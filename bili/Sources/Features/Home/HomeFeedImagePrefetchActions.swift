import Foundation

extension HomeFeedMediaPreloadCoordinator {
    func scheduleImagePrefetch(for videos: [VideoItem]) {
        imagePrefetchTask?.cancel()
        let environment = PlaybackEnvironment.current
        let prefetchLimit = environment.shouldPreferConservativePlayback ? 4 : 5
        let prefetchPlan = HomeFeedImagePrefetchPlan.make(
            for: videos,
            layout: libraryStore.homeFeedLayout,
            limit: prefetchLimit
        )

        guard !prefetchPlan.coverSources.isEmpty else { return }
        let coverSourcesToPrefetch = prefetchPlan.coverSources
        let coverTargetPixelSize = prefetchPlan.coverTargetPixelSize
        imagePrefetchTask = Task(priority: .utility) {
            await RemoteImageCache.shared.prefetch(
                coverSourcesToPrefetch,
                targetPixelSize: coverTargetPixelSize,
                maximumConcurrentLoads: 1
            )
        }
    }
}
