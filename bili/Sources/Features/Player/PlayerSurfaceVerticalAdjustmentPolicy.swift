import CoreGraphics

enum PlayerSurfaceVerticalAdjustmentTarget: Equatable {
    case brightness
    case volume

    var accessibilityLabel: String {
        switch self {
        case .brightness:
            "屏幕亮度"
        case .volume:
            "音量"
        }
    }
}

nonisolated enum PlayerSurfaceVerticalAdjustmentPolicy {
    static func target(startLocationX: CGFloat, width: CGFloat) -> PlayerSurfaceVerticalAdjustmentTarget? {
        guard width > 0, startLocationX >= 0, startLocationX <= width else { return nil }
        return startLocationX < width / 2 ? .brightness : .volume
    }

    static func shouldBegin(
        translation: CGSize,
        activationDistance: CGFloat,
        dominanceRatio: CGFloat
    ) -> Bool {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        return verticalDistance >= activationDistance
            && verticalDistance > horizontalDistance * dominanceRatio
    }

    static func adjustedValue(
        initialValue: Float,
        verticalTranslation: CGFloat,
        height: CGFloat
    ) -> Float {
        let clampedInitialValue = min(max(initialValue, 0), 1)
        guard height > 0 else { return clampedInitialValue }
        let adjustment = -Float(verticalTranslation / height)
        return min(max(clampedInitialValue + adjustment, 0), 1)
    }

    static func shouldPresentHardwareVolumeIndicator(
        previousValue: Float,
        currentValue: Float,
        isVerticalAdjusting: Bool
    ) -> Bool {
        guard !isVerticalAdjusting else { return false }
        return abs(currentValue - previousValue) > 0.0001
    }
}
