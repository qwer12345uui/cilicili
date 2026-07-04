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
                PgcSeasonLoadingView(state: state) {
                    Task { await load(force: true) }
                }
            }
        }
        .navigationTitle(season?.displayTitle ?? route.title)
        .navigationBarTitleDisplayMode(.inline)
        .nativeTopNavigationChrome()
        .task(id: route.id) {
            await load(force: false)
        }
    }

    private func load(force: Bool) async {
        guard force || season == nil else { return }
        state = .loading
        do {
            season = try await dependencies.api.fetchPgcSeasonInfo(seasonID: route.seasonID)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private struct PgcSeasonLoadedView: View {
    let season: PgcSeasonInfo

    var body: some View {
        List {
            Section {
                PgcSeasonHeader(season: season)
                PgcContinueWatchingRouteButton(season: season)
            }
            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))

            Section {
                ForEach(season.episodes) { episode in
                    PgcEpisodeRouteRow(season: season, episode: episode)
                }
            } header: {
                Text("分集")
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct PgcSeasonHeader: View {
    let season: PgcSeasonInfo

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SearchPosterCover(
                sourceURLString: season.normalizedCover,
                thumbnailWidth: 270,
                thumbnailHeight: 360,
                targetPixelSize: 360,
                size: CGSize(width: 96, height: 128),
                placeholderSystemImage: "play.tv"
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(season.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)

                PgcSeasonMetaLine(season: season)

                if let evaluate = season.evaluate?.removingHTMLTags().trimmedNonEmpty {
                    Text(evaluate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        }
    }
}

private struct PgcContinueWatchingRouteButton: View {
    let season: PgcSeasonInfo

    var body: some View {
        if let episode = season.continueWatchingEpisode,
           let video = episode.videoItem(in: season) {
            VideoRouteLink(video) {
                PgcContinueWatchingButtonContent(episode: episode)
            }
        }
    }
}

private struct PgcContinueWatchingButtonContent: View {
    let episode: PgcEpisode

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.fill")
                .font(.subheadline.weight(.bold))

            VStack(alignment: .leading, spacing: 2) {
                Text("继续观看")
                    .font(.subheadline.weight(.semibold))
                Text(episode.displayTitle)
                    .font(.caption)
                    .lineLimit(1)
                    .opacity(0.86)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .opacity(0.72)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("继续观看 \(episode.displayTitle)")
    }
}

private struct PgcSeasonMetaLine: View {
    let season: PgcSeasonInfo

    var body: some View {
        HStack(spacing: 8) {
            if let score = season.rating?.displayScore {
                SearchSoftPill("\(score)分", tint: .pink)
            }
            if !season.episodes.isEmpty {
                SearchSoftPill("\(season.episodes.count)集")
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

private struct PgcEpisodeRouteRow: View {
    let season: PgcSeasonInfo
    let episode: PgcEpisode

    var body: some View {
        if let video = episode.videoItem(in: season) {
            VideoRouteLink(video) {
                PgcEpisodeRow(episode: episode)
            }
        } else {
            PgcEpisodeRow(episode: episode)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PgcEpisodeRow: View {
    let episode: PgcEpisode

    var body: some View {
        HStack(spacing: 12) {
            SearchPosterCover(
                sourceURLString: episode.cover?.normalizedBiliURL(),
                thumbnailWidth: 240,
                thumbnailHeight: 135,
                targetPixelSize: 240,
                size: CGSize(width: 112, height: 63),
                placeholderSystemImage: "play.rectangle"
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(episode.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let badge = episode.badge?.trimmedNonEmpty {
                        SearchSoftPill(badge)
                    }
                    if let duration = episode.durationSeconds {
                        Text(BiliFormatters.duration(duration))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 63, alignment: .topLeading)
        }
        .contentShape(Rectangle())
    }
}

private struct PgcSeasonLoadingView: View {
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
                ProgressView()
                    .controlSize(.large)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
