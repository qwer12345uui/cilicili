import Combine
import Foundation

typealias DashStream = DASHStream

enum VideoCodecPreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto
    case preferAV1
    case forceHEVC
    case forceH264

    nonisolated static let storageKey = "cc.bili.playback.videoCodecPreference.v1"
    nonisolated static let defaultValue: VideoCodecPreference = .auto
    nonisolated static var allCases: [VideoCodecPreference] {
        var preferences: [VideoCodecPreference] = [.auto]
        if PlaybackCodecPolicy.canDecodeAV1 {
            preferences.append(.preferAV1)
        }
        preferences += [.forceHEVC, .forceH264]
        return preferences
    }

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .auto:
            return "自动（HEVC 优先）"
        case .preferAV1:
            return "优先 AV1"
        case .forceHEVC:
            return "仅 HEVC"
        case .forceH264:
            return "仅 H.264"
        }
    }

    nonisolated var detail: String {
        switch self {
        case .auto:
            return "按 HEVC、H.264 的顺序选择可硬解视频流。"
        case .preferAV1:
            return "优先选择 AV1 硬解视频流；当前视频没有 AV1 时自动改用 HEVC 或 H.264。"
        case .forceHEVC:
            return "只请求和选择 HEVC；不可用时提示播放失败。"
        case .forceH264:
            return "只请求和选择 H.264；不可用时提示播放失败。"
        }
    }

    nonisolated var codecOrder: [VideoCodecFamily] {
        switch self {
        case .auto:
            return [.hevc, .h264, .unknown]
        case .preferAV1:
            return [.av1, .hevc, .h264, .unknown]
        case .forceHEVC:
            return [.hevc]
        case .forceH264:
            return [.h264]
        }
    }

    nonisolated var forcedCodecFamily: VideoCodecFamily? {
        switch self {
        case .auto, .preferAV1:
            return nil
        case .forceHEVC:
            return .hevc
        case .forceH264:
            return .h264
        }
    }

    nonisolated var forcedUnavailableMessage: String? {
        switch self {
        case .auto, .preferAV1:
            return nil
        case .forceHEVC:
            return "当前视频没有可硬解 HEVC 播放地址，可在设置中切换为自动或 H.264。"
        case .forceH264:
            return "当前视频没有可硬解 H.264 播放地址，可在设置中切换为自动或 HEVC。"
        }
    }

    nonisolated static func stored(in userDefaults: UserDefaults = .standard) -> VideoCodecPreference {
        let rawValue = userDefaults.string(forKey: storageKey)
        let storedPreference: VideoCodecPreference?
        if rawValue == "forceAV1" {
            storedPreference = .preferAV1
        } else {
            storedPreference = rawValue.flatMap(VideoCodecPreference.init(rawValue:))
        }
        guard let storedPreference else { return defaultValue }

        let resolvedPreference = storedPreference.resolvedForCurrentDevice
        if rawValue != resolvedPreference.rawValue {
            userDefaults.set(resolvedPreference.rawValue, forKey: storageKey)
        }
        return resolvedPreference
    }

    nonisolated var isAvailableOnCurrentDevice: Bool {
        self != .preferAV1 || PlaybackCodecPolicy.canDecodeAV1
    }

    nonisolated var resolvedForCurrentDevice: VideoCodecPreference {
        isAvailableOnCurrentDevice ? self : .auto
    }
}

enum VideoCodecFamily: Int, CaseIterable, Sendable {
    case unknown = 0
    case h264 = 1
    case hevc = 2
    case av1 = 3

    nonisolated var title: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .h264:
            return "H.264"
        case .hevc:
            return "HEVC"
        case .av1:
            return "AV1"
        }
    }
}

nonisolated enum DashStreamDispatcher {
    static func selectBestStream(
        from streams: [DashStream],
        preference: VideoCodecPreference,
        supportsAV1HardwareDecode: Bool = PlaybackCodecPolicy.canDecodeAV1
    ) -> DashStream? {
        let playableStreams = streams.enumerated()
            .filter { _, stream in
                guard stream.url != nil else { return false }
                guard stream.videoCodecFamily != .av1 || supportsAV1HardwareDecode else { return false }
                if let forcedCodecFamily = preference.forcedCodecFamily,
                   stream.videoCodecFamily != forcedCodecFamily {
                    return false
                }
                return true
            }
        guard !playableStreams.isEmpty else { return nil }

        let streams = playableStreams.map(\.element)
        let codecOrder = effectiveCodecOrder(
            for: preference,
            streams: streams
        )
        return playableStreams
            .min { lhs, rhs in
                rankingTuple(
                    for: lhs.element,
                    originalIndex: lhs.offset,
                    codecOrder: codecOrder
                ) < rankingTuple(
                    for: rhs.element,
                    originalIndex: rhs.offset,
                    codecOrder: codecOrder
                )
            }?
            .element
    }

    private static func effectiveCodecOrder(
        for preference: VideoCodecPreference,
        streams _: [DashStream] = []
    ) -> [VideoCodecFamily] {
        return preference.codecOrder
    }

    private static func rankingTuple(
        for stream: DashStream,
        originalIndex: Int,
        codecOrder: [VideoCodecFamily]
    ) -> StreamRankingTuple {
        let family = stream.videoCodecFamily
        let codecIndex = codecOrder.firstIndex(of: family) ?? codecOrder.count
        return StreamRankingTuple(
            codecIndex: codecIndex,
            dolbyPenalty: stream.isDolbyVisionVideoCodec ? 1 : 0,
            hardwarePenalty: stream.isHardwareDecodingCompatibleVideo ? 0 : 1,
            negativeBandwidth: -(stream.bandwidth ?? 0),
            originalIndex: originalIndex
        )
    }

}

