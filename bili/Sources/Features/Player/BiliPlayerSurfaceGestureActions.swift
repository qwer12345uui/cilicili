import SwiftUI

struct BiliPlayerSurfaceGestureActions {
    let viewModel: PlayerStateViewModel
    let visibilityActions: BiliPlayerPlaybackControlsVisibilityActions
    let speedBoostActions: BiliPlayerSpeedBoostActions
    let holdCurrentFrameForSeek: () -> Void
    let prepareUserSeekWarmup: (Double, Bool) -> Void
    let resetPreparedScrubProgress: () -> Void

    func singleTap() {
        guard !viewModel.isTerminated else { return }
        viewModel.togglePlayback()
        visibilityActions.showAndSchedule()
    }

    func doubleTap() {
        guard !viewModel.isTerminated else { return }
        visibilityActions.toggle()
    }

    func beginSpeedBoost() {
        guard !viewModel.isTerminated else { return }
        speedBoostActions.beginIfNeeded()
    }

    func endSpeedBoost() {
        guard !viewModel.isTerminated else {
            speedBoostActions.end(reason: "terminated")
            return
        }
        speedBoostActions.end(reason: "gestureEnded")
    }

    func horizontalSeekStart(_ progress: Double) {
        guard !viewModel.isTerminated else { return }
        visibilityActions.markInteraction(keepsVisible: true)
        prepareUserSeekWarmup(progress, true)
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
        viewModel.playbackClock.clearSeekPreview()
        resetPreparedScrubProgress()
        visibilityActions.markInteraction()
    }
}
