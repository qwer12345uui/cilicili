import SwiftUI

struct VideoCardElevatedBody<Cover: View>: View {
    let display: VideoCardDisplayModel
    let cover: Cover
    let showsPublishTimeInAuthorRow: Bool
    let showsAuthorIdentity: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover

            VideoCardTextStack(
                display: display,
                showsPublishTimeInAuthorRow: showsPublishTimeInAuthorRow,
                showsAuthorIdentity: showsAuthorIdentity
            )
            .padding(.horizontal, 8)
            .padding(.top, 7)
            .padding(.bottom, 8)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.10), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .mediaShadow(.subtle)
    }
}

struct VideoCardBlendedBody<Cover: View>: View {
    let display: VideoCardDisplayModel
    let cover: Cover
    let showsPublishTimeInAuthorRow: Bool
    let showsAuthorIdentity: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover
                .videoCoverSurface(cornerRadius: 15, shadowLevel: .control)

            VideoCardTextStack(
                display: display,
                showsPublishTimeInAuthorRow: showsPublishTimeInAuthorRow,
                showsAuthorIdentity: showsAuthorIdentity
            )
            .padding(.horizontal, 2)
        }
    }
}

struct VideoCardBorderedBody<Cover: View>: View {
    let display: VideoCardDisplayModel
    let cover: Cover
    let showsPublishTimeInAuthorRow: Bool
    let showsAuthorIdentity: Bool

    private let cornerRadius: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover
                .videoCardBorderedCover()

            VideoCardTextStack(
                display: display,
                showsPublishTimeInAuthorRow: showsPublishTimeInAuthorRow,
                showsAuthorIdentity: showsAuthorIdentity
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .videoCardBorderedSurface(cornerRadius: cornerRadius)
    }
}

struct VideoCardBorderedCompactBody: View {
    let display: VideoCardDisplayModel
    let coverSize: CGSize

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VideoCompactCover(
                display: display,
                size: coverSize,
                maximumPixelLength: 480,
                cornerRadius: 18,
                showsBorder: true
            )

            VStack(alignment: .leading, spacing: 6) {
                StableVideoTitleText(display.title, style: .compactCard, lineLimit: 2)
                    .frame(minHeight: 38, alignment: .topLeading)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(display.authorName)
                            .lineLimit(1)

                        if !display.recommendReasonText.isEmpty {
                            Text(display.recommendReasonText)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: 8) {
                        if !display.viewText.isEmpty {
                            Label(display.viewText, systemImage: "play.fill")
                                .labelStyle(.titleAndIcon)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 6)

                        if !display.publishTimeText.isEmpty {
                            Text(display.publishTimeText)
                                .lineLimit(1)
                        }
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, minHeight: max(coverSize.height - 20, 1), alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: coverSize.height, alignment: .topLeading)
        .videoCardBorderedSurface(cornerRadius: 18)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.title)
    }
}

extension View {
    func videoCardBorderedSurface(cornerRadius: CGFloat = 18) -> some View {
        modifier(VideoCardBorderedSurfaceModifier(cornerRadius: cornerRadius))
    }

    func videoCardBorderedCover(cornerRadius: CGFloat = 14) -> some View {
        videoCoverSurface(cornerRadius: cornerRadius, emphasizesBorder: true)
    }
}

private struct VideoCardBorderedSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape
                    .fill(.ultraThinMaterial)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(borderColor, lineWidth: 1)
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: 18, x: 0, y: 10)
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var borderColor: Color {
        switch colorScheme {
        case .dark:
            return Color.white.opacity(0.18)
        default:
            return Color.black.opacity(0.12)
        }
    }

    private var shadowOpacity: Double {
        colorScheme == .dark ? 0.18 : 0.10
    }
}
