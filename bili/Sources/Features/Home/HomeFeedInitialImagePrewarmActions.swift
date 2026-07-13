import Foundation

extension HomeFeedMediaPreloadCoordinator {
    func prewarmInitialImagesBeforePublishing(_ videos: [VideoItem]) async {
        let prefetchPlan = HomeFeedImagePrefetchPlan.make(
            for: videos,
            layout: libraryStore.homeFeedLayout,
            limit: 3
        )
        guard !prefetchPlan.coverSources.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await RemoteImageCache.shared.prefetch(
                    prefetchPlan.coverSources,
                    targetPixelSize: prefetchPlan.coverTargetPixelSize,
                    maximumConcurrentLoads: 1
                )
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 320_000_000)
            }
            _ = await group.next()
            group.cancelAll()
        }
    }
}
