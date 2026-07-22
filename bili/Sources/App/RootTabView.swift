import Foundation
import SwiftUI

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var dependencies: AppDependencies
    @EnvironmentObject var libraryStore: LibraryStore
    @StateObject var runtimeSettings = RootRuntimeSettingsStore()
    @StateObject var homeViewModelHolder = RootHomeViewModelHolder()
    @StateObject var searchBottomAccessoryStore = SearchBottomAccessoryStore()
    @State var selectedTab = Self.initialTab.appTab
    @State var bottomMode: BottomTabMode = .root
    @State var rootTabBarRestoreRequestID = 0
    @State var activeVideo: VideoItem?
    @State var videoNavigationPath = NavigationPath()
    @State var navigationPath = NavigationPath()
    @State var dynamicNavigationPath = NavigationPath()
    @State var liveNavigationPath = NavigationPath()
    @State var mineNavigationPath = NavigationPath()
    @State var searchNavigationPath = NavigationPath()
    @State var didConsumeStartupVideo = false
    @State var didConsumeStartupLiveRoom = false
    @State var didConsumeStartupUploader = false
    @State var isClosingVideo = false
    @State var videoPresentationGeneration = 0
    @State var closeVideoFallbackTask: Task<Void, Never>?
    @State var inAppBrowserItem: InAppBrowserItem?
    @State var recentPlaybackPreloadTimes: [String: Date] = [:]
    let shouldStartDetail = ProcessInfo.processInfo.arguments.contains("--start-detail")
    let startBVID = Self.argumentValue(after: "--start-bvid")
    let startLiveRoomID = Self.argumentInt(after: "--start-live-room")
    let startUploaderMID = Self.argumentInt(after: "--start-uploader-mid")

    var body: some View {
        ZStack {
            TabView(selection: tabSelection) {
                ForEach(visibleRootTabs) { tab in
                    Tab(value: tab) {
                        rootTabContent(for: tab)
                    } label: {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                }
            }
            .tint(libraryStore.appTintColor)
            .tabViewBottomAccessory(isEnabled: showsSearchBottomAccessory) {
                SearchTabBottomAccessory(store: searchBottomAccessoryStore)
            }
            .tabBarMinimizeBehavior(rootTabBarMinimizeBehavior)
            .restoresRootTabBarWhenRequested(requestID: rootTabBarRestoreRequestID)
            .background(RootTabBarAppearanceInstaller(tintColorHex: libraryStore.appTintColorHex))

            if bottomMode == .video {
                videoNavigationHost()
                    .ignoresSafeArea()
                    .transition(.identity)
                    .zIndex(1)
            }
        }
        .environment(\.openVideoAction, openVideo)
        .environment(\.openLiveRoomAction, openLiveRoom)
        .environment(\.prewarmVideoRouteAction, beginPlaybackPreload)
        .environment(\.openPgcSeasonRouteAction, openPgcSeasonRoute)
        .environment(\.openVideoOwnerRouteAction, openVideoOwnerRoute)
        .environment(\.openAppURLAction, openAppURL)
        .environment(\.appThemeTintColor, libraryStore.appTintColor)
        .environment(\.showsVideoCoverDurationBadges, libraryStore.showsVideoCoverDurationBadges)
        .environment(\.unifiedVideoCoverBorderExperimentEnabled, libraryStore.unifiedVideoCoverBorderExperimentEnabled)
        .environment(\.fastScrollImageLoadSuppressionExperimentEnabled, libraryStore.fastScrollImageLoadSuppressionExperimentEnabled)
        .environment(\.scrollEdgeEffectPreference, runtimeSettings.scrollEdgeEffectPreference)
        .environment(\.openURL, OpenURLAction { url in
            guard AppLinkRouter.canHandle(url) else { return .systemAction }
            openAppURL(url)
            return .handled
        })
        .background(NavigationChromeInstaller(isStandardChromeEnabled: bottomMode == .video))
        .animation(.smooth(duration: 0.28), value: bottomMode)
        .preferredColorScheme(runtimeSettings.appearanceMode.preferredColorScheme)
        .sheet(item: $inAppBrowserItem) { item in
            InAppBrowserView(url: item.url)
                .ignoresSafeArea()
        }
        .task {
            AppIconController.apply(libraryStore.appIconPreference)
            PictureInPictureRestoreCoordinator.shared.restoreHandler = { video in
                await restoreVideoPlaybackUIForPictureInPicture(video)
            }
            runtimeSettings.bind(dependencies.libraryStore)
            repairSelectedTabIfNeeded(visibleTabs: runtimeSettings.visibleRootTabs)
            openStartupVideoIfNeeded()
            openStartupLiveRoomIfNeeded()
            openStartupUploaderIfNeeded()
            dependencies.scheduleDeferredStartupWorkIfNeeded()
        }
        .onChange(of: runtimeSettings.visibleRootTabs) { _, tabs in
            repairSelectedTabIfNeeded(visibleTabs: tabs)
        }
        .onChange(of: libraryStore.appIconPreference) { _, preference in
            AppIconController.apply(preference)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            Task {
                await VideoPreloadCenter.shared.cancelMediaWarmups(clearCache: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            cancelMediaWarmupsIfEnvironmentConstrained()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)) { _ in
            cancelMediaWarmupsIfEnvironmentConstrained()
        }
        .onReceive(NotificationCenter.default.publisher(for: .biliPlaybackNetworkClassDidChange)) { _ in
            cancelMediaWarmupsIfEnvironmentConstrained()
        }
    }

    private var showsSearchBottomAccessory: Bool {
        guard visibleRootTabs.contains(.search),
              selectedTab == .search,
              searchBottomAccessoryStore.viewModel != nil,
              !searchBottomAccessoryStore.isSearchFocused else {
            return false
        }
        // Keep the accessory alive under pushed and overlay detail pages so it does not reappear late on return.
        return true
    }

    private var rootTabBarMinimizeBehavior: TabBarMinimizeBehavior {
        if selectedTab == .search {
            return .onScrollDown
        }
        return runtimeSettings.minimizesTabBarOnScroll ? .onScrollDown : .never
    }

    private func cancelMediaWarmupsIfEnvironmentConstrained() {
        let environment = PlaybackEnvironment.current
        guard environment.shouldPreferConservativePlayback || environment.isThermallyElevated else { return }
        Task {
            await VideoPreloadCenter.shared.cancelMediaWarmups(clearCache: false)
        }
    }

    @ViewBuilder
    private func homePage() -> some View {
        if let viewModel = homeViewModelHolder.viewModel {
            HomeView(
                viewModel: viewModel,
                detailPath: $navigationPath,
                launchConfiguration: HomeFeedLaunchConfiguration(
                    autoOpenDetail: shouldAutoOpenDetail,
                    startVideo: startBVID.map(Self.seedVideo),
                    onVideoSelect: openVideo
                )
            )
            .videoDestinations()
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .task {
                    homeViewModelHolder.configure(
                        api: dependencies.api,
                        libraryStore: dependencies.libraryStore,
                        sessionStore: dependencies.sessionStore,
                        initialMode: .recommend
                    )
                }
        }
    }

    @ViewBuilder
    private func rootTabContent(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            NavigationStack(path: $navigationPath) {
                homePage()
            }
        case .dynamic:
            NavigationStack(path: $dynamicNavigationPath) {
                DynamicView()
                    .videoDestinations()
            }
        case .live:
            NavigationStack(path: $liveNavigationPath) {
                LiveView()
                    .videoDestinations()
            }
        case .mine:
            NavigationStack(path: $mineNavigationPath) {
                MineView()
                    .videoDestinations()
            }
        case .search:
            NavigationStack(path: $searchNavigationPath) {
                SearchView(accessoryStore: searchBottomAccessoryStore)
                    .videoDestinations()
            }
        }
    }

}
