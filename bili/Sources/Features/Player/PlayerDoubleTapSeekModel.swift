import Combine
import CoreGraphics
import QuartzCore
import SwiftUI

enum PlayerDoubleTapSeekTarget: Equatable {
    case backward
    case center
    case forward
}

enum PlayerDoubleTapSeekDirection: Equatable {
    case backward
    case forward

    var systemImage: String {
        switch self {
        case .backward:
            "gobackward.10"
        case .forward:
            "goforward.10"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .backward:
            "快退"
        case .forward:
            "快进"
        }
    }
}

nonisolated enum PlayerDoubleTapSeekPolicy {
    static let stepInterval: TimeInterval = 10

    static func target(locationX: CGFloat, width: CGFloat) -> PlayerDoubleTapSeekTarget {
        guard width > 0 else { return .center }
        let progress = min(max(locationX / width, 0), 1)
        if progress < 0.25 {
            return .backward
        }
        if progress >= 0.75 {
            return .forward
        }
        return .center
    }
}

struct PlayerDoubleTapSeekPresentation: Equatable {
    let direction: PlayerDoubleTapSeekDirection
    let offset: TimeInterval
    let targetTime: TimeInterval
    let duration: TimeInterval
}

@MainActor
final class PlayerDoubleTapSeekModel: ObservableObject {
    @Published private(set) var presentation: PlayerDoubleTapSeekPresentation?

    private let dismissDelayNanoseconds: UInt64 = 800_000_000
    private var dismissalTask: Task<Void, Never>?
    private var dismissalGeneration = 0
    private var lastDirection: PlayerDoubleTapSeekDirection?
    private var lastUpdateTime: CFTimeInterval?
    private var burstStartTime: TimeInterval?

    deinit {
        dismissalTask?.cancel()
    }

    func present(
        direction: PlayerDoubleTapSeekDirection,
        sourceTime: TimeInterval,
        targetTime: TimeInterval,
        duration: TimeInterval
    ) {
        guard duration > 0 else { return }
        let clampedTarget = min(max(targetTime, 0), duration)
        guard abs(clampedTarget - sourceTime) >= 0.25 else { return }

        let now = CACurrentMediaTime()
        let continuesBurst = lastDirection == direction
            && (lastUpdateTime.map { now - $0 <= 0.8 } ?? false)
        if !continuesBurst {
            burstStartTime = sourceTime
        }
        let offset = clampedTarget - (burstStartTime ?? sourceTime)
        guard abs(offset) >= 0.25 else { return }

        lastDirection = direction
        lastUpdateTime = now
        withAnimation(.easeInOut(duration: 0.16)) {
            presentation = PlayerDoubleTapSeekPresentation(
                direction: direction,
                offset: offset,
                targetTime: clampedTarget,
                duration: duration
            )
        }
        Haptics.light()
        scheduleDismissal()
    }

    func dismiss() {
        dismissalTask?.cancel()
        dismissalTask = nil
        dismissalGeneration &+= 1
        lastDirection = nil
        lastUpdateTime = nil
        burstStartTime = nil
        withAnimation(.easeInOut(duration: 0.16)) {
            presentation = nil
        }
    }

    private func scheduleDismissal() {
        dismissalTask?.cancel()
        dismissalGeneration &+= 1
        let generation = dismissalGeneration
        dismissalTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.dismissDelayNanoseconds ?? 0)
            guard let self,
                  !Task.isCancelled,
                  self.dismissalGeneration == generation
            else { return }
            self.dismiss()
        }
    }
}
