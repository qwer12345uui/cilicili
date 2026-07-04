import Foundation

nonisolated struct PgcSeasonRoute: Hashable, Identifiable {
    let seasonID: Int
    let title: String
    let cover: String?

    var id: Int { seasonID }

    init?(media: SearchMediaItem) {
        guard let seasonID = media.seasonID else { return nil }
        self.seasonID = seasonID
        self.title = media.title
        self.cover = media.cover?.normalizedBiliURL()
    }
}

nonisolated struct PgcSeasonInfo: Decodable, Hashable, Sendable {
    let seasonID: Int?
    let mediaID: Int?
    let title: String?
    let seasonTitle: String?
    let subtitle: String?
    let cover: String?
    let evaluate: String?
    let episodes: [PgcEpisode]
    let rating: PgcRating?
    let upInfo: PgcUpInfo?
    let userStatus: PgcUserStatus?

    enum CodingKeys: String, CodingKey {
        case title, subtitle, cover, evaluate, episodes, rating
        case seasonID = "season_id"
        case mediaID = "media_id"
        case seasonTitle = "season_title"
        case upInfo = "up_info"
        case userStatus = "user_status"
    }

    var displayTitle: String {
        seasonTitle?.removingHTMLTags().pgcTrimmedNonEmpty
            ?? title?.removingHTMLTags().pgcTrimmedNonEmpty
            ?? "番剧"
    }

    var normalizedCover: String? {
        cover?.normalizedBiliURL()
    }

    var owner: VideoOwner? {
        guard let upInfo else { return nil }
        return VideoOwner(
            mid: upInfo.mid ?? 0,
            name: upInfo.name ?? "番剧",
            face: upInfo.avatar?.normalizedBiliURL()
        )
    }

    var continueWatchingEpisode: PgcEpisode? {
        guard let lastEpID = userStatus?.progress?.lastEpID else { return nil }
        return episodes.first { episode in
            episode.epID == lastEpID || episode.idValue == lastEpID
        }
    }
}

nonisolated struct PgcEpisode: Decodable, Hashable, Identifiable, Sendable {
    let idValue: Int?
    let epID: Int?
    let aid: Int?
    let bvid: String?
    let cid: Int?
    let title: String?
    let longTitle: String?
    let showTitle: String?
    let cover: String?
    let badge: String?
    let duration: Int?
    let pubTime: Int?
    let dimension: VideoDimension?

    enum CodingKeys: String, CodingKey {
        case aid, bvid, cid, title, cover, badge, duration, dimension
        case idValue = "id"
        case epID = "ep_id"
        case longTitle = "long_title"
        case showTitle = "show_title"
        case pubTime = "pub_time"
        case releaseDate = "release_date"
    }

    var id: Int {
        epID ?? idValue ?? cid ?? aid ?? 0
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        idValue = container.pgcDecodeLossyIntIfPresent(forKey: .idValue)
        epID = container.pgcDecodeLossyIntIfPresent(forKey: .epID)
        aid = container.pgcDecodeLossyIntIfPresent(forKey: .aid)
        bvid = container.pgcDecodeLossyStringIfPresent(forKey: .bvid)
        cid = container.pgcDecodeLossyIntIfPresent(forKey: .cid)
        title = container.pgcDecodeLossyStringIfPresent(forKey: .title)
        longTitle = container.pgcDecodeLossyStringIfPresent(forKey: .longTitle)
        showTitle = container.pgcDecodeLossyStringIfPresent(forKey: .showTitle)
        cover = container.pgcDecodeLossyStringIfPresent(forKey: .cover)
        badge = container.pgcDecodeLossyStringIfPresent(forKey: .badge)
        duration = container.pgcDecodeLossyIntIfPresent(forKey: .duration)
        pubTime = container.pgcDecodeLossyIntIfPresent(forKey: .pubTime)
            ?? container.pgcDecodeLossyIntIfPresent(forKey: .releaseDate)
        dimension = try container.decodeIfPresent(VideoDimension.self, forKey: .dimension)
    }

    var displayTitle: String {
        let titleText = title?.removingHTMLTags().pgcTrimmedNonEmpty
        let longTitleText = longTitle?.removingHTMLTags().pgcTrimmedNonEmpty
        if let titleText, let longTitleText {
            return "\(titleText) \(longTitleText)"
        }
        return longTitleText
            ?? showTitle?.removingHTMLTags().pgcTrimmedNonEmpty
            ?? titleText
            ?? "分集"
    }

    var durationSeconds: Int? {
        guard let duration, duration > 0 else { return nil }
        return duration > 10_000 ? duration / 1000 : duration
    }

    func videoItem(in season: PgcSeasonInfo) -> VideoItem? {
        guard let cid, cid > 0 else { return nil }
        let episodeID = epID ?? idValue
        let seasonID = season.seasonID
        let routeID = bvid?.pgcTrimmedNonEmpty
            ?? episodeID.map { "ep\($0)" }
            ?? "pgc-\(seasonID ?? 0)-\(cid)"
        return VideoItem(
            bvid: routeID,
            aid: aid,
            title: displayTitle,
            pic: cover?.normalizedBiliURL() ?? season.normalizedCover,
            desc: season.evaluate,
            duration: durationSeconds,
            pubdate: pubTime,
            owner: season.owner,
            stat: nil,
            cid: cid,
            pages: [
                VideoPage(
                    cid: cid,
                    page: 1,
                    part: displayTitle,
                    duration: durationSeconds,
                    dimension: dimension
                )
            ],
            dimension: dimension,
            pgcSeasonID: seasonID,
            pgcEpisodeID: episodeID
        )
    }
}

nonisolated struct PgcRating: Decodable, Hashable, Sendable {
    let score: Double?

    var displayScore: String? {
        guard let score else { return nil }
        return String(format: "%.1f", score)
    }
}

nonisolated struct PgcUpInfo: Decodable, Hashable, Sendable {
    let mid: Int?
    let name: String?
    let avatar: String?

    enum CodingKeys: String, CodingKey {
        case mid, avatar
        case name = "uname"
    }
}

nonisolated struct PgcUserStatus: Decodable, Hashable, Sendable {
    let progress: PgcUserProgress?
    let favored: Int?
}

nonisolated struct PgcUserProgress: Decodable, Hashable, Sendable {
    let lastEpID: Int?

    enum CodingKeys: String, CodingKey {
        case lastEpID = "last_ep_id"
    }
}

nonisolated struct PgcPlayURLResult: Decodable, Sendable {
    let videoInfo: PlayURLData?

    enum CodingKeys: String, CodingKey {
        case videoInfo = "video_info"
    }
}

private extension String {
    nonisolated var pgcTrimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension KeyedDecodingContainer {
    nonisolated func pgcDecodeLossyIntIfPresent(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    nonisolated func pgcDecodeLossyStringIfPresent(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(format: "%.3f", value)
        }
        return nil
    }
}
