import SwiftUI

/// 把正式的 UIKit 详情页外壳 `VideoDetailShellViewController` 包回 SwiftUI。
///
/// binding 与内容区回调从 SwiftUI 侧透传；播放器竖屏“更多”菜单由 UIKit
/// 外壳直接呈现，避免嵌套 HostingController 的 sheet 状态丢失。
struct VideoDetailShellRepresentable: UIViewControllerRepresentable {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.openVideoOwnerRouteAction) private var openVideoOwnerRoute
    @ObservedObject var viewModel: VideoDetailViewModel
    @ObservedObject var fullscreenCoordinator: VideoDetailFullscreenCoordinator
    @ObservedObject var runtimeSettings: VideoDetailRuntimeSettingsStore
    @Binding var selectedContentTab: VideoDetailContentTab
    @Binding var replySheetComment: Comment?
    @Binding var replySheetSecondaryID: Int?
    @Binding var isShowingDanmakuSettings: Bool
    @Binding var isShowingFavoriteFolders: Bool
    @Binding var isShowingCoinPicker: Bool
    @Binding var isShowingNetworkDiagnostics: Bool
    let onNavigateBack: () -> Void

    func makeUIViewController(context: Context) -> VideoDetailShellViewController {
        // 新路径绕过 PlaybackScene，需自己 bind runtimeSettings，
        // 否则内容区设置（诊断按钮/进度条等）取默认值。
        runtimeSettings.bind(dependencies.libraryStore)
        return VideoDetailShellViewController(
            viewModel: viewModel,
            fullscreenCoordinator: fullscreenCoordinator,
            runtimeSettings: runtimeSettings,
            dependencies: dependencies,
            openVideoOwnerRoute: openVideoOwnerRoute,
            selectedContentTab: $selectedContentTab,
            onShowNetworkDiagnostics: { isShowingNetworkDiagnostics = true },
            onShowFavoriteFolders: { isShowingFavoriteFolders = true },
            onShowCoinPicker: { isShowingCoinPicker = true },
            onShowDanmakuSettings: { isShowingDanmakuSettings = true },
            onReply: {
                replySheetSecondaryID = nil
                replySheetComment = $0
            },
            onNavigateBack: onNavigateBack
        )
    }

    func updateUIViewController(_: VideoDetailShellViewController, context _: Context) {}

    static func dismantleUIViewController(
        _ uiViewController: VideoDetailShellViewController,
        coordinator _: Void
    ) {
        uiViewController.prepareForDismantle()
    }
}
