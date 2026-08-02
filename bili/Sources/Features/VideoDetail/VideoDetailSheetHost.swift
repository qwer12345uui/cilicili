import SwiftUI

private struct VideoDetailSheetHostModifier: ViewModifier {
    @ObservedObject var viewModel: VideoDetailViewModel
    @ObservedObject var libraryStore: LibraryStore
    let sheetState: VideoDetailSheetState
    let sheetActions: VideoDetailSheetActions

    func body(content: Content) -> some View {
        content
            .sheet(item: sheetState.replySheetComment, onDismiss: {
                sheetState.replySheetSecondaryID.wrappedValue = nil
                viewModel.clearDeepLinkCommentThreadAnchor()
            }) { comment in
                if let replyID = sheetState.replySheetSecondaryID.wrappedValue,
                   let reply = viewModel.replies(for: comment).first(where: { $0.id == replyID }) {
                    CommentDialogSheet(
                        rootComment: comment,
                        focusReply: reply,
                        store: viewModel.commentThreadRenderStore,
                        loadDialog: sheetActions.replies.loadDialog,
                        reloadDialog: sheetActions.replies.reloadDialog
                    )
                    .environment(\.commentContentOwnerMID, viewModel.detail.owner?.mid)
                } else {
                    VideoDetailReplySheetHost(
                        rootComment: comment,
                        viewModel: viewModel,
                        initialReplyID: nil,
                        actions: sheetActions.replies
                    )
                    .environment(\.commentContentOwnerMID, viewModel.detail.owner?.mid)
                }
            }
            .sheet(isPresented: sheetState.isShowingFavoriteFolders) {
                VideoDetailFavoriteFolderSheetHost(
                    viewModel: viewModel,
                    actions: sheetActions.favoriteFolders
                )
            }
            .sheet(isPresented: sheetState.isShowingCoinPicker) {
                VideoDetailCoinSheetHost(viewModel: viewModel)
            }
            .sheet(isPresented: sheetState.isShowingDanmakuSettings) {
                VideoDetailDanmakuSettingsSheetHost(
                    viewModel: viewModel,
                    actions: sheetActions.danmaku
                )
            }
            .sheet(isPresented: sheetState.isShowingNetworkDiagnostics) {
                VideoDetailNetworkDiagnosticsSheetHost(
                    viewModel: viewModel,
                    libraryStore: libraryStore
                )
            }
    }
}

extension View {
    func videoDetailSheets(
        viewModel: VideoDetailViewModel,
        libraryStore: LibraryStore,
        sheetState: VideoDetailSheetState
    ) -> some View {
        modifier(
            VideoDetailSheetHostModifier(
                viewModel: viewModel,
                libraryStore: libraryStore,
                sheetState: sheetState,
                sheetActions: VideoDetailSheetActionsBuilder(viewModel: viewModel).actions
            )
        )
    }
}
