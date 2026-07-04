import Foundation

extension VideoDetailViewModel {
    func preparePlayURLRecoveryRetry() async {
        await PlayURLCache.shared.invalidate(bvid: detail.bvid)
        await VideoPreloadCenter.shared.invalidatePlayURLCache(for: detail.bvid)
        await api.clearCachedPlayURLFailures(bvid: detail.bvid)
        cancelStartupPlayURLTask()
    }

    func fetchStartupPlayURLForRecovery(
        cid: Int,
        page: Int?
    ) async throws -> PlayURLData {
        try await fetchPlayURLWithTimeout(
            timeout: playURLRecoveryTimeoutNanoseconds
        ) { [self] in
            try await startupPlayURL(bvid: detail.bvid, cid: cid, page: page)
        }
    }

    func fetchFullPlayURLForRecovery(
        cid: Int,
        page: Int?
    ) async throws -> PlayURLData {
        try await fetchPlayURLWithTimeout(
            timeout: playURLFullRecoveryTimeoutNanoseconds
        ) { [self] in
            if detail.isPGCEpisode {
                return try await api.fetchPgcPlayURL(
                    bvid: detail.bvid,
                    cid: cid,
                    seasonID: detail.pgcSeasonID,
                    epID: detail.pgcEpisodeID,
                    preferredQuality: adaptiveStartupPreferredQuality
                )
            }
            return try await api.fetchPlayURL(
                bvid: detail.bvid,
                cid: cid,
                page: page,
                preferredQuality: adaptiveStartupPreferredQuality,
                supplementsQualities: false,
                preferProgressiveFastStart: false
            )
        }
    }
}
