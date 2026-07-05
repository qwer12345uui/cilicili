import SwiftUI

struct UploaderVideosSection: View {
    @ObservedObject var viewModel: UploaderViewModel
    let metrics: HomeFeedLayoutMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sortMenu

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.videos.isEmpty {
            emptyContent
        } else {
            videoGrid
        }
    }

    private var sortMenu: some View {
        HStack {
            Menu {
                ForEach(UploaderVideoOrder.allCases) { order in
                    Button {
                        Task { await viewModel.changeVideoOrder(order) }
                    } label: {
                        Label(order.title, systemImage: order == viewModel.videoOrder ? "checkmark" : "circle")
                    }
                }
            } label: {
                Label(viewModel.videoOrder.title, systemImage: "arrow.up.arrow.down.circle")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.feedHorizontalPadding)
    }

    @ViewBuilder
    private var emptyContent: some View {
        if viewModel.state.isLoading {
            UploaderVideosLoadingState()
        } else if case .failed(let message) = viewModel.state {
            ErrorStateView(title: "投稿加载失败", message: message) {
                Task { await viewModel.refresh() }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            EmptyStateView(title: "暂无投稿", systemImage: "film", message: "下拉刷新后再试。")
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        }
    }

    private var videoGrid: some View {
        LazyVGrid(columns: metrics.feedColumns, spacing: metrics.feedSpacing) {
            ForEach(viewModel.videos) { video in
                UploaderVideoGridItem(
                    video: video,
                    metrics: metrics
                ) {
                    await viewModel.loadMoreIfNeeded(current: video)
                }
            }

            footer
                .gridCellColumns(metrics.feedColumns.count)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, metrics.feedHorizontalPadding)
    }

    @ViewBuilder
    private var footer: some View {
        if viewModel.state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        } else if !viewModel.hasMoreVideos {
            Text("没有更多投稿了")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
    }
}

private struct UploaderVideosLoadingState: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()

            Text("正在加载投稿")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

private struct UploaderVideoGridItem: View {
    let video: VideoItem
    let metrics: HomeFeedLayoutMetrics
    let loadMoreIfNeeded: () async -> Void

    var body: some View {
        VideoRouteLink(video) {
            HomeFeedVideoCardLabel(
                metrics: metrics,
                display: VideoCardDisplayModel(video: video),
                showsAuthorIdentity: false
            )
        }
        .task {
            await loadMoreIfNeeded()
        }
    }
}
