import Foundation
import QuartzCore

extension VideoDetailViewModel {
    private static var startupPackageWarmupPlayerCreationWait: TimeInterval { 0.08 }
    private static var cachedPlayURLStartupPackageWarmupPlayerCreationWait: TimeInterval { 0.16 }
    private static var slowPlayURLStartupPackageWarmupPlayerCreationWait: TimeInterval { 0.24 }
    private static var slowPlayURLWarmupThresholdMilliseconds: Int { 350 }

    func schedulePostPlayURLApplicationWork(
        variants: [PlayVariant],
        selectedVariant: PlayVariant?,
        targetVariant: PlayVariant?,
        cid: Int?,
        page: Int?,
        schedulesSupplementalLoad: Bool
    ) async {
        guard !isPlaybackInvalidatedForNavigation else { return }
        cancelFastStartUpgradeTask()
        scheduleSelectedStartupPackageWarmupBeforeFirstFrame(
            selectedVariant,
            targetVariant: targetVariant,
            cid: cid,
            page: page
        )
        scheduleSelectedStartupPackageWarmupAfterFirstFrame(selectedVariant, cid: cid, page: page)
        await waitForStartupPackageWarmupBeforePlayerCreationIfNeeded(
            selectedVariant,
            targetVariant: targetVariant,
            cid: cid,
            page: page
        )
        updateStablePlayerViewModelIfNeeded()
        playURLState = .loaded
        warmSelectedVariantAfterFirstFrameIfNeeded(selectedVariant, cid: cid, page: page)
        scheduleAutomaticCDNRecommendationAfterFirstFrameIfNeeded(cid: cid, page: page)
        rankPlaybackCDNCandidatesAfterFirstFrameIfNeeded(selectedVariant, cid: cid)
        scheduleHLSRenditionPrebuildAfterFirstFrameIfNeeded(
            startupVariant: selectedVariant,
            targetVariant: targetVariant,
            cid: cid,
            page: page
        )
        clearSupplementalPlayURLState()
        if schedulesSupplementalLoad {
            scheduleSupplementalTargetQualityLoadIfNeeded(
                variants: variants,
                cid: cid,
                page: page
            )
        }
    }

    private func waitForStartupPackageWarmupBeforePlayerCreationIfNeeded(
        _ selectedVariant: PlayVariant?,
        targetVariant: PlayVariant?,
        cid: Int?,
        page: Int?
    ) async {
        guard stablePlayerViewModel == nil,
              !isPlaybackInvalidatedForNavigation,
              let cid,
              let selectedVariant,
              selectedVariant.isPlayable
        else { return }

        let bvid = detail.bvid
        let selectedVariantID = selectedVariant.id
        let startedAt = CACurrentMediaTime()
        let timeout = startupPackageWarmupPlayerCreationWaitForCurrentLoad(selectedVariant)
        let result = await VideoPreloadCenter.shared.prebuildStartupPackageAndWait(
            variant: selectedVariant,
            targetVariant: targetVariant,
            bvid: bvid,
            cid: cid,
            page: page,
            durationHint: detail.duration.map(TimeInterval.init),
            cdnPreference: libraryStore.effectivePlaybackCDNPreference,
            timeout: timeout
        )
        let elapsedMilliseconds = PlayerMetricsLog.elapsedMilliseconds(since: startedAt)
        guard !isPlaybackInvalidatedForNavigation,
              detail.bvid == bvid,
              selectedCID == cid,
              selectedPlayVariant?.id == selectedVariantID
        else { return }
        PlayerMetricsLog.record(
            .manifestStage,
            metricsID: bvid,
            message: [
                "startupWarmWait=\(result.rawValue)",
                "\(Int(elapsedMilliseconds.rounded()))ms",
                "budget=\(Int((timeout * 1000).rounded()))ms",
                "codec=\(selectedVariant.codec?.replacingOccurrences(of: " ", with: "_") ?? "-")"
            ].joined(separator: " ")
        )
    }

    private func startupPackageWarmupPlayerCreationWaitForCurrentLoad(_: PlayVariant) -> TimeInterval {
        let isSlowPlayURL = (playURLElapsedMilliseconds ?? 0) >= Self.slowPlayURLWarmupThresholdMilliseconds
        if isSlowPlayURL {
            return Self.slowPlayURLStartupPackageWarmupPlayerCreationWait
        }
        if lastPlayURLSource?.localizedCaseInsensitiveContains("cache") == true {
            return Self.cachedPlayURLStartupPackageWarmupPlayerCreationWait
        }
        return Self.startupPackageWarmupPlayerCreationWait
    }
}
