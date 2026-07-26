import SwiftUI

struct VideoDetailSheetState {
    var replySheetComment: Binding<Comment?>
    var replySheetSecondaryID: Binding<Int?>
    var isShowingFavoriteFolders: Binding<Bool>
    var isShowingCoinPicker: Binding<Bool>
    var isShowingDanmakuSettings: Binding<Bool>
    var isShowingNetworkDiagnostics: Binding<Bool>
}
