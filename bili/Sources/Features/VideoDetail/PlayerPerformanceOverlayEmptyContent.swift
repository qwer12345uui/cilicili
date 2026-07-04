import SwiftUI

struct PlayerPerformanceOverlayEmptyContent: View {
    @ObservedObject var diagnosticsStore: VideoDetailNetworkDiagnosticsRenderStore
    let playerViewModel: PlayerStateViewModel?

    var body: some View {
        PlayerPerformanceOverlayLiveDiagnosticsSection(
            diagnosticsStore: diagnosticsStore,
            playerViewModel: playerViewModel
        )

        Text("等待播放事件")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}
