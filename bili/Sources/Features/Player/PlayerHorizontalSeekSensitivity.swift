import Foundation

enum PlayerHorizontalSeekSensitivity {
    static func secondsPerFullWidth(duration: TimeInterval?) -> TimeInterval {
        guard let duration, duration.isFinite, duration > 0 else { return 90 }
        return min(max(duration * 0.1, 45), 360)
    }
}
