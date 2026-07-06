import SwiftUI

struct PgcSeasonView: View {
    let route: PgcSeasonRoute

    @EnvironmentObject private var dependencies: AppDependencies
    @State private var season: PgcSeasonInfo?
    @State private var state: LoadingState = .idle

    var body: some View {
        Group {
            if let season {
                PgcSeasonLoadedView(season: season)
            } else {
                PgcSeasonLoadingView(route: route, state: state) {
                    Task { await load(force: true) }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            }
        }
        .background(VideoNavigationHostTransparency(suppressesNavigationBar: true))
        .background(VideoDetailSystemBackGestureBridge {})
        .hidesRootTabBarOnPush()
        .task(id: route.id) {
            await load(force: false)
        }
    }

    private func load(force: Bool) async {
        guard force || season == nil else { return }
        state = .loading
        do {
            season = try await dependencies.api.fetchPgcSeasonInfo(seasonID: route.seasonID)
                .withFallbackSeasonID(route.seasonID)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private struct PgcSeasonLoadedView: View {
    let season: PgcSeasonInfo
    @State private var episodeOrder: PgcEpisodeOrder = .ascending
    @State private var isEpisodeSheetPresented = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    PgcSeasonHeroCover(
                        season: season,
                        width: proxy.size.width
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        PgcSeasonInfoSection(
                            season: season
                        )

                        PgcEpisodeGrid(
                            season: season,
                            order: $episodeOrder,
                            showsEpisodeSheet: $isEpisodeSheetPresented
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .scrollContentBackground(.hidden)
            .nativeTopScrollEdgeEffect()
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $isEpisodeSheetPresented) {
            PgcEpisodeSelectionSheet(
                season: season,
                order: $episodeOrder
            )
        }
    }
}

private struct PgcSeasonHeroCover: View {
    let season: PgcSeasonInfo
    let width: CGFloat

    private var coverURLString: String? {
        season.normalizedCover
    }

    private var targetPixelSize: Int {
        max(960, Int((width * 3).rounded()))
    }

    var body: some View {
        CachedRemoteImage(
            url: coverURLString.flatMap(URL.init(string:)),
            targetPixelSize: targetPixelSize,
            animatesAppearance: true
        ) { image in
            image
                .resizable()
                .scaledToFit()
        } placeholder: {
            PgcSeasonHeroImagePlaceholder()
        }
        .frame(width: width)
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.black.opacity(0.42), .black.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
        }
    }
}

private struct PgcSeasonInfoSection: View {
    let season: PgcSeasonInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(season.displayTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)

                PgcSeasonMetaLine(season: season)

                if let evaluate = season.evaluate?.removingHTMLTags().trimmedNonEmpty {
                    PgcSeasonEvaluateText(evaluate)
                }
            }

            PgcPlayRouteButton(season: season)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PgcSeasonEvaluateText: View {
    @Environment(\.appThemeTintColor) private var appTintColor
    let text: String
    @State private var isExpanded = false

    init(_ text: String) {
        self.text = text
    }

    private var shouldShowToggle: Bool {
        text.count > 72
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)

            if shouldShowToggle {
                Button {
                    withAnimation(.smooth(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "收起" : "展开")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(appTintColor)
            }
        }
    }
}

private struct PgcPlayRouteButton: View {
    let season: PgcSeasonInfo

    private var continueEpisode: PgcEpisode? {
        guard let episode = season.continueWatchingEpisode,
              episode.videoItem(in: season) != nil
        else { return nil }
        return episode
    }

    private var targetEpisode: PgcEpisode? {
        continueEpisode
            ?? season.selectableEpisodes.first { $0.videoItem(in: season) != nil }
    }

    private var targetVideo: VideoItem? {
        targetEpisode?.videoItem(in: season)
    }

    var body: some View {
        if let targetEpisode, let targetVideo {
            VideoRouteLink(targetVideo) {
                PgcPlayButtonContent(
                    title: "继续播放",
                    subtitle: targetEpisode.displayTitle
                )
            }
        } else {
            PgcPlayButtonContent(title: "暂无可播放分集", subtitle: nil)
                .opacity(0.55)
                .allowsHitTesting(false)
        }
    }
}

private struct PgcPlayButtonContent: View {
    @Environment(\.appThemeTintColor) private var appTintColor
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.fill")
                .font(.subheadline.weight(.bold))

            Text(title)
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: 8)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .lineLimit(1)
                    .opacity(0.86)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appTintColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel(subtitle.map { "\(title) \($0)" } ?? title)
    }
}

private struct PgcSeasonMetaLine: View {
    let season: PgcSeasonInfo

