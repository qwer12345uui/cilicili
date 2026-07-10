import Combine
import Foundation

struct VideoDetailPerformanceExperimentSnapshot: Equatable {
    var isEnabled = false
    var isBareSurfaceTransitionActive = false
    var overlayPublishCount = 0
    var overlayDeferredCount = 0
    var overlayFlushCount = 0
    var rotationTransitionCount = 0
    var lastBareSurfaceDurationMilliseconds = 0
    var totalBareSurfaceDurationMilliseconds = 0
    var lastEvent = "未启用"

    nonisolated init(
        isEnabled: Bool = false,
        isBareSurfaceTransitionActive: Bool = false,
        overlayPublishCount: Int = 0,
        overlayDeferredCount: Int = 0,
        overlayFlushCount: Int = 0,
        rotationTransitionCount: Int = 0,
        lastBareSurfaceDurationMilliseconds: Int = 0,
        totalBareSurfaceDurationMilliseconds: Int = 0,
        lastEvent: String = "未启用"
    ) {
        self.isEnabled = isEnabled
        self.isBareSurfaceTransitionActive = isBareSurfaceTransitionActive
        self.overlayPublishCount = overlayPublishCount
        self.overlayDeferredCount = overlayDeferredCount
        self.overlayFlushCount = overlayFlushCount
        self.rotationTransitionCount = rotationTransitionCount
        self.lastBareSurfaceDurationMilliseconds = lastBareSurfaceDurationMilliseconds
        self.totalBareSurfaceDurationMilliseconds = totalBareSurfaceDurationMilliseconds
        self.lastEvent = lastEvent
    }

    var isVisible: Bool {
        isEnabled
    }
}

@MainActor
final class VideoDetailPerformanceExperimentState: ObservableObject {
    @Published private(set) var snapshot = VideoDetailPerformanceExperimentSnapshot()
    private var bareSurfaceTransitionBeganAt: Date?

    func setEnabled(_ isEnabled: Bool) {
        update { snapshot in
            snapshot.isEnabled = isEnabled
            snapshot.lastEvent = isEnabled ? "实验已开启" : "实验已关闭"
        }
    }

    func setBareSurfaceTransitionActive(_ active: Bool) {
        let now = Date()
        update { snapshot in
            guard snapshot.isBareSurfaceTransitionActive != active else { return }
            snapshot.isBareSurfaceTransitionActive = active
            if active {
                bareSurfaceTransitionBeganAt = now
                snapshot.rotationTransitionCount += 1
                snapshot.lastEvent = "旋转中：冻结叠层刷新"
            } else {
                let elapsedMilliseconds = bareSurfaceTransitionBeganAt
                    .map { max(0, Int((now.timeIntervalSince($0) * 1_000).rounded())) }
                    ?? 0
                bareSurfaceTransitionBeganAt = nil
                if elapsedMilliseconds > 0 {
                    snapshot.lastBareSurfaceDurationMilliseconds = elapsedMilliseconds
                    snapshot.totalBareSurfaceDurationMilliseconds += elapsedMilliseconds
                }
                snapshot.lastEvent = "旋转结束：恢复叠层刷新"
            }
        }
    }

    func recordOverlayPublish() {
        update { snapshot in
            snapshot.overlayPublishCount += 1
            snapshot.lastEvent = "叠层快照已发布"
        }
    }

    func recordOverlayDeferred() {
        update { snapshot in
            snapshot.overlayDeferredCount += 1
            snapshot.lastEvent = "旋转中暂存叠层更新"
        }
    }

    func recordOverlayFlush() {
        update { snapshot in
            snapshot.overlayFlushCount += 1
            snapshot.lastEvent = "恢复后合并发布叠层更新"
        }
    }

    private func update(_ transform: (inout VideoDetailPerformanceExperimentSnapshot) -> Void) {
        var next = snapshot
        transform(&next)
        guard next != snapshot else { return }
        snapshot = next
    }
}
