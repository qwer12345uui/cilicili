import SwiftUI

struct HomeFeedSingleColumnContent: View {
    let metrics: HomeFeedLayoutMetrics
    let cells: [HomeVideoCellModel]
    let lastSeenMarkerIndex: Int?
    let isLoadingMore: Bool
    let actions: HomeFeedContentActions

    private var loadMoreTriggerCellID: String? {
        cells.last?.id
    }

    private var visibleLastSeenMarkerIndex: Int? {
        guard let lastSeenMarkerIndex,
              lastSeenMarkerIndex > 0,
              lastSeenMarkerIndex < cells.count
        else { return nil }
        return lastSeenMarkerIndex
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                if visibleLastSeenMarkerIndex == index {
                    HomeFeedLastSeenMarkerCard(
                        metrics: metrics,
                        action: actions.onRefreshFromLastSeenMarker
                    )
                    .padding(.top, metrics.mode == .borderedSingleColumn ? 8 : 9)
                    .padding(.bottom, metrics.mode == .borderedSingleColumn ? 8 : 14)
                }

                HomeFeedSingleColumnCard(
                    metrics: metrics,
                    cell: cell,
                    index: index,
                    loadMoreTriggerCellID: loadMoreTriggerCellID,
                    actions: actions
                )
            }

            if isLoadingMore {
                VideoFeedSkeletonCard(style: loadingMoreSkeletonStyle)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, metrics.singleColumnHorizontalPadding)
        .padding(.top, 0)
        .padding(.bottom, 18)
    }

    private var loadingMoreSkeletonStyle: VideoFeedSkeletonCard.Style {
        switch metrics.mode {
        case .borderedSingleColumn:
            return .borderedSingleColumn(
                coverSize: metrics.borderedSingleColumnCoverSize ?? CGSize(width: 140, height: 88)
            )
        case .singleColumn, .doubleColumn, .borderedDoubleColumn:
            return .singleColumn
        }
    }
}
