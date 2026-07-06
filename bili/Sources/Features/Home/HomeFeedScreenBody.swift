import SwiftUI

struct HomeFeedScreenBody: View {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var runtimeSettings: HomeRuntimeSettingsStore
    @ObservedObject var libraryStore: LibraryStore
    @Binding var viewportState: HomeFeedViewportState
    @Binding var detailPath: NavigationPath
    let contentActions: HomeFeedContentActions
    let actionStore: HomeFeedScreenActionStore
    let launchConfiguration: HomeFeedLaunchConfiguration

    var body: some View {
        HomeFeedScrollView(
            viewModel: viewModel,
            runtimeSettings: runtimeSettings,
            viewportState: $viewportState,
            scrollActions: actionStore.scroll,
            refreshActions: actionStore.refresh
        ) {
            HomeFeedContentSection(
                metrics: viewportState.layoutMetrics(for: runtimeSettings.homeFeedLayout),
                cells: viewModel.videoCells,
                lastSeenMarkerIndex: viewModel.lastSeenMarkerIndex,
                isLoadingMore: viewModel.state.isLoading && !viewModel.isRefreshing && !viewModel.isUserRefreshing,
                actions: contentActions
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .homeFeedScreenLifecycle(
            viewModel: viewModel,
            runtimeSettings: runtimeSettings,
            libraryStore: libraryStore,
            detailPath: $detailPath,
            configuration: lifecycleConfiguration
        )
    }

    private var lifecycleConfiguration: HomeFeedScreenLifecycleConfiguration {
        HomeFeedScreenLifecycleConfiguration(
            launchConfiguration: launchConfiguration,
            lifecycleActions: actionStore.lifecycle,
            detailOpenActions: actionStore.detailOpen
        )
    }
}
