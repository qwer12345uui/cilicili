import SwiftUI

extension RootTabView {
    var shouldAutoOpenDetail: Bool {
        !didConsumeStartupVideo && shouldStartDetail && startBVID == nil
    }

    func openStartupVideoIfNeeded() {
        guard !didConsumeStartupVideo,
              let startBVID
        else { return }

        openVideo(Self.seedVideo(bvid: startBVID))
    }

    func openStartupLiveRoomIfNeeded() {
        guard !didConsumeStartupLiveRoom,
              let startLiveRoomID
        else { return }

        didConsumeStartupLiveRoom = true
        selectedTab = .live
        DispatchQueue.main.async {
            liveNavigationPath.append(Self.seedLiveRoom(roomID: startLiveRoomID))
        }
    }

    func openStartupUploaderIfNeeded() {
        guard !didConsumeStartupUploader,
              let startUploaderMID,
              startUploaderMID > 0
        else { return }

        didConsumeStartupUploader = true
        selectedTab = .home
        DispatchQueue.main.async {
            navigationPath.append(Self.seedUploader(mid: startUploaderMID))
        }
    }

    func openAppURL(_ url: URL) {
        guard AppLinkRouter.canHandle(url) else { return }

        Task { @MainActor in
            let destination = await AppLinkRouter.destination(for: url, api: dependencies.api)
            routeAppLinkDestination(destination)
        }
    }

    func routeAppLinkDestination(_ destination: AppLinkDestination) {
        switch destination {
        case .video(let video):
            openVideo(video)
        case .liveRoom(let room):
            openLiveRoomFromLink(room)
        case .user(let owner):
            openUserFromLink(owner)
        case .browser(let url):
            inAppBrowserItem = InAppBrowserItem(url: url)
        }
    }

    func openPgcSeasonRoute(_ route: PgcSeasonRoute) {
        openOverlayRoute(route)
    }

    func openVideoOwnerRoute(_ owner: VideoOwner) {
        openOverlayRoute(owner)
    }

    private func openOverlayRoute<Route: Hashable>(_ route: Route) {
        AppOrientationLock.restorePortrait()
        if bottomMode == .video {
            withAnimation(.smooth(duration: 0.28)) {
                videoNavigationPath.append(route)
            }
            return
        }

        withAnimation(.smooth(duration: 0.32)) {
            videoPresentationGeneration &+= 1
            didConsumeStartupVideo = true
            isClosingVideo = false
            activeVideo = nil
            videoNavigationPath = NavigationPath()
            bottomMode = .video
        }
        pushInitialOverlayRoute(route, generation: videoPresentationGeneration)
    }

    func openLiveRoomFromLink(_ room: LiveRoom) {
        AppOrientationLock.restorePortrait()
        if bottomMode == .video {
            ActivePlaybackCoordinator.shared.stopActivePlayback()
            withAnimation(.smooth(duration: 0.28)) {
                videoNavigationPath.append(room)
            }
            return
        }

        selectedTab = .live
        DispatchQueue.main.async {
            liveNavigationPath.append(room)
        }
    }

    func openUserFromLink(_ owner: VideoOwner) {
        AppOrientationLock.restorePortrait()
        if bottomMode == .video {
            withAnimation(.smooth(duration: 0.28)) {
                videoNavigationPath.append(owner)
            }
            return
        }

        DispatchQueue.main.async {
            switch selectedTab {
            case .home:
                navigationPath.append(owner)
            case .dynamic:
                dynamicNavigationPath.append(owner)
            case .live:
                liveNavigationPath.append(owner)
            case .mine:
                mineNavigationPath.append(owner)
            case .search:
                searchNavigationPath.append(owner)
            }
        }
    }

    func videoNavigationHost() -> some View {
        RootVideoNavigationHost(
            path: $videoNavigationPath,
            isClosingVideo: isClosingVideo,
            onRequestClose: closeVideo,
            onPopOne: popOneVideoLevel,
            onCancelledClose: cancelCloseVideoIfNeeded,
            onCompletedClose: completeCloseVideoIfNeeded
        ) {
            guard bottomMode == .video else { return }
            scheduleCloseVideo()
        }
    }

