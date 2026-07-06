import SwiftUI

struct BiliPlayerSurfaceGestureLayerHost<Content: View>: View {
    let content: Content
    let visibilityActions: BiliPlayerPlaybackControlsVisibilityActions
    let speedBoostActions: BiliPlayerSpeedBoostActions
    let viewModel: PlayerStateViewModel
    let holdCurrentFrameForSeek: () -> Void
    let prepareUserSeekWarmup: (Double, Bool) -> Void
    let resetPreparedScrubProgress: () -> Void

    private var gestureActions: BiliPlayerSurfaceGestureActions {
        BiliPlayerSurfaceGestureActions(
            viewModel: viewModel,
            visibilityActions: visibilityActions,
            speedBoostActions: speedBoostActions,
            holdCurrentFrameForSeek: holdCurrentFrameForSeek,
            prepareUserSeekWarmup: prepareUserSeekWarmup,
            resetPreparedScrubProgress: resetPreparedScrubProgress
        )
    }

    var body: some View {
        BiliPlayerSurfaceGestureLayer(
            content: content,
            clock: viewModel.playbackClock,
            durationHint: viewModel.displayDuration,
            canSeek: viewModel.canSeek,
            onSingleTap: gestureActions.singleTap,
            onDoubleTap: gestureActions.doubleTap,
            onBeginSpeedBoost: gestureActions.beginSpeedBoost,
            onEndSpeedBoost: gestureActions.endSpeedBoost,
            onHorizontalSeekStart: gestureActions.horizontalSeekStart,
            onHorizontalSeekChanged: gestureActions.horizontalSeekChanged,
            onHorizontalSeekEnded: gestureActions.horizontalSeekEnded,
            onHorizontalSeekCancelled: gestureActions.horizontalSeekCancelled
        )
    }
}
