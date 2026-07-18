import SwiftUI

struct BiliPlayerSurfaceGestureLayer<Content: View>: View {
    let content: Content
    let clock: PlayerPlaybackClock
    let durationHint: TimeInterval?
    let canSeek: Bool
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    let onBeginSpeedBoost: () -> Void
    let onEndSpeedBoost: () -> Void
    let onHorizontalSeekStart: (Double) -> Void
    let onHorizontalSeekChanged: (Double) -> Void
    let onHorizontalSeekEnded: (Double) -> Void
    let onHorizontalSeekCancelled: () -> Void
    let onHorizontalSeekCancelPendingChanged: (Bool) -> Void

    @State private var horizontalSeekStartProgress: Double?
    @State private var horizontalSeekCurrentProgress: Double?
    @State private var horizontalSeekLastTranslationWidth: CGFloat?
    @State private var lastReportedHorizontalSeekProgress: Double?
    @State private var isHorizontalSeeking = false
    @State private var isHorizontalSeekCancelPending = false
    @State private var isSpeedBoostGestureActive = false

    private let horizontalSeekActivationDistance: CGFloat = 8
    private let horizontalSeekDominanceRatio: CGFloat = 3
    private let horizontalSeekChangeReportDelta = 0.004

    var body: some View {
        GeometryReader { proxy in
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 2)
                    .exclusively(before: TapGesture(count: 1))
                    .onEnded { value in
                        switch value {
                        case .first:
                            onSingleTap()
                        case .second:
                            onDoubleTap()
                        }
                    }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.28, maximumDistance: 80)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onChanged { value in
                        guard !isHorizontalSeeking else { return }
                        guard case .second(true, _) = value else { return }
                        isSpeedBoostGestureActive = true
                        onBeginSpeedBoost()
                    }
                    .onEnded { _ in
                        isSpeedBoostGestureActive = false
                        onEndSpeedBoost()
                    }
            )
            .simultaneousGesture(horizontalSeekGesture(size: proxy.size))
        }
    }

    private func horizontalSeekGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: horizontalSeekActivationDistance, coordinateSpace: .local)
            .onChanged { value in
                guard canSeek, !isSpeedBoostGestureActive else { return }
                updateHorizontalSeek(for: value, size: size)
            }
            .onEnded { value in
                guard canSeek, isHorizontalSeeking else {
                    if isHorizontalSeeking {
                        onHorizontalSeekCancelled()
                    }
                    resetHorizontalSeekState(clearsClockPreview: true)
                    return
                }
                updateHorizontalSeek(for: value, size: size)
                guard !isHorizontalSeekCancelPending else {
                    onHorizontalSeekCancelled()
                    resetHorizontalSeekState(clearsClockPreview: true)
                    return
                }
                let progress = horizontalSeekCurrentProgress
                    ?? lastReportedHorizontalSeekProgress
                    ?? horizontalSeekStartProgress
                    ?? clock.progress
                onHorizontalSeekEnded(progress)
                resetHorizontalSeekState(clearsClockPreview: false)
            }
    }

    private func updateHorizontalSeek(for value: DragGesture.Value, size: CGSize) {
        guard let duration = resolvedDuration, duration > 0 else { return }
        guard size.width > 0 else { return }
        let dx = value.translation.width
        let dy = value.translation.height
        if !isHorizontalSeeking {
            guard abs(dx) >= horizontalSeekActivationDistance else { return }
            guard abs(dx) > abs(dy) * horizontalSeekDominanceRatio else { return }
            let startProgress = clock.progress
            isHorizontalSeeking = true
            horizontalSeekStartProgress = startProgress
            horizontalSeekCurrentProgress = startProgress
            horizontalSeekLastTranslationWidth = dx
            isHorizontalSeekCancelPending = horizontalSeekShouldCancel(at: value.location, size: size)
            clock.updateSeekPreview(progress: startProgress, force: true)
            onEndSpeedBoost()
            onHorizontalSeekStart(startProgress)
            onHorizontalSeekCancelPendingChanged(isHorizontalSeekCancelPending)
            return
        }

        let previousTranslationWidth = horizontalSeekLastTranslationWidth ?? dx
        horizontalSeekLastTranslationWidth = dx
        let deltaX = dx - previousTranslationWidth
        let currentProgress = horizontalSeekCurrentProgress
            ?? horizontalSeekStartProgress
            ?? clock.progress
        let secondsPerFullWidth = PlayerHorizontalSeekSensitivity.secondsPerFullWidth(duration: duration)
        let progressDelta = Double(deltaX / size.width) * secondsPerFullWidth / duration
        let progress = min(max(currentProgress + progressDelta, 0), 1)
        horizontalSeekCurrentProgress = progress
        clock.updateSeekPreview(progress: progress)
        isHorizontalSeekCancelPending = horizontalSeekShouldCancel(at: value.location, size: size)
        onHorizontalSeekCancelPendingChanged(isHorizontalSeekCancelPending)
        reportHorizontalSeekChanged(progress)
    }

    private var resolvedDuration: TimeInterval? {
        clock.duration ?? durationHint
    }

    private func reportHorizontalSeekChanged(_ progress: Double) {
        let clamped = min(max(progress, 0), 1)
        guard let lastReportedHorizontalSeekProgress else {
            lastReportedHorizontalSeekProgress = clamped
            clock.updateSeekPreview(progress: clamped)
            onHorizontalSeekChanged(clamped)
            return
        }
        guard abs(clamped - lastReportedHorizontalSeekProgress) >= horizontalSeekChangeReportDelta else { return }
        self.lastReportedHorizontalSeekProgress = clamped
        onHorizontalSeekChanged(clamped)
    }

    private func resetHorizontalSeekState(clearsClockPreview: Bool) {
        horizontalSeekStartProgress = nil
        horizontalSeekCurrentProgress = nil
        horizontalSeekLastTranslationWidth = nil
        lastReportedHorizontalSeekProgress = nil
        isHorizontalSeeking = false
        isHorizontalSeekCancelPending = false
        if clearsClockPreview {
            clock.clearSeekPreview()
        }
    }

    private func horizontalSeekShouldCancel(at location: CGPoint, size: CGSize) -> Bool {
        guard size.width > 0, size.height > 0 else { return false }
        let topCancelHeight = size.height * 0.125
        let edgeCancelWidth = size.width * 0.125
        return location.y <= topCancelHeight
            && (location.x <= edgeCancelWidth || location.x >= size.width - edgeCancelWidth)
    }
}
