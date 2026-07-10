import Foundation

extension VideoDetailViewModel {
    func resumePlaybackAfterCoveredNavigationIfNeeded() async {
        guard isPlaybackInvalidatedForNavigation || isPlaybackTerminatedForNavigation else { return }
        navigationState.playbackStopTask?.cancel()
        navigationState.playbackStopTask = nil
        isPlaybackInvalidatedForNavigation = false
        isPlaybackTerminatedForNavigation = false

        if let player = stablePlayerViewModel {
            _ = player.restoreAudioAfterCancelledNavigation()
            clearPendingNavigationResumeState()
            return
        }

        await load()
    }

    private func clearPendingNavigationResumeState() {
        shouldResumePlaybackAfterCancelledNavigation = false
        pendingNavigationResumeTime = nil
        hasPendingNavigationInterruption = false
    }
}
