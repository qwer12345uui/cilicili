import SwiftUI

struct PlayerPerformanceOverlayLoadedContent: View {
    @ObservedObject var diagnosticsStore: VideoDetailNetworkDiagnosticsRenderStore
    let session: PlayerPerformanceSession
    let playerViewModel: PlayerStateViewModel?

    var body: some View {
        PlayerPerformanceOverlayLiveDiagnosticsSection(
            diagnosticsStore: diagnosticsStore,
            playerViewModel: playerViewModel
        )
        PlayerPerformanceOverlayMetricsGrid(session: session)
        PlayerPerformanceOverlaySamplesSection(samples: session.recentStartupSamples)
        PlayerPerformanceOverlayStartupWaterfallSection(session: session)
        PlayerPerformanceOverlayDiagnosticsSection(
            session: session,
            playerViewModel: playerViewModel
        )
        PlayerPerformanceOverlayCountersRow(session: session)
        PlayerPerformanceOverlayTerminalSection(session: session)
    }
}
