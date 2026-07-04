import Foundation

extension VideoDetailViewModel {
    func prepareHistoryResumeBeforeApplyingPlayURL(_ data: PlayURLData, cid: Int) async -> Bool {
        guard stablePlayerViewModel == nil else { return false }
        if redirectToHistoryCIDIfNeeded(data.lastPlayCID, currentCID: cid) {
            return true
        }
        if redirectToHistoryCIDIfNeeded(detail.historyCID, currentCID: cid) {
            return true
        }
        if let resumeTime = data.resumeTime(duration: historyResumeDurationHint) {
            setPendingPlaybackHistoryResumeTime(resumeTime, cid: cid)
            return false
        }
        if let resumeTime = detail.historyResumeTime,
           resumeTime > 0.25,
           detail.historyCID == nil || detail.historyCID == cid {
            setPendingPlaybackHistoryResumeTime(resumeTime, cid: cid)
            return false
        }
        guard pendingPlaybackHistoryResumeTime == nil else { return false }
        await prepareCloudHistoryResumeIfNeeded(currentCID: cid)
        return selectedCID != cid
    }

    func consumePendingPlaybackHistoryResumeTime(for cid: Int?) -> TimeInterval? {
        guard stablePlayerViewModel == nil,
              let resumeTime = pendingPlaybackHistoryResumeTime,
              resumeTime > 0.25
        else { return nil }
        if let pendingCID = pendingPlaybackHistoryResumeCID,
           let cid,
           pendingCID != cid {
            return nil
        }
        pendingPlaybackHistoryResumeTime = nil
        pendingPlaybackHistoryResumeCID = nil
        return resumeTime
    }

    private var historyResumeDurationHint: TimeInterval? {
        detail.duration.map(TimeInterval.init)
    }

    private func prepareCloudHistoryResumeIfNeeded(currentCID: Int) async {
        guard !didResolveCloudHistoryResume else { return }
        didResolveCloudHistoryResume = true
        guard !libraryStore.incognitoModeEnabled,
              let aid = detail.aid
        else { return }
        do {
            let history = try await api.fetchVideoHistoryProgress(aid: aid)
            let targetCID = matchingHistoryCID(history.lastPlayCid) ?? currentCID
            if let resumeTime = history.resumeTime(duration: historyResumeDurationHint) {
                setPendingPlaybackHistoryResumeTime(resumeTime, cid: targetCID)
            }
            if targetCID != currentCID {
                selectedCID = targetCID
            }
        } catch {
            return
        }
    }

    private func redirectToHistoryCIDIfNeeded(_ rawCID: Int?, currentCID: Int) -> Bool {
        guard let targetCID = matchingHistoryCID(rawCID),
              targetCID != currentCID
        else { return false }
        selectedCID = targetCID
        return true
    }

    private func matchingHistoryCID(_ rawCID: Int?) -> Int? {
        guard let rawCID, rawCID > 0 else { return nil }
        guard let pages = detail.pages, !pages.isEmpty else { return rawCID }
        return pages.contains(where: { $0.cid == rawCID }) ? rawCID : nil
    }

    private func setPendingPlaybackHistoryResumeTime(
        _ resumeTime: TimeInterval,
        cid: Int?
    ) {
        pendingPlaybackHistoryResumeTime = resumeTime
        pendingPlaybackHistoryResumeCID = cid
    }
}
