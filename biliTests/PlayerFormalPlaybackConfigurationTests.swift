import XCTest
@testable import bili

final class PlayerFormalPlaybackConfigurationTests: XCTestCase {
    func testLivePlayerControlLayoutOnlyKeepsNavigationActions() {
        XCTAssertFalse(BiliPlayerControlLayout.live.showsProgress)
        XCTAssertFalse(BiliPlayerControlLayout.live.showsPlaybackToggle)
        XCTAssertFalse(BiliPlayerControlLayout.live.showsTimeLabel)

        XCTAssertTrue(BiliPlayerControlLayout.standard.showsProgress)
        XCTAssertTrue(BiliPlayerControlLayout.standard.showsPlaybackToggle)
        XCTAssertTrue(BiliPlayerControlLayout.standard.showsTimeLabel)
    }

    @MainActor
    func testPlayerSettingsMigratesLegacyAV1CodecPreferenceToAuto() {
        let defaults = makeUserDefaults()
        defaults.set("forceAV1", forKey: VideoCodecPreference.storageKey)

        let settings = PlayerSettings(userDefaults: defaults)
        settings.reload()

        XCTAssertEqual(settings.videoCodecPreference, .auto)
        XCTAssertEqual(defaults.string(forKey: VideoCodecPreference.storageKey), VideoCodecPreference.auto.rawValue)
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
