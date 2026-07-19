import CoreGraphics

nonisolated enum PlayerDoubleTapGesturePolicy {
    static func shouldTogglePlayback(locationX: CGFloat, width: CGFloat) -> Bool {
        guard width > 0 else { return false }
        let progress = min(max(locationX / width, 0), 1)
        return progress >= 0.25 && progress < 0.75
    }
}
