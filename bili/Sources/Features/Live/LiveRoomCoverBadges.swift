import SwiftUI

struct LiveRoomStatusBadge: View {
    @AppStorage(VideoCoverBadgeShadow.storageKey) private var shadowOpacity = VideoCoverBadgeShadow.defaultOpacity

    var body: some View {
        Label("直播中", systemImage: "dot.radiowaves.left.and.right")
            .font(.system(size: 10.5, weight: .bold))
            .videoCoverBadgeForeground(opacity: shadowOpacity)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .videoCoverBadgeBackground(style: .clear, in: Capsule())
            .liveRoomCoverControlShadow()
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: 76, alignment: .leading)
            .clipped()
    }
}

private extension View {
    func liveRoomCoverControlShadow() -> some View {
        shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)
            .shadow(color: .black.opacity(0.16), radius: 2, x: 0, y: 1)
    }
}
