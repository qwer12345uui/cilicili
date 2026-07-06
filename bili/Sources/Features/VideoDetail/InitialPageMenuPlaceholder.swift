import SwiftUI

struct InitialPageMenuPlaceholder: View {
    let pageCount: Int?

    private var title: String {
        pageCount.map { "\($0)P" } ?? "分P"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.stack")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)

            SkeletonBlock(width: title.count > 2 ? 34 : 24, height: 12, shape: .capsule)
        }
        .frame(maxWidth: .infinity)
        .initialPageMenuPlaceholderBackground()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
