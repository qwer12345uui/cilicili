import XCTest
@testable import bili

final class PlayerSpeedBoostPolicyTests: XCTestCase {
    func testRejectsTerminatedPlayback() {
        XCTAssertEqual(
            PlayerSpeedBoostPolicy.rejectionReason(
                isTerminated: true,
                isLiveStream: false,
                isPlaying: true,
                currentRate: .x10
            ),
            .terminated
        )
    }

    func testRejectsLivePlayback() {
        XCTAssertEqual(
            PlayerSpeedBoostPolicy.rejectionReason(
                isTerminated: false,
                isLiveStream: true,
                isPlaying: true,
                currentRate: .x10
            ),
            .live
        )
    }

    func testRejectsPausedPlayback() {
        XCTAssertEqual(
            PlayerSpeedBoostPolicy.rejectionReason(
                isTerminated: false,
                isLiveStream: false,
                isPlaying: false,
                currentRate: .x10
            ),
            .paused
        )
    }

    func testRejectsWhenAlreadyAtTwoTimesSpeed() {
        XCTAssertEqual(
            PlayerSpeedBoostPolicy.rejectionReason(
                isTerminated: false,
                isLiveStream: false,
                isPlaying: true,
                currentRate: .x20
            ),
            .alreadyAtMaximumRate
        )
    }

    func testAllowsPlayingVideoOnARegularRate() {
        XCTAssertNil(
            PlayerSpeedBoostPolicy.rejectionReason(
                isTerminated: false,
                isLiveStream: false,
                isPlaying: true,
                currentRate: .x15
            )
        )
    }
}
