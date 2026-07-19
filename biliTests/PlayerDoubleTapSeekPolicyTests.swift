import CoreGraphics
import XCTest
@testable import bili

final class PlayerDoubleTapSeekPolicyTests: XCTestCase {
    func testRoutesLeftQuarterToBackward() {
        XCTAssertEqual(
            PlayerDoubleTapSeekPolicy.target(locationX: 99, width: 400),
            .backward
        )
    }

    func testRoutesMiddleHalfToCenter() {
        XCTAssertEqual(
            PlayerDoubleTapSeekPolicy.target(locationX: 100, width: 400),
            .center
        )
        XCTAssertEqual(
            PlayerDoubleTapSeekPolicy.target(locationX: 299, width: 400),
            .center
        )
    }

    func testRoutesRightQuarterToForward() {
        XCTAssertEqual(
            PlayerDoubleTapSeekPolicy.target(locationX: 300, width: 400),
            .forward
        )
    }

    func testFallsBackToCenterWithoutUsableWidth() {
        XCTAssertEqual(
            PlayerDoubleTapSeekPolicy.target(locationX: 10, width: 0),
            .center
        )
    }

    func testUsesTenSecondStep() {
        XCTAssertEqual(PlayerDoubleTapSeekPolicy.stepInterval, 10)
    }
}
