import XCTest
@testable import bili

final class PlayerHorizontalSeekSensitivityTests: XCTestCase {
    func testUsesFineControlForShortVideo() {
        XCTAssertEqual(
            PlayerHorizontalSeekSensitivity.secondsPerFullWidth(duration: 3 * 60),
            45
        )
    }

    func testUsesDurationRelativeControlForMediumVideo() {
        XCTAssertEqual(
            PlayerHorizontalSeekSensitivity.secondsPerFullWidth(duration: 15 * 60),
            90
        )
    }

    func testCapsLongVideoTravelDistance() {
        XCTAssertEqual(
            PlayerHorizontalSeekSensitivity.secondsPerFullWidth(duration: 2 * 60 * 60),
            360
        )
    }

    func testFallsBackToExistingSensitivityWithoutDuration() {
        XCTAssertEqual(
            PlayerHorizontalSeekSensitivity.secondsPerFullWidth(duration: nil),
            90
        )
    }
}
