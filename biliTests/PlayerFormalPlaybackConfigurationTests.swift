import XCTest
@testable import bili

final class PlayerFormalPlaybackConfigurationTests: XCTestCase {
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
