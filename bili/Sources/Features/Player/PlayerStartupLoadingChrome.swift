import SwiftUI

struct PlayerStartupLoadingChrome: View {
    let isBuffering: Bool

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(.white)
                .accessibilityHidden(true)

            Text(isBuffering ? "缓冲中" : "加载中")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .biliPlayerClearGlass(interactive: false, in: Capsule())
    }
}