    var body: some View {
        HStack(spacing: 8) {
            if let score = season.rating?.displayScore {
                SearchSoftPill("\(score)分", tint: .pink)
            }
            if !season.selectableEpisodes.isEmpty {
                SearchSoftPill("\(season.selectableEpisodes.count)集")
            }
            if let subtitle = season.subtitle?.removingHTMLTags().trimmedNonEmpty {
                Text(subtitle)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

private struct PgcEpisodeGrid: View {
    let season: PgcSeasonInfo
    @Binding var order: PgcEpisodeOrder
    @Binding var showsEpisodeSheet: Bool

    private var orderedEpisodes: [PgcEpisode] {
        order.episodes(from: season.selectableEpisodes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PgcEpisodeSectionHeader(
                episodeCount: season.selectableEpisodes.count,
                order: $order,
                showsEpisodeSheet: $showsEpisodeSheet
            )

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(orderedEpisodes) { episode in
                        PgcEpisodeRouteTile(
                            season: season,
                            episode: episode,
                            width: 124,
                            height: 62
                        )
                    }
                }
            }
            .padding(.horizontal, -16)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .frame(height: 62)
        }
    }
}

private struct PgcEpisodeSectionHeader: View {
    let episodeCount: Int
    @Binding var order: PgcEpisodeOrder
    @Binding var showsEpisodeSheet: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("分集")
                .font(.headline)

            if episodeCount > 0 {
                Text("\(episodeCount) 集")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                order.toggle()
            } label: {
                Label(order.title, systemImage: "arrow.up.arrow.down")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button {
                showsEpisodeSheet = true
            } label: {
                Image(systemName: "triangle.fill")
                    .font(.caption.weight(.bold))
                    .rotationEffect(.degrees(180))
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("展开全部分集")
        }
    }
}

private struct PgcEpisodeSelectionButton: View {
    let episode: PgcEpisode
    let isPlayable: Bool
    let width: CGFloat?
    let height: CGFloat
    let usesGlassBackground: Bool

    init(
        episode: PgcEpisode,
        isPlayable: Bool,
        width: CGFloat? = nil,
        height: CGFloat = 56,
        usesGlassBackground: Bool = false
    ) {
        self.episode = episode
        self.isPlayable = isPlayable
        self.width = width
        self.height = height
        self.usesGlassBackground = usesGlassBackground
    }

    var body: some View {
        selectionSurface {
            VStack(alignment: .leading, spacing: 6) {
                Text(episode.displayTitle)
                    .font(titleFont)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                HStack(spacing: 8) {
                    if let badge = episode.badge?.trimmedNonEmpty {
                        SearchSoftPill(badge)
                    }
                    if let duration = episode.durationSeconds {
                        Text(BiliFormatters.duration(duration))
                    }
                }
                .font(metadataFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(width: width, height: height, alignment: .topLeading)
        }
        .disabled(!isPlayable)
        .opacity(isPlayable ? 1 : 0.55)
        .accessibilityLabel(episode.displayTitle)
    }

    @ViewBuilder
    private func selectionSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if usesGlassBackground {
            content()
                .background(glassFill, in: shape)
                .commentPlayerGlassRoundedRectangle(cornerRadius: 12, showsShadow: false)
                .overlay {
                    shape.strokeBorder(borderColor, lineWidth: borderWidth)
                }
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        } else {
            content()
                .background(backgroundStyle, in: shape)
                .overlay {
                    shape.strokeBorder(borderColor, lineWidth: borderWidth)
                }
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }

    private var borderWidth: CGFloat {
        0.8
    }

    private var backgroundStyle: Color {
        Color(.secondarySystemBackground)
    }

    private var glassFill: Color {
        Color(.systemBackground).opacity(0.58)
    }

    private var borderColor: Color {
        return usesGlassBackground ? Color.primary.opacity(0.16) : Color(.separator).opacity(0.22)
    }

    private var titleFont: Font {
        usesGlassBackground ? .subheadline.weight(.semibold) : .caption.weight(.semibold)
    }

    private var metadataFont: Font {
        usesGlassBackground ? .caption.weight(.medium) : .caption
    }

    private var horizontalPadding: CGFloat {
        usesGlassBackground ? 14 : 12
    }

    private var verticalPadding: CGFloat {
        usesGlassBackground ? 10 : 8
    }
}

private struct PgcEpisodeSelectionSheet: View {
    let season: PgcSeasonInfo
    @Binding var order: PgcEpisodeOrder

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var orderedEpisodes: [PgcEpisode] {
        order.episodes(from: season.selectableEpisodes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PgcEpisodeSheetHeader(
                        episodeCount: season.selectableEpisodes.count,
                        order: $order
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                    GlassEffectContainer(spacing: 10) {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(orderedEpisodes) { episode in
                                PgcEpisodeRouteTile(
                                    season: season,
                                    episode: episode,
                                    height: 68,
                                    usesGlassBackground: true,
                                    dismissesOnRoute: true
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }
            }
            .hiddenInlineNavigationTitle()
            .nativeTopScrollEdgeEffect(hidesRootNavigationTitle: false)
            .scrollContentBackground(.hidden)
            .background(.clear)
        }
        .presentationDetents([.fraction(0.7)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }
}

private struct PgcEpisodeRouteTile: View {
    let season: PgcSeasonInfo
    let episode: PgcEpisode
    var width: CGFloat?
    var height: CGFloat = 56
    var usesGlassBackground = false
    var dismissesOnRoute = false
    @Environment(\.openVideoAction) private var openVideo
    @Environment(\.prewarmVideoRouteAction) private var prewarmVideoRoute
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let video = episode.videoItem(in: season) {
            if let openVideo {
                Button {
                    prewarmVideoRoute?(video)
                    if dismissesOnRoute {
                        dismiss()
                    }
                    openVideo(video)
                } label: {
                    tile(isPlayable: true)
                }
                .buttonStyle(.plain)
            } else {
                VideoRouteLink(video) {
                    tile(isPlayable: true)
                }
            }
        } else {
            tile(isPlayable: false)
        }
    }

    private func tile(isPlayable: Bool) -> some View {
        PgcEpisodeSelectionButton(
            episode: episode,
            isPlayable: isPlayable,
            width: width,
            height: height,
            usesGlassBackground: usesGlassBackground
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct PgcEpisodeSheetHeader: View {
    let episodeCount: Int
    @Binding var order: PgcEpisodeOrder

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 10) {
                Text("全部分集")
                    .font(.headline)

                Text("\(episodeCount) 集")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    order.toggle()
                } label: {
                    Label(order.title, systemImage: "arrow.up.arrow.down")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .commentPlayerGlassCapsule(showsShadow: false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .commentPlayerGlassRoundedRectangle(cornerRadius: 14, showsShadow: false)
        }
    }
}

private enum PgcEpisodeOrder {
    case ascending
    case descending

    var title: String {
        switch self {
        case .ascending:
            return "正序"
        case .descending:
            return "倒序"
        }
    }

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }

    func episodes(from episodes: [PgcEpisode]) -> [PgcEpisode] {
        switch self {
        case .ascending:
            return episodes
        case .descending:
            return Array(episodes.reversed())
        }
    }
}

private struct PgcSeasonLoadingView: View {
    let route: PgcSeasonRoute
    let state: LoadingState
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            switch state {
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试", action: retry)
                    .buttonStyle(.borderedProminent)
            default:
                PgcSeasonSkeletonView(route: route)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private struct PgcSeasonSkeletonView: View {
    let route: PgcSeasonRoute

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PgcSeasonSkeletonHeroCover(
                        coverURLString: route.cover,
                        width: proxy.size.width
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        PgcSeasonSkeletonInfo(route: route, width: proxy.size.width)

                        SkeletonBlock(height: 42, shape: .rounded(12))

                        PgcSeasonEpisodeSkeletonSection()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .scrollContentBackground(.hidden)
            .nativeTopScrollEdgeEffect()
            .background(Color(.systemBackground))
        }
        .accessibilityLabel("正在加载番剧详情")
    }
}

private struct PgcSeasonSkeletonHeroCover: View {
    let coverURLString: String?
    let width: CGFloat

    private var targetPixelSize: Int {
        max(960, Int((width * 3).rounded()))
    }

    var body: some View {
        CachedRemoteImage(
            url: coverURLString.flatMap(URL.init(string:)),
            targetPixelSize: targetPixelSize,
            animatesAppearance: true
        ) { image in
            image
                .resizable()
                .scaledToFit()
        } placeholder: {
            PgcSeasonHeroImagePlaceholder()
        }
        .frame(width: width)
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.black.opacity(0.28), .black.opacity(0.01)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
        }
    }
}

private struct PgcSeasonHeroImagePlaceholder: View {
    var body: some View {
        BiliMediaPlaceholder(style: .video, iconSize: 28)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }
}

private struct PgcSeasonSkeletonInfo: View {
    let route: PgcSeasonRoute
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = route.title.removingHTMLTags().trimmedNonEmpty {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            } else {
                SkeletonBlock(width: min(width * 0.62, 240), height: 22, shape: .rounded(6))
            }

            HStack(spacing: 8) {
                SkeletonBlock(width: 46, height: 20, shape: .capsule)
                SkeletonBlock(width: 54, height: 20, shape: .capsule)
                SkeletonBlock(width: min(width * 0.32, 132), height: 13, shape: .capsule)
            }

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(height: 13, shape: .rounded(5))
                SkeletonBlock(width: min(width * 0.78, 320), height: 13, shape: .rounded(5))
            }
            .padding(.top, 2)
        }
    }
}

private struct PgcSeasonEpisodeSkeletonSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SkeletonBlock(width: 58, height: 20, shape: .rounded(5))
                Spacer()
                SkeletonBlock(width: 48, height: 14, shape: .capsule)
                SkeletonBlock(width: 28, height: 28, shape: .circle)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { _ in
                        SkeletonBlock(width: 124, height: 62, shape: .rounded(12))
                    }
                }
            }
            .scrollDisabled(true)
            .padding(.horizontal, -16)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .frame(height: 62)
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
