import SwiftUI

struct BilibiliUPBadge: View {
    let size: CGFloat

    var body: some View {
        Image("BilibiliUPBadge")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
