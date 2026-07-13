import Foundation

nonisolated struct HomeFeedImagePrefetchPlan {
    let coverSources: [RemoteImageSource]
    let coverTargetPixelSize: Int

    static func make(
        for videos: [VideoItem],
        layout: HomeFeedLayout,
        limit: Int
    ) -> HomeFeedImagePrefetchPlan {
        var seenCovers = Set<String>()
        var coverSources = [RemoteImageSource]()
        let coverTargetPixelSize = targetPixelSize(for: layout)

        for video in videos.prefix(limit) {
            if let source = video.pic?.normalizedBiliURL(),
               let coverSource = homeCoverImageSource(
                source: source,
                layout: layout,
                targetPixelSize: coverTargetPixelSize
               ),
               seenCovers.insert(source).inserted {
                coverSources.append(coverSource)
            }
        }

        return HomeFeedImagePrefetchPlan(
            coverSources: coverSources,
            coverTargetPixelSize: coverTargetPixelSize
        )
    }
}
