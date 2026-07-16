import SwiftUI

/// Shared primary title treatment for playback detail pages.
struct PlaybackDetailTitleText: View {
    let text: String
    let lineLimit: Int?

    init(text: String, lineLimit: Int? = 1) {
        self.text = text
        self.lineLimit = lineLimit
    }

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .lineSpacing(1.5)
            .foregroundStyle(.primary)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
