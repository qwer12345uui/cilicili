import XCTest
import UIKit
@testable import bili

final class PlayerFormalPlaybackConfigurationTests: XCTestCase {
    func testLivePlayerControlLayoutOnlyKeepsNavigationActions() {
        XCTAssertFalse(BiliPlayerControlLayout.live.showsProgress)
        XCTAssertFalse(BiliPlayerControlLayout.live.showsPlaybackToggle)
        XCTAssertFalse(BiliPlayerControlLayout.live.showsTimeLabel)

        XCTAssertFalse(BiliPlayerControlLayout.livePiliPod.showsProgress)
        XCTAssertTrue(BiliPlayerControlLayout.livePiliPod.showsPlaybackToggle)
        XCTAssertFalse(BiliPlayerControlLayout.livePiliPod.showsTimeLabel)

        XCTAssertTrue(BiliPlayerControlLayout.standard.showsProgress)
        XCTAssertTrue(BiliPlayerControlLayout.standard.showsPlaybackToggle)
        XCTAssertTrue(BiliPlayerControlLayout.standard.showsTimeLabel)
    }

    @MainActor
    func testPlayerSettingsRestoresLegacyAV1CodecPreferenceOnlyWhenSupported() {
        let defaults = makeUserDefaults()
        defaults.set("forceAV1", forKey: VideoCodecPreference.storageKey)

        let settings = PlayerSettings(userDefaults: defaults)
        settings.reload()

        let expectedPreference: VideoCodecPreference = PlaybackCodecPolicy.canDecodeAV1 ? .preferAV1 : .auto
        XCTAssertEqual(settings.videoCodecPreference, expectedPreference)
        XCTAssertEqual(defaults.string(forKey: VideoCodecPreference.storageKey), expectedPreference.rawValue)
    }

    @MainActor
    func testPlayerSettingsPersistsForceHardwareDecode() {
        let defaults = makeUserDefaults()
        let settings = PlayerSettings(userDefaults: defaults)

        settings.setForceHardwareDecodeEnabled(true)

        XCTAssertTrue(settings.forceHardwareDecodeEnabled)
        XCTAssertTrue(PlaybackHardwareDecodePolicy.stored(in: defaults))
    }

    @MainActor
    func testLibraryStorePersistsVideoCoverDurationBadgeVisibility() {
        let defaults = makeUserDefaults()
        let store = LibraryStore(userDefaults: defaults)

        XCTAssertFalse(store.showsVideoCoverDurationBadges)
        store.setShowsVideoCoverDurationBadges(true)

        XCTAssertTrue(
            LibraryStore(userDefaults: defaults).showsVideoCoverDurationBadges
        )
    }

    @MainActor
    func testLibraryStoreDefaultsVideoDetailAutoplayOnAndPersistsSelection() {
        let defaults = makeUserDefaults()
        let store = LibraryStore(userDefaults: defaults)

        XCTAssertTrue(store.videoDetailAutoplayEnabled)
        store.setVideoDetailAutoplayEnabled(false)

        XCTAssertFalse(
            LibraryStore(userDefaults: defaults).videoDetailAutoplayEnabled
        )
    }

    @MainActor
    func testExplicitPlaybackPromptsDoNotReturnAfterPause() {
        let player = PlayerStateViewModel(
            videoURL: nil,
            audioURL: nil,
            title: "Test",
            referer: "https://www.bilibili.com"
        )
        defer { player.stop() }

        player.setInitialManualPlaybackPrompt(true)
        player.setRelatedVideoReturnPlaybackPrompt(true)
        XCTAssertTrue(player.isAwaitingInitialManualPlayback)
        XCTAssertTrue(player.isAwaitingRelatedVideoReturnPlayback)

        player.play()
        player.pause()

        XCTAssertFalse(player.isAwaitingInitialManualPlayback)
        XCTAssertFalse(player.isAwaitingRelatedVideoReturnPlayback)
    }

    @MainActor
    func testLibraryStoreDefaultsAppIconPreferenceToSystemAndPersistsSelection() {
        let defaults = makeUserDefaults()
        let store = LibraryStore(userDefaults: defaults)

        XCTAssertEqual(store.appIconPreference, .system)
        store.setAppIconPreference(.dark)

        XCTAssertEqual(
            LibraryStore(userDefaults: defaults).appIconPreference,
            .dark
        )
    }

