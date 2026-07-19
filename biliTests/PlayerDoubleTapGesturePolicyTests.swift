import CoreGraphics
import XCTest
@testable import bili

final class PlayerDoubleTapGesturePolicyTests: XCTestCase {
    func testAcceptsMiddleHalfForPlaybackToggle() {
        XCTAssertTrue(PlayerDoubleTapGesturePolicy.shouldTogglePlayback(locationX: 100, width: 400))
        XCTAssertTrue(PlayerDoubleTapGesturePolicy.shouldTogglePlayback(locationX: 299, width: 400))
    }

    func testIgnoresLeftAndRightQuarters() {
        XCTAssertFalse(PlayerDoubleTapGesturePolicy.shouldTogglePlayback(locationX: 99, width: 400))
        XCTAssertFalse(PlayerDoubleTapGesturePolicy.shouldTogglePlayback(locationX: 300, width: 400))
    }

    func testIgnoresTapWithoutUsableWidth() {
        XCTAssertFalse(PlayerDoubleTapGesturePolicy.shouldTogglePlayback(locationX: 10, width: 0))
    }
}
