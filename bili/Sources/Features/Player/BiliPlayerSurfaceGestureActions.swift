import SwiftUI

struct BiliPlayerSurfaceGestureActions {
    let viewModel: PlayerStateViewModel
    let visibilityActions: BiliPlayerPlaybackControlsVisibilityActions
    let speedBoostActions: BiliPlayerSpeedBoostActions
    let doubleTapSeekModel: PlayerDoubleTapSeekModel
    let holdCurrentFrameForSeek: () -> Void
    let prepareUserSeekWarmup: (Double, Bool) -> Void
    let resetPreparedScrubProgress: () -> Void

    func singleTap() {
        guard !viewModel.isTerminated else { return }
        viewModel.togglePlayback()
        visibilityActions.showAndSchedule()
    }

    func doubleTap(target: PlayerDoubleTapSeekTarget) {
        guard !viewModel.isTerminated else { return }
        guard target != .center else {
            visibilityActions.toggle()
            return
        }
        guard !viewModel.isLiveStream, viewModel.canSeek else {
            visibilityActions.toggle()
            return
        }

        let sourceTime = viewModel.currentTime
        let interval: TimeInterval
        let direction: PlayerDoubleTapSeekDirection
        switch target {
        case .backward:
            interval = -PlayerDoubleTapSeekPolicy.stepInterval
            direction = .backward
        case .forward:
            interval = PlayerDoubleTapSeekPolicy.stepInterval
            direction = .forward
        case .center:
            return
        }

        guard let targetTime = viewModel.seek(by: interval, source: "doubleTap") else { return }
        doubleTapSeekModel.present(
            direction: direction,
            sourceTime: sourceTime,
            targetTime: targetTime,
            duration: viewModel.displayDuration ?? viewModel.playbackClock.duration ?? 0
        )
    }

    func beginSpeedBoost() -> Bool {
        speedBoostActions.beginIfNeeded()
    }

    func endSpeedBoost(reason: PlayerSpeedBoostEndReason) {
        speedBoostActions.end(reason: reason)
    }

    func horizontalSeekStart(_ progress: Double) {
        guard !viewModel.isTerminated else { return }
        visibilityActions.markInteraction(keepsVisible: true)
        prepareUserSeekWarmup(progress, true)
        viewModel.beginUserScrubInteraction(source: .surfaceGesture)
    }

    func horizontalSeekChanged(_ progress: Double) {
        guard !viewModel.isTerminated else { return }
        prepareUserSeekWarmup(progress, false)
    }

    func horizontalSeekEnded(_ progress: Double) {
        guard !viewModel.isTerminated else {
            viewModel.playbackClock.clearSeekPreview()
            resetPreparedScrubProgress()
            return
        }
        prepareUserSeekWarmup(progress, true)
        holdCurrentFrameForSeek()
        viewModel.seekAfterSliderCommit(to: progress)
        viewModel.playbackClock.clearSeekPreview()
        resetPreparedScrubProgress()
        visibilityActions.markInteraction()
    }

    func horizontalSeekCancelled() {
        viewModel.cancelUserScrubInteraction()
        viewModel.playbackClock.clearSeekPreview()
        resetPreparedScrubProgress()
        visibilityActions.markInteraction()
    }
}
