import XCTest
@testable import bili

@MainActor
final class LiveRoomPlaybackLifecycleTests: XCTestCase {
    func testNavigationStopTerminatesAndUnregistersLivePlayer() {
        let coordinator = ActivePlaybackCoordinator.shared
        coordinator.stopActivePlayback()
        defer { coordinator.stopActivePlayback() }

        let defaultsName = "LiveRoomPlaybackLifecycleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let viewModel = makeViewModel(defaults: defaults, keychainService: defaultsName)
        let player = PlayerStateViewModel(
            videoURL: nil,
            audioURL: nil,
            title: "直播生命周期测试",
            referer: "https://live.bilibili.com/1"
        )
        let surface = VideoSurfaceContainerView()
        player.attachSurface(surface, prefersNativePlaybackControls: false)
        player.play()
        viewModel.playerViewModel = player

        XCTAssertTrue(coordinator.isActive(player))

        viewModel.stopPlaybackForNavigation()

        XCTAssertNil(viewModel.playerViewModel)
        XCTAssertTrue(player.isTerminated)
        XCTAssertFalse(coordinator.isActive(player))
    }

    private func makeViewModel(defaults: UserDefaults, keychainService: String) -> LiveRoomViewModel {
        let libraryStore = LibraryStore(userDefaults: defaults)
        let sessionStore = SessionStore(keychain: KeychainStore(service: keychainService))
        let api = BiliAPIClient(
            session: URLSession(configuration: .ephemeral),
            sessionStore: sessionStore,
            libraryStore: libraryStore,
            homeRecommendDiagnosticsStore: .shared
        )
        return LiveRoomViewModel(
            seedRoom: LiveRoom(
                roomID: 1,
                title: "测试直播间",
                uname: "测试主播",
                uid: 1,
                face: nil,
                cover: nil,
                keyframe: nil,
                online: nil,
                areaName: nil,
                parentAreaName: nil,
                liveStatus: 1
            ),
            api: api,
            libraryStore: libraryStore
        )
    }
}
