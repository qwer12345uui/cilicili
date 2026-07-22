import Foundation

extension VideoDetailViewModel {
    func replacingVariant(
        in variants: [PlayVariant],
        matching id: String,
        with replacement: PlayVariant
    ) -> [PlayVariant] {
        variants.map { $0.id == id ? replacement : $0 }
    }

    func scheduleSupplementalTargetQualityLoadIfNeeded(
        variants: [PlayVariant],
        cid: Int?,
        page: Int?
    ) {
        guard let cid,
              needsSupplementalTargetQuality(variants)
        else { return }
        scheduleSupplementalPlayURLLoad(
            cid: cid,
            page: page,
            waitsForFirstFrame: true,
            startDelay: 0.28
        )
    }

    private func shouldSupplementPlayQualities(for variants: [PlayVariant]) -> Bool {
        guard sessionStore.isLoggedIn,
              currentPlayURLData?.hasAdvertisedQualityMissingMediaStream == true
        else { return false }
        return variants.contains { !$0.isPlayable && $0.videoURL == nil }
    }

    func supplementalPlayURLPreferredQuality() -> Int? {
        currentPlayURLData?.preferredQualityForMissingStreamSupplement(
            fallback: targetPlaybackPreferredQuality
        ) ?? targetPlaybackPreferredQuality
    }

    private func needsSupplementalTargetQuality(_ variants: [PlayVariant]) -> Bool {
        let playableVariants = variants.filter(\.isPlayable)
        guard !playableVariants.isEmpty,
              let currentPlayURLData
        else { return false }
        return shouldRefetchForPreferredQuality(currentPlayURLData)
            || shouldSupplementPlayQualities(for: variants)
    }

    private func playVariantsNeedSupplementalFrameRateUpgrade(_ variants: [PlayVariant]) -> Bool {
        let playableVariants = variants.filter(\.isPlayable)
        guard !playableVariants.isEmpty else { return false }
        guard let preferredQuality = libraryStore.effectivePreferredVideoQuality else { return false }
        guard [116, 74].contains(preferredQuality) else { return false }
        return !playableVariants.contains { $0.satisfiesPreferredQuality(preferredQuality) }
    }
}