    /// 详情页返回按钮：只 pop 一层（回到上一个详情页或来源页），
    /// 而非 closeVideo 的清空整栈。count==1 时 removeLast 会清空到 0，
    /// 触发 onPathEmptied → scheduleCloseVideo，正好回到来源页。
    func popOneVideoLevel() {
        guard bottomMode == .video, !videoNavigationPath.isEmpty else { return }
        withAnimation(.smooth(duration: 0.28)) {
            videoNavigationPath.removeLast()
        }
    }

    func openVideo(_ video: VideoItem) {
        AppOrientationLock.restorePortrait()
        PlayerMetricsLog.record(.routeOpen, metricsID: video.bvid, title: video.title)
        if bottomMode == .video {
            pushVideo(video)
            return
        }

        beginPlaybackPreload(for: video)
        let update = {
            videoPresentationGeneration &+= 1
            didConsumeStartupVideo = true
            isClosingVideo = false
            activeVideo = video
            videoNavigationPath = NavigationPath()
            bottomMode = .video
        }

        let opensFromStartup = shouldStartDetail && !didConsumeStartupVideo
        if shouldStartDetail && !didConsumeStartupVideo {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, update)
        } else {
            withAnimation(.smooth(duration: 0.32), update)
        }
        pushInitialVideo(video, generation: videoPresentationGeneration, animated: !opensFromStartup)
    }

    func pushVideo(_ video: VideoItem) {
        AppOrientationLock.restorePortrait()
        PlayerMetricsLog.record(.routeOpen, metricsID: video.bvid, title: video.title)
        ActivePlaybackCoordinator.shared.pauseActivePlaybackForNavigation()
        beginPlaybackPreload(for: video)
        withAnimation(.smooth(duration: 0.28)) {
            didConsumeStartupVideo = true
            isClosingVideo = false
            videoNavigationPath.append(video)
        }
    }

    func beginPlaybackPreload(for video: VideoItem) {
        guard !video.bvid.isEmpty, !video.bvid.hasPrefix("av") else { return }
        guard !video.isPGCEpisode else { return }
        let now = Date()
        if let lastPreload = recentPlaybackPreloadTimes[video.bvid],
           now.timeIntervalSince(lastPreload) < 1.2 {
            return
        }
        recentPlaybackPreloadTimes[video.bvid] = now
        trimRecentPlaybackPreloads(now: now)

        Task {
            dependencies.refreshPlaybackCDNProbeIfNeeded()
            let playbackAdaptationProfile = PlayerPerformanceStore.shared.playbackAdaptationProfile(
                for: video.bvid,
                isEnabled: dependencies.libraryStore.isPlaybackAutoOptimizationEnabled
            )
            let preferredQuality = dependencies.libraryStore.effectivePreferredVideoQuality
            let cdnPreference = dependencies.libraryStore.effectivePlaybackCDNPreference
            let api = dependencies.api
            await VideoPreloadCenter.shared.updatePlaybackPreferences(
                preferredQuality: preferredQuality,
                cdnPreference: cdnPreference,
                playbackAdaptationProfile: playbackAdaptationProfile
            )
            await VideoPreloadCenter.shared.prioritizePlayback(for: video)
            await VideoPreloadCenter.shared.preloadPlayInfo(
                video,
                api: api,
                preferredQuality: preferredQuality,
                cdnPreference: cdnPreference,
                priority: .userInitiated,
                warmsMedia: true,
                mediaWarmupDelay: 0,
                playbackAdaptationProfile: playbackAdaptationProfile
            )
        }
    }

    func trimRecentPlaybackPreloads(now: Date) {
        recentPlaybackPreloadTimes = recentPlaybackPreloadTimes.filter { _, date in
            now.timeIntervalSince(date) < 8
        }
        guard recentPlaybackPreloadTimes.count > 16 else { return }
        let keptKeys = Set(
            recentPlaybackPreloadTimes
                .sorted { $0.value > $1.value }
                .prefix(16)
                .map(\.key)
        )
        recentPlaybackPreloadTimes = recentPlaybackPreloadTimes.filter { keptKeys.contains($0.key) }
    }

    func pushInitialOverlayRoute<Route: Hashable>(_ route: Route, generation: Int) {
        DispatchQueue.main.async {
            guard bottomMode == .video,
                  videoNavigationPath.isEmpty,
                  videoPresentationGeneration == generation,
                  !isClosingVideo
            else { return }

            withAnimation(.smooth(duration: 0.30)) {
                videoNavigationPath.append(route)
            }
        }
    }

    func pushInitialVideo(_ video: VideoItem, generation: Int, animated: Bool) {
        DispatchQueue.main.async {
            guard bottomMode == .video,
                  videoNavigationPath.isEmpty,
                  activeVideo?.id == video.id,
                  videoPresentationGeneration == generation,
                  !isClosingVideo
            else { return }

            let push = {
                videoNavigationPath.append(video)
            }

            if animated {
                withAnimation(.smooth(duration: 0.30), push)
            } else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction, push)
            }
        }
    }

    func restoreVideoPlaybackUIForPictureInPicture(_ video: VideoItem) async -> Bool {
        closeVideoFallbackTask?.cancel()
        closeVideoFallbackTask = nil
        AppOrientationLock.restorePortrait()

        let isAlreadyShowingPlaybackPage = bottomMode == .video
            && !isClosingVideo
            && activeVideo?.id == video.id
            && videoNavigationPath.count == 1
        guard !isAlreadyShowingPlaybackPage else { return true }

        beginPlaybackPreload(for: video)
        videoPresentationGeneration &+= 1
        didConsumeStartupVideo = true
        isClosingVideo = false

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeVideo = video
            videoNavigationPath = NavigationPath()
            bottomMode = .video
        }

        await Task.yield()
        guard bottomMode == .video,
              activeVideo?.id == video.id,
              !isClosingVideo
        else { return false }

        videoNavigationPath.append(video)
        await Task.yield()
        return bottomMode == .video && !videoNavigationPath.isEmpty
    }

    func closeVideo() {
        guard bottomMode == .video else { return }
        beginDefinitiveVideoClose()
    }

    func scheduleCloseVideo() {
        guard bottomMode == .video, !isClosingVideo else {
            return
        }
        isClosingVideo = true
        videoPresentationGeneration &+= 1
        ActivePlaybackCoordinator.shared.pauseActivePlaybackForNavigation()
        closeVideoFallbackTask?.cancel()
        closeVideoFallbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled, bottomMode == .video, isClosingVideo else { return }
            completeCloseVideoIfNeeded()
        }
    }

    func beginDefinitiveVideoClose() {
        isClosingVideo = true
        videoPresentationGeneration &+= 1
        closeVideoFallbackTask?.cancel()
        closeVideoFallbackTask = nil
        ActivePlaybackCoordinator.shared.stopActivePlayback()
        AppOrientationLock.restorePortrait()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeVideo = nil
            videoNavigationPath = NavigationPath()
            bottomMode = .root
            isClosingVideo = false
        }
        rootTabBarRestoreRequestID &+= 1
    }

    func cancelCloseVideoIfNeeded() {
        guard bottomMode == .video, isClosingVideo else { return }
        closeVideoFallbackTask?.cancel()
        closeVideoFallbackTask = nil
        isClosingVideo = false
        ActivePlaybackCoordinator.shared.resumeActivePlaybackAfterCancelledNavigation()
    }

    func completeCloseVideoIfNeeded() {
        guard bottomMode == .video, isClosingVideo else { return }
        closeVideoFallbackTask?.cancel()
        closeVideoFallbackTask = nil
        ActivePlaybackCoordinator.shared.stopActivePlayback()
        AppOrientationLock.restorePortrait()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeVideo = nil
            videoNavigationPath = NavigationPath()
            bottomMode = .root
            isClosingVideo = false
        }
        rootTabBarRestoreRequestID &+= 1
    }
}
