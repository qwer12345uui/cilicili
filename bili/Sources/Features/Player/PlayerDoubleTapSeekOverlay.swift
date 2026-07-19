import SwiftUI

struct PlayerDoubleTapSeekOverlay: View {
    let presentation: PlayerDoubleTapSeekPresentation

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: presentation.direction.systemImage)
                .font(.title3.weight(.semibold))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(offsetText)
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(timeText)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .biliLiquidGlassForeground(shadowOpacity: 0.20)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .biliPlayerClearGlass(interactive: false, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(presentation.direction.accessibilityTitle) \(offsetText)，定位到 \(timeText)")
    }

    private var offsetText: String {
        let seconds = Int(abs(presentation.offset).rounded())
        let sign = presentation.offset < 0 ? "-" : "+"
        return "\(sign)\(seconds)s"
    }

    private var timeText: String {
        "\(formatDuration(presentation.targetTime)) / \(formatDuration(presentation.duration))"
    }

    private func formatDuration(_ value: TimeInterval) -> String {
        let seconds = max(Int(value.rounded()), 0)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