    @MainActor
    func testLibraryStorePersistsUnifiedVideoCoverBorderExperiment() {
        let defaults = makeUserDefaults()
        let store = LibraryStore(userDefaults: defaults)

        XCTAssertFalse(store.unifiedVideoCoverBorderExperimentEnabled)
        store.setUnifiedVideoCoverBorderExperimentEnabled(true)

        XCTAssertTrue(
            LibraryStore(userDefaults: defaults).unifiedVideoCoverBorderExperimentEnabled
        )
    }

    @MainActor
    func testAppTypographyScalesSemanticVideoTitleRoles() {
        let regular = AppTypography.Role.feedVideoTitle.uiFont(contentSizeCategory: .large)
        let compact = AppTypography.Role.compactVideoTitle.uiFont(contentSizeCategory: .large)
        let accessibility = AppTypography.Role.feedVideoTitle.uiFont(
            contentSizeCategory: .accessibilityExtraLarge
        )

        XCTAssertEqual(regular.pointSize, 15, accuracy: 0.001)
        XCTAssertEqual(compact.pointSize, 14, accuracy: 0.001)
        XCTAssertGreaterThan(accessibility.pointSize, regular.pointSize)
    }

    @MainActor
    func testLibraryStorePersistsHomeNavigationModeSwitcherExperiment() {
        let defaults = makeUserDefaults()
        let store = LibraryStore(userDefaults: defaults)

        XCTAssertTrue(store.homeNavigationModeSwitcherExperimentEnabled)
        store.setHomeNavigationModeSwitcherExperimentEnabled(false)

        XCTAssertFalse(
            LibraryStore(userDefaults: defaults).homeNavigationModeSwitcherExperimentEnabled
        )
    }

    @MainActor
    func testLibraryStoreRemovesRetiredExperimentPreferences() {
        let defaults = makeUserDefaults()
        let retiredKeys = [
            "cc.bili.playback.startupRequestSchedulingExperimentEnabled.v1",
            "cc.bili.live.videoDetailLayoutExperimentEnabled.v1",
            "cc.bili.live.piliPodLayoutExperimentEnabled.v1",
            "cc.bili.live.parallelStartupExperimentEnabled.v1",
            "cc.bili.live.adaptiveCDNStartupExperimentEnabled.v1",
            "cc.bili.live.slowStartupRouteSwitchExperimentEnabled.v1",
            "cc.bili.live.hlsFastStartExperimentEnabled.v1",
            "cc.bili.live.danmakuRenderBatchingExperimentEnabled.v1",
            "cc.bili.live.rotationSurfaceAlignmentExperimentEnabled.v1",
            "cc.bili.display.mineSingleStackNavigationExperimentEnabled.v1",
            "cc.bili.display.fixedVideoTitleTypographyExperimentEnabled.v1",
            "cc.bili.display.unifiedAppTypographyExperimentEnabled.v1",
            "cc.bili.display.highQualityImageViewerExperimentEnabled.v1",
            "cc.bili.account.messageCenterExperimentEnabled.v1",
            "cc.bili.display.telegramTopEdgeBlurExperimentEnabled.v1",
            "cc.bili.display.uploaderProfileGlassSheetExperimentEnabled.v1",
        ]
        retiredKeys.forEach { defaults.set(true, forKey: $0) }

        _ = LibraryStore(userDefaults: defaults)

        retiredKeys.forEach { XCTAssertNil(defaults.object(forKey: $0)) }
    }

    @MainActor
    func testLibraryStorePersistsFastScrollImageLoadSuppressionExperiment() {
        let defaults = makeUserDefaults()
        let store = LibraryStore(userDefaults: defaults)

        XCTAssertTrue(store.fastScrollImageLoadSuppressionExperimentEnabled)
        store.setFastScrollImageLoadSuppressionExperimentEnabled(false)

        XCTAssertFalse(
            LibraryStore(userDefaults: defaults).fastScrollImageLoadSuppressionExperimentEnabled
        )
    }

