import SwiftUI

struct VideoDetailView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    let seedVideo: VideoItem
    private let hidesRootTabBar: Bool
    private let onRequestClose: (() -> Void)?
    private let onPopOne: (() -> Void)?

    @StateObject private var holder = VideoDetailViewModelHolder()
    @StateObject private var runtimeSettings = VideoDetailRuntimeSettingsStore()
    @StateObject private var fullscreenCoordinator = VideoDetailFullscreenCoordinator()
    @State private var presentationState = VideoDetailViewPresentationState()

    init(
        seedVideo: VideoItem,
        hidesRootTabBar: Bool = true,
        onRequestClose: (() -> Void)? = nil,
        onPopOne: (() -> Void)? = nil
    ) {
        self.seedVideo = seedVideo
        self.hidesRootTabBar = hidesRootTabBar
        self.onRequestClose = onRequestClose
        self.onPopOne = onPopOne
    }

    var body: some View {
        PlaybackDetailPageHost(
            hidesSystemChrome: .constant(false),
            background: VideoDetailTheme.background,
            hidesRootTabBar: hidesRootTabBar,
            navigationBarVisibility: .hidden,
            hidesBackButton: true,
            statusBarStyle: .default,
            performanceContext: .video(seedVideo),
            lifecycleActions: pageLifecycleActions
        ) {
            VideoDetailViewContent(
                seedVideo: seedVideo,
                holder: holder,
                runtimeSettings: runtimeSettings,
                fullscreenCoordinator: fullscreenCoordinator,
                selectedContentTab: $presentationState.selectedContentTab,
                replySheetComment: $presentationState.replySheetComment,
                isShowingDanmakuSettings: $presentationState.isShowingDanmakuSettings,
                isShowingFavoriteFolders: $presentationState.isShowingFavoriteFolders,
                isShowingNetworkDiagnostics: $presentationState.isShowingNetworkDiagnostics,
                onNavigateBack: popOneVideoLevel,
                lifecycleActions: contentLifecycleActions
            )
        }
    }

    private var contentLifecycleActions: VideoDetailViewContentLifecycleActions {
        VideoDetailViewContentLifecycleActions(
            configureViewModel: viewActions.configureViewModel
        )
    }

    private var pageLifecycleActions: PlaybackDetailPageLifecycleActions {
        PlaybackDetailPageLifecycleActions(
            onAppear: {
                guard let viewModel = holder.viewModel else { return }
                Task { await viewModel.resumePlaybackAfterCoveredNavigationIfNeeded() }
            },
            onDisappear: {
                fullscreenCoordinator.resetForDisappear()
                holder.viewModel?.stopPlaybackForNavigation()
            }
        )
    }

    private var viewActions: VideoDetailViewActions {
        VideoDetailViewActionsBuilder(
            seedVideo: seedVideo,
            dependencies: dependencies,
            holder: holder,
            fullscreenCoordinator: fullscreenCoordinator,
            dismiss: dismiss,
            onRequestClose: onRequestClose,
            onPopOne: onPopOne
        )
        .actions
    }

    private func dismissVideoDetail() {
        viewActions.dismissVideoDetail(presentationState: $presentationState)
    }

    private func popOneVideoLevel() {
        viewActions.popOneVideoLevel(presentationState: $presentationState)
    }
}