nonisolated private struct StreamRankingTuple: Comparable {
    let codecIndex: Int
    let dolbyPenalty: Int
    let hardwarePenalty: Int
    let negativeBandwidth: Int
    let originalIndex: Int

    static func < (lhs: StreamRankingTuple, rhs: StreamRankingTuple) -> Bool {
        if lhs.codecIndex != rhs.codecIndex {
            return lhs.codecIndex < rhs.codecIndex
        }
        if lhs.dolbyPenalty != rhs.dolbyPenalty {
            return lhs.dolbyPenalty < rhs.dolbyPenalty
        }
        if lhs.hardwarePenalty != rhs.hardwarePenalty {
            return lhs.hardwarePenalty < rhs.hardwarePenalty
        }
        if lhs.negativeBandwidth != rhs.negativeBandwidth {
            return lhs.negativeBandwidth < rhs.negativeBandwidth
        }
        return lhs.originalIndex < rhs.originalIndex
    }
}

enum PlaybackHardwareDecodePolicy {
    nonisolated static let storageKey = "cc.bili.playback.forceHardwareDecode.v1"
    nonisolated static let defaultValue = true

    nonisolated static func stored(in userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.object(forKey: storageKey) as? Bool ?? defaultValue
    }
}

enum PlaybackAudioURLPolicy {
    nonisolated static let storageKey = "cc.bili.playback.prefersBackupAudioURL.v1"
    nonisolated static let defaultValue = false

    nonisolated static func stored(in userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.object(forKey: storageKey) as? Bool ?? defaultValue
    }
}

nonisolated enum DolbyVisionRenderingPolicy: String, CaseIterable, Identifiable, Codable, Sendable {
    case compatibleHLG
    case metadataPassthrough
    case appleNativeP8HLS
    case protectedHLG
    /// Deprecated: Bilibili Profile 8.4 fMP4 streams fail AVPlayer startup when
    /// we advertise them as native `dvh1` HLS tracks.
    case fullEffect
    case supplementalHLS

    nonisolated static let storageKey = "cc.bili.playback.dolbyVisionRenderingPolicy.v1"
    nonisolated static let defaultValue: DolbyVisionRenderingPolicy = .appleNativeP8HLS
    nonisolated static let allCases: [DolbyVisionRenderingPolicy] = [
        .compatibleHLG,
        .appleNativeP8HLS
    ]

    nonisolated var id: String { rawValue }

    nonisolated var playablePolicy: DolbyVisionRenderingPolicy {
        switch self {
        case .compatibleHLG, .appleNativeP8HLS:
            return self
        case .metadataPassthrough, .protectedHLG, .fullEffect, .supplementalHLS:
            return .compatibleHLG
        }
    }

    nonisolated var hlsBridgePolicy: DolbyVisionRenderingPolicy {
        switch playablePolicy {
        case .appleNativeP8HLS:
            return .compatibleHLG
        case .compatibleHLG:
            return .compatibleHLG
        case .metadataPassthrough, .protectedHLG, .fullEffect, .supplementalHLS:
            return .compatibleHLG
        }
    }

    nonisolated var title: String {
        switch self {
        case .compatibleHLG:
            return "兼容基层防过曝"
        case .metadataPassthrough:
            return "已停用：杜比元数据直通"
        case .appleNativeP8HLS:
            return "原生 HDR 视频层（实验）"
        case .protectedHLG:
            return "已停用：杜比标识 + 过曝保护"
        case .fullEffect:
            return "已停用：原生杜比主轨"
        case .supplementalHLS:
            return "已停用：完整杜比视界实验"
        }
    }

    nonisolated var detail: String {
        switch self {
        case .compatibleHLG:
            return "AVPlayer 只播放 Dolby Vision 的兼容基层，避免 B 站 Profile 8.4 触发过曝。"
        case .metadataPassthrough:
            return "该路线即使按色彩盒声明 HLG，AVPlayer 仍会因 B 站 Profile 8.4 元数据过曝，已自动迁移到兼容基层。"
        case .appleNativeP8HLS:
            return "底层 HLS 仍使用兼容基层，另挂一个静音 AVPlayerLayer 直连原始杜比/HDR 视频流，模拟 PiliPlus 的 iOS 原生显示链路。"
        case .protectedHLG:
            return "该路线仍可能让 AVPlayer 套用错误杜比映射，已自动迁移到兼容基层。"
        case .fullEffect:
            return "该路线会让 B 站 Profile 8.4 流不可播放，已自动迁移到兼容基层。"
        case .supplementalHLS:
            return "该路线会保留 Dolby Vision 补充标识并可能过曝，已自动迁移到兼容基层。"
        }
    }

    nonisolated static func stored(in userDefaults: UserDefaults = .standard) -> DolbyVisionRenderingPolicy {
        guard let rawValue = userDefaults.string(forKey: storageKey),
              let policy = DolbyVisionRenderingPolicy(rawValue: rawValue)
        else { return defaultValue }
        let playablePolicy = policy.playablePolicy
        if playablePolicy != policy {
            userDefaults.set(defaultValue.rawValue, forKey: storageKey)
            return defaultValue
        }
        return playablePolicy
    }
}

