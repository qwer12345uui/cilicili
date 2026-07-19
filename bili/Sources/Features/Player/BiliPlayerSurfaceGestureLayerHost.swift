import SwiftUI

struct BiliPlayerSurfaceGestureLayerHost<Content: View>: View {
    let content: Content
    let visibilityActions: BiliPlayerPlaybackControlsVisibilityActions
    let speedBoostActions: BiliPlayerSpeedBoostActions
    let doubleTapSeekModel: PlayerDoubleTapSeekModel
    let viewModel: PlayerStateViewModel
    @ObservedObject var seekPreviewModel: PlayerSeekPreviewModel
    let seekPreviewAPI: BiliAPIClient?
    let seekPreviewContext: PlayerSeekPreviewContext?
    let holdCurrentFrameForSeek: () -> Void
    let prepareUserSeekWarmup: (Double, Bool) -> Void
    let resetPreparedScrubProgress: () -> Void

    private var gestureActions: BiliPlayerSurfaceGestureActions {
        BiliPlayerSurfaceGestureActions(
            viewModel: viewModel,
            visibilityActions: visibilityActions,
            speedBoostActions: speedBoostActions,
            doubleTapSeekModel: doubleTapSeekModel,
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
            onDoubleTap: gestureActions.doubleTap(target:),
            onBeginSpeedBoost: gestureActions.beginSpeedBoost,
            onEndSpeedBoost: gestureActions.endSpeedBoost(reason:),
            onHorizontalSeekStart: { progress in
                seekPreviewModel.beginScrub(
                    api: seekPreviewAPI,
                    context: seekPreviewContext,
                    source: .surfaceGesture,
                    progress: progress,
                    duration: resolvedDuration
                )
                gestureActions.horizontalSeekStart(progress)
            },
            onHorizontalSeekChanged: { progress in
                seekPreviewModel.updateScrub(progress: progress, duration: resolvedDuration)
                gestureActions.horizontalSeekChanged(progress)
            },
            onHorizontalSeekEnded: { progress in
                seekPreviewModel.endScrub()
                gestureActions.horizontalSeekEnded(progress)
            },
            onHorizontalSeekCancelled: {
                seekPreviewModel.endScrub()
                gestureActions.horizontalSeekCancelled()
            },
            onHorizontalSeekCancelPendingChanged: { isPending in
                seekPreviewModel.setCancellationPending(isPending)
            }
        )
        .onDisappear {
            seekPreviewModel.endScrub()
            speedBoostActions.end(reason: .disappear)
            doubleTapSeekModel.dismiss()
        }
    }

    private var resolvedDuration: TimeInterval {
        viewModel.playbackClock.duration ?? viewModel.displayDuration ?? 0
    }
}
