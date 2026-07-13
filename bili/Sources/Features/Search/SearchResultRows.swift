import SwiftUI

struct SearchVideoResultRow: View {
    @Environment(\.unifiedVideoCoverBorderExperimentEnabled) private var unifiedVideoCoverBorderExperimentEnabled
    private let video: VideoItem
    private let display: VideoCardDisplayModel
    private let coverSize = CGSize(width: 140, height: 88)
    private let cornerRadius: CGFloat = 18

    init(video: VideoItem) {
        self.video = video
        self.display = VideoCardDisplayModel(video: video)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            cover
            textColumn
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 108, alignment: .topLeading)
        .background(cardBackground)
        .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 10)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.title)
    }

    private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        return AdaptiveVideoCoverImage(
            display: display,
            style: .exactCrop,
            fixedSize: coverSize,
            maximumPixelLength: 480
        )
        .frame(width: coverSize.width, height: coverSize.height)
        .clipShape(shape)
        .unifiedVideoCoverExperimentBorder(
            in: shape,
            isEnabled: unifiedVideoCoverBorderExperimentEnabled
        )
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(video.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            metadataStack
        }
        .frame(maxWidth: .infinity, minHeight: coverSize.height, alignment: .topLeading)
    }

    private var metadataStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !display.authorName.isEmpty {
                Text(display.authorName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !display.durationText.isEmpty || !display.publishTimeText.isEmpty {
                HStack(spacing: 8) {
                    if !display.durationText.isEmpty {
                        Label(display.durationText, systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    if !display.publishTimeText.isEmpty {
                        Text(display.publishTimeText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
    }
}

struct SearchVideoResultSkeletonRow: View {
    private let coverSize = CGSize(width: 140, height: 88)
    private let cornerRadius: CGFloat = 18

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SkeletonBlock(width: coverSize.width, height: coverSize.height, shape: .rounded(12))

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    SkeletonBlock(height: 15, shape: .rounded(5))
                    SkeletonBlock(width: 132, height: 15, shape: .rounded(5))
                }
                .frame(minHeight: 36, alignment: .topLeading)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 5) {
                    SkeletonBlock(width: 86, height: 12, shape: .capsule)

                    HStack(spacing: 8) {
                        SkeletonBlock(width: 58, height: 11, shape: .capsule)
                        Spacer(minLength: 6)
                        SkeletonBlock(width: 46, height: 11, shape: .capsule)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: coverSize.height, alignment: .topLeading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 108, alignment: .topLeading)
        .background(cardBackground)
        .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 10)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .allowsHitTesting(false)
        .accessibilityLabel("正在加载搜索结果")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
    }
}
