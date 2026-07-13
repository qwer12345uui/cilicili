import Foundation

extension HomeFeedImagePrefetchPlan {
    nonisolated static func targetPixelSize(for layout: HomeFeedLayout) -> Int {
        switch layout {
        case .singleColumn:
            return 720
        case .borderedSingleColumn, .doubleColumn, .borderedDoubleColumn:
            return 480
        }
    }

    nonisolated static func homeCoverImageSource(
        source: String,
        layout: HomeFeedLayout,
        targetPixelSize: Int
    ) -> RemoteImageSource? {
        let urlString: String
        switch layout {
        case .singleColumn:
            urlString = source.biliImageThumbnailURL(maxSide: targetPixelSize)
        case .doubleColumn:
            let coverHeight = Int(Double(targetPixelSize) * 9.0 / 16.0)
            urlString = source.biliCoverThumbnailURL(width: targetPixelSize, height: coverHeight)
        case .borderedSingleColumn, .borderedDoubleColumn:
            let coverHeight = Int(Double(targetPixelSize) * 10.0 / 16.0)
            urlString = source.biliCoverThumbnailURL(width: targetPixelSize, height: coverHeight)
        }
        guard let url = URL(string: urlString) else { return nil }
        return RemoteImageSource(url: url, fallbackURL: URL(string: source))
    }
}
