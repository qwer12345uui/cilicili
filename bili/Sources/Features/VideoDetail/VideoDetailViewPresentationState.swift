import Foundation

struct VideoDetailViewPresentationState {
    var selectedContentTab: VideoDetailContentTab = .detail
    var replySheetComment: Comment?
    var replySheetSecondaryID: Int?
    var isShowingDanmakuSettings = false
    var isShowingFavoriteFolders = false
    var isShowingCoinPicker = false
    var isShowingNetworkDiagnostics = false
    var isClosingDetail = false
}
