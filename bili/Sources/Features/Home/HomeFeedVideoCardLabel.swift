import SwiftUI

struct HomeFeedVideoCardLabel: View {
    let metrics: HomeFeedLayoutMetrics
    let display: VideoCardDisplayModel
    var showsAuthorIdentity = true

    var body: some View {
        switch metrics.mode {
        case .singleColumn:
            YouTubeStyleVideoFeedCardView(
                display: display,
                fixedCoverAspectRatio: 16 / 9,
                fixedCoverSize: metrics.singleColumnFixedCoverSize,
                coverMaximumPixelLength: 720
            )
            .equatable()
        case .borderedSingleColumn:
            VideoCardBorderedCompactBody(
                display: display,
                coverSize: metrics.borderedSingleColumnCoverSize ?? CGSize(width: 140, height: 88)
            )
            .equatable()
        case .doubleColumn:
            VideoCardView(
                display: display,
                showsPublishTimeInAuthorRow: true,
                showsAuthorIdentity: showsAuthorIdentity,
                showsCoverViewCountBadge: false,
                surfaceStyle: .blended,
                fixedCoverSize: metrics.doubleColumnFixedCoverSize,
                coverMaximumPixelLength: 480
            )
            .equatable()
        case .borderedDoubleColumn:
            VideoCardView(
                display: display,
                showsPublishTimeInAuthorRow: true,
                showsAuthorIdentity: showsAuthorIdentity,
                showsCoverViewCountBadge: false,
                surfaceStyle: .bordered,
                coverAspectRatio: 16 / 10,
                fixedCoverSize: metrics.doubleColumnFixedCoverSize,
                coverMaximumPixelLength: 480
            )
            .equatable()
        }
    }
}