extension DASHStream {
    nonisolated init(
        id: Int?,
        url: URL,
        backupURLs: [URL] = [],
        bandwidth: Int? = nil,
        codecs: String?,
        codecid: Int? = nil,
        width: Int? = nil,
        height: Int? = nil,
        frameRate: String? = nil,
        mimeType: String? = nil,
        segmentBase: DASHSegmentBase? = nil
    ) {
        self.id = id
        self.baseURL = url.absoluteString
        self.backupURL = backupURLs.map(\.absoluteString)
        self.bandwidth = bandwidth
        self.codecs = codecs
        self.codecid = codecid
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.mimeType = mimeType
        self.segmentBase = segmentBase
    }

    nonisolated var url: URL? {
        playURL
    }

    nonisolated var videoCodecFamily: VideoCodecFamily {
        if isAV1VideoCodec {
            return .av1
        }
        if isHEVCVideoCodec {
            return .hevc
        }
        if isAVCVideoCodec {
            return .h264
        }
        return .unknown
    }
}

@MainActor
final class PlayerSettings: ObservableObject {
    static let shared = PlayerSettings()

    @Published private(set) var videoCodecPreference: VideoCodecPreference
    @Published private(set) var forceHardwareDecodeEnabled: Bool
    @Published private(set) var dolbyVisionRenderingPolicy: DolbyVisionRenderingPolicy

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.videoCodecPreference = VideoCodecPreference.stored(in: userDefaults)
        self.forceHardwareDecodeEnabled = PlaybackHardwareDecodePolicy.stored(in: userDefaults)
        self.dolbyVisionRenderingPolicy = DolbyVisionRenderingPolicy.stored(in: userDefaults)
    }

    func setVideoCodecPreference(_ preference: VideoCodecPreference) {
        let resolvedPreference = preference.resolvedForCurrentDevice
        guard videoCodecPreference != resolvedPreference
            || userDefaults.string(forKey: VideoCodecPreference.storageKey) != resolvedPreference.rawValue
        else { return }
        videoCodecPreference = resolvedPreference
        userDefaults.set(resolvedPreference.rawValue, forKey: VideoCodecPreference.storageKey)
    }

    func setForceHardwareDecodeEnabled(_ isEnabled: Bool) {
        guard forceHardwareDecodeEnabled != isEnabled
            || PlaybackHardwareDecodePolicy.stored(in: userDefaults) != isEnabled
        else { return }
        forceHardwareDecodeEnabled = isEnabled
        userDefaults.set(isEnabled, forKey: PlaybackHardwareDecodePolicy.storageKey)
    }

    func setDolbyVisionRenderingPolicy(_ policy: DolbyVisionRenderingPolicy) {
        guard dolbyVisionRenderingPolicy != policy
            || DolbyVisionRenderingPolicy.stored(in: userDefaults) != policy
        else { return }
        dolbyVisionRenderingPolicy = policy
        userDefaults.set(policy.rawValue, forKey: DolbyVisionRenderingPolicy.storageKey)
    }

    func reload() {
        videoCodecPreference = VideoCodecPreference.stored(in: userDefaults)
        forceHardwareDecodeEnabled = PlaybackHardwareDecodePolicy.stored(in: userDefaults)
        dolbyVisionRenderingPolicy = DolbyVisionRenderingPolicy.stored(in: userDefaults)
    }
}
