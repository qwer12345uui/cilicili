import SwiftUI

enum VideoCoverBadgeShadow {
    static let storageKey = "cc.bili.display.videoCoverBadgeShadowOpacity.v1"
    static let defaultOpacity = 0.20
    static let opacityRange: ClosedRange<Double> = 0...1

    static func normalized(_ opacity: Double) -> Double {
        min(max(opacity, opacityRange.lowerBound), opacityRange.upperBound)
    }
}

struct VideoCoverGlassBadge<Content: View>: View {
    @AppStorage(VideoCoverBadgeShadow.storageKey) private var shadowOpacity = VideoCoverBadgeShadow.defaultOpacity
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .videoCoverBadgeForegroundShadow(opacity: shadowOpacity)
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.86)
            .allowsTightening(true)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .biliRegularGlassEffect(in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: 146, alignment: .leading)
            .clipped()
    }
}

struct VideoCoverDurationBadge: View {
    @AppStorage(VideoCoverBadgeShadow.storageKey) private var shadowOpacity = VideoCoverBadgeShadow.defaultOpacity
    let duration: String
    private let maxWidth: CGFloat

    init(_ duration: String, maxWidth: CGFloat = 96) {
        self.duration = duration
        self.maxWidth = maxWidth
    }

    var body: some View {
        Text(duration)
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .videoCoverBadgeForegroundShadow(opacity: shadowOpacity)
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.86)
            .allowsTightening(true)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .modifier(VideoCoverBadgeBackground(shape: Capsule()))
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: maxWidth, alignment: .trailing)
            .clipped()
            .accessibilityLabel("视频时长 \(duration)")
    }
}

struct VideoCoverViewCountBadge: View {
    @AppStorage(VideoCoverBadgeShadow.storageKey) private var shadowOpacity = VideoCoverBadgeShadow.defaultOpacity
    let viewText: String

    init(_ viewText: String) {
        self.viewText = viewText
    }

    var body: some View {
        Label(viewText, systemImage: "play.fill")
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.white)
            .videoCoverBadgeForegroundShadow(opacity: shadowOpacity)
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.86)
            .allowsTightening(true)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .biliRegularGlassEffect(in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: 112, alignment: .leading)
            .clipped()
            .accessibilityLabel("观看次数 \(viewText)")
    }
}

struct VideoCoverPlayBadge: View {
    @AppStorage(VideoCoverBadgeShadow.storageKey) private var shadowOpacity = VideoCoverBadgeShadow.defaultOpacity
    var size: CGFloat = 40
    var iconSize: CGFloat = 15

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            Image(systemName: "play.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(.white)
                .videoCoverBadgeForegroundShadow(opacity: shadowOpacity)
                .offset(x: 1)
                .frame(width: size, height: size)
                .modifier(VideoCoverBadgeBackground(shape: Circle()))
                .videoCoverControlShadow()
                .accessibilityHidden(true)
        }
    }
}

struct VideoCoverBottomScrim: View {
    var opacity: Double = 0.20
    var heightFraction: CGFloat = 1.0 / 4.0

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(opacity)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: max(proxy.size.height * min(max(heightFraction, 0), 1), 0))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct VideoCoverBadgeBackground<BadgeShape: InsettableShape>: ViewModifier {
    let shape: BadgeShape

    func body(content: Content) -> some View {
        content.biliPlayerClearGlass(interactive: false, in: shape)
    }
}

extension View {
    func videoCoverBadgeForegroundShadow(opacity: Double) -> some View {
        shadow(
            color: .black.opacity(VideoCoverBadgeShadow.normalized(opacity)),
            radius: 2.5,
            x: 0,
            y: 1
        )
    }
}

private extension View {
    func videoCoverControlShadow() -> some View {
        shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)
            .shadow(color: .black.opacity(0.16), radius: 2, x: 0, y: 1)
    }
}