    @MainActor
    func testLibraryStorePersistsRemoteImageCDNFailoverExperiment() {
        let defaults = makeUserDefaults()
        let store = LibraryStore(userDefaults: defaults)

        XCTAssertTrue(store.remoteImageCDNFailoverExperimentEnabled)
        store.setRemoteImageCDNFailoverExperimentEnabled(false)

        XCTAssertFalse(
            LibraryStore(userDefaults: defaults).remoteImageCDNFailoverExperimentEnabled
        )
    }

    @MainActor
    func testLibraryStoreDefaultsImageDiagnosticsOnAndPersistsToggle() {
        let defaults = makeUserDefaults()
        let store = LibraryStore(userDefaults: defaults)

        XCTAssertTrue(store.remoteImageDiagnosticsEnabled)
        store.setRemoteImageDiagnosticsEnabled(false)

        XCTAssertFalse(
            LibraryStore(userDefaults: defaults).remoteImageDiagnosticsEnabled
        )
    }

    @MainActor
    func testPlaybackSessionTracksActivePlayerIdentityAndDetaches() {
        let player = PlayerStateViewModel(
            videoURL: nil,
            audioURL: nil,
            title: "Playback session test",
            referer: "https://www.bilibili.com"
        )
        let session = PlaybackSession()

        session.replaceActivePlayer(with: player)

        XCTAssertTrue(session.activePlayer === player)
        XCTAssertEqual(session.snapshot.playerID, ObjectIdentifier(player))
        XCTAssertEqual(session.snapshot.phase, .preparing)

        player.isPreparing = false
        player.isPlaying = true
        XCTAssertEqual(session.snapshot.phase, .playing)

        player.isBuffering = true
        XCTAssertEqual(session.snapshot.phase, .buffering)

        player.errorMessage = "Test failure"
        XCTAssertEqual(session.snapshot.phase, .failed)

        session.detach()

        XCTAssertNil(session.activePlayer)
        XCTAssertEqual(session.snapshot, .idle)
        player.stop(reason: .navigation)
    }

    @MainActor
    func testLibraryStoreAllowsHidingSearchRootTab() {
        let defaults = makeUserDefaults()
        let store = LibraryStore(userDefaults: defaults)

        XCTAssertTrue(AppTab.search.canHideFromRootTabBar)
        XCTAssertTrue(AppTab.search.participatesInRootTabVisibilitySettings)

        store.setRootTab(.search, isVisible: false)

        XCTAssertFalse(store.visibleRootTabs.contains(.search))
        XCTAssertFalse(LibraryStore(userDefaults: defaults).visibleRootTabs.contains(.search))
    }

    func testDolbyVisionQualityUsesAutomaticCodecNegotiation() {
        XCTAssertTrue(BiliAPIClient.requiresAutomaticCodecNegotiation(requestedQuality: 125))
        XCTAssertTrue(BiliAPIClient.requiresAutomaticCodecNegotiation(requestedQuality: 126))
        XCTAssertTrue(BiliAPIClient.requiresAutomaticCodecNegotiation(requestedQuality: 129))
        XCTAssertFalse(BiliAPIClient.requiresAutomaticCodecNegotiation(requestedQuality: 120))
    }

    func testHDRPlaybackRecoveryWatchdogAllowsSlowerFirstFrame() {
        XCTAssertLessThan(
            PlaybackRecoveryWatchdogReason.firstFrame.delay(for: .sdr),
            PlaybackRecoveryWatchdogReason.firstFrame.delay(for: .dolbyVision)
        )
        XCTAssertGreaterThanOrEqual(
            PlaybackRecoveryWatchdogReason.firstFrame.delay(for: .dolbyVision),
            11_000_000_000
        )
        XCTAssertLessThan(
            PlaybackRecoveryWatchdogReason.stall.delay(for: .sdr),
            PlaybackRecoveryWatchdogReason.stall.delay(for: .hdr10)
        )
    }

    @MainActor
    func testCoreVideoPlayerManagerUsesAVPlayer() {
        let manager = CoreVideoPlayerManager()

        XCTAssertTrue(manager.makeRenderingEngine() is AVPlayerHLSBridgeEngine)
        XCTAssertTrue(manager.makePlayer() is AVPlayerAdapter)
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "cc.bili.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
