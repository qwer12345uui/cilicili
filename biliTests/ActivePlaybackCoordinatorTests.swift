import XCTest
@testable import bili

@MainActor
final class ActivePlaybackCoordinatorTests: XCTestCase {
    func testCancelledNavigationRestoresActivePlayerIntent() {
        let coordinator = ActivePlaybackCoordinator.shared
        coordinator.stopActivePlayback()
        defer { coordinator.stopActivePlayback() }

        let player = PlayerStateViewModel(
            videoURL: nil,
            audioURL: nil,
            title: "导航恢复测试",
            referer: "https://www.bilibili.com"
        )
        let surface = VideoSurfaceContainerView()
        player.attachSurface(surface, prefersNativePlaybackControls: false)
        player.play()

        XCTAssertTrue(coordinator.isActive(player))
        XCTAssertTrue(player.wantsAutoplay)

        coordinator.pauseActivePlaybackForNavigation()

        XCTAssertFalse(player.wantsAutoplay)
        let pendingResumeState = player.pendingNavigationResumeState()
        XCTAssertNotNil(pendingResumeState)
        XCTAssertTrue(pendingResumeState?.shouldResumePlayback == true)
        XCTAssertTrue(coordinator.resumeActivePlaybackAfterCancelledNavigation())
        XCTAssertTrue(coordinator.isActive(player))
        XCTAssertTrue(player.wantsAutoplay)
    }

    func testCancelledNavigationWithoutActivePlayerDoesNothing() {
        let coordinator = ActivePlaybackCoordinator.shared
        coordinator.stopActivePlayback()

        XCTAssertFalse(coordinator.resumeActivePlaybackAfterCancelledNavigation())
    }
}
