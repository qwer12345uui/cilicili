import SwiftUI

struct VideoDetailLoadedDetailContentPage: View {
    @ObservedObject var viewModel: VideoDetailViewModel
    let layoutWidth: CGFloat
    let runtimeSettings: VideoDetailRuntimeSettingsSnapshot
    let onShowNetworkDiagnostics: () -> Void
    let onShowFavoriteFolders: () -> Void

    var body: some View {
        let renderPack = renderPack

        VideoDetailSummaryCard(
            viewModel: viewModel,
            contentWidth: renderPack.contentWidth,
            showsNetworkDiagnosticsButton: runtimeSettings.showsNetworkDiagnosticsButton,
            onShowNetworkDiagnostics: onShowNetworkDiagnostics,
            onShowFavoriteFolders: onShowFavoriteFolders
        )
        .padding(.horizontal, PlaybackDetailContentMetrics.horizontalPadding)

        if viewModel.detail.isPGCEpisode {
            VideoDetailPgcEpisodeSection(
                detail: viewModel.detail,
                selectEpisode: renderPack.actions.selectPgcEpisode
            )
                .padding(.horizontal, PlaybackDetailContentMetrics.horizontalPadding)
        } else {
            VideoDetailPageMenu(
                store: renderPack.pageSelectorStore,
                selectPage: renderPack.actions.selectPage
            )
            .padding(.horizontal, PlaybackDetailContentMetrics.horizontalPadding)

            VideoDetailRelatedSection(
                store: renderPack.relatedStore,
                layoutWidth: layoutWidth,
                runtimeSettings: runtimeSettings,
                retryRelated: renderPack.actions.retryRelated
            )
        }
    }

    private var renderPack: VideoDetailLoadedDetailContentPageRenderPack {
        VideoDetailLoadedDetailContentPageRenderPack(
            viewModel: viewModel,
            layoutWidth: layoutWidth
        )
    }
}
