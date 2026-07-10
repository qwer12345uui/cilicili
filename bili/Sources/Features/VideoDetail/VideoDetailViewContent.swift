import SwiftUI

struct VideoDetailViewContent: View {
    let seedVideo: VideoItem
    @ObservedObject var holder: VideoDetailViewModelHolder
    @ObservedObject var runtimeSettings: VideoDetailRuntimeSettingsStore
    @ObservedObject var fullscreenCoordinator: VideoDetailFullscreenCoordinator
    @Binding var selectedContentTab: VideoDetailContentTab
    @Binding var replySheetComment: Comment?
    @Binding var isShowingDanmakuSettings: Bool
    @Binding var isShowingFavoriteFolders: Bool
    @Binding var isShowingNetworkDiagnostics: Bool
    let onNavigateBack: () -> Void
    let lifecycleActions: VideoDetailViewContentLifecycleActions

    var body: some View {
        PlaybackDetailLoadedStatePage(
            holder.viewModel,
            performanceContext: .video(seedVideo)
        ) { viewModel in
            VideoDetailViewContentResolver(
                seedVideo: seedVideo,
                runtimeSettings: runtimeSettings,
                fullscreenCoordinator: fullscreenCoordinator,
                viewModel: viewModel,
                selectedContentTab: $selectedContentTab,
                replySheetComment: $replySheetComment,
                isShowingDanmakuSettings: $isShowingDanmakuSettings,
                isShowingFavoriteFolders: $isShowingFavoriteFolders,
                isShowingNetworkDiagnostics: $isShowingNetworkDiagnostics,
                onNavigateBack: onNavigateBack
            )
        } initialContent: {
            VideoDetailInitialContentResolver(
                seedVideo: seedVideo,
                selectedContentTab: $selectedContentTab,
                runtimeSettings: runtimeSettings.snapshot,
                onNavigateBack: onNavigateBack,
                lifecycleActions: lifecycleActions
            )
        }
    }
}
