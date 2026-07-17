import AVFoundation
import Combine
import SwiftUI
import UIKit

/// 直播播放器的正式视频层协调入口。
/// SwiftUI 仍拥有直播详情内容与控件，UIKit 只托管稳定的 player surface 容器。
struct LiveRoomSurfaceCoordinatorView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: LiveRoomViewModel
    let playbackSession: PlaybackSession
    let dependencies: AppDependencies
    let usesLandscapeChrome: Bool
    let controlsAccessory: (Bool) -> AnyView
    let onRequestFullscreen: (PlayerStateViewModel?) -> Void
    let onExitFullscreen: (PlayerStateViewModel?) -> Void

    func makeUIViewController(context _: Context) -> LiveRoomSurfaceCoordinatorViewController {
        LiveRoomSurfaceCoordinatorViewController(
            viewModel: viewModel,
            playbackSession: playbackSession,
            dependencies: dependencies,
            usesLandscapeChrome: usesLandscapeChrome,
            controlsAccessory: controlsAccessory,
            onRequestFullscreen: onRequestFullscreen,
            onExitFullscreen: onExitFullscreen
        )
    }

    func updateUIViewController(
        _ viewController: LiveRoomSurfaceCoordinatorViewController,
        context _: Context
    ) {
        viewController.update(
            playbackSession: playbackSession,
            usesLandscapeChrome: usesLandscapeChrome
        )
    }
}

@MainActor
final class LiveRoomSurfaceCoordinatorViewController: UIViewController {
    private let viewModel: LiveRoomViewModel
    private let dependencies: AppDependencies
    private let controlsAccessory: (Bool) -> AnyView
    private let onRequestFullscreen: (PlayerStateViewModel?) -> Void
    private let onExitFullscreen: (PlayerStateViewModel?) -> Void
    private let playerContainer = UIView()
    private var playbackSession: PlaybackSession
    private var usesLandscapeChrome: Bool

    private lazy var surfaceController: PlayerSurfaceController = {
        PlayerSurfaceController(
            parentViewController: self,
            containerView: playerContainer,
            makeHost: { [weak self] playerViewModel in
                guard let self else { return nil }
                return LiveRoomSurfaceHost(
                    playerViewModel: playerViewModel,
                    viewModel: self.viewModel,
                    dependencies: self.dependencies,
                    controlsAccessory: self.controlsAccessory,
                    onRequestFullscreen: self.onRequestFullscreen,
                    onExitFullscreen: self.onExitFullscreen
                )
            }
        )
    }()

    init(
        viewModel: LiveRoomViewModel,
        playbackSession: PlaybackSession,
        dependencies: AppDependencies,
        usesLandscapeChrome: Bool,
        controlsAccessory: @escaping (Bool) -> AnyView,
        onRequestFullscreen: @escaping (PlayerStateViewModel?) -> Void,
        onExitFullscreen: @escaping (PlayerStateViewModel?) -> Void
    ) {
        self.viewModel = viewModel
        self.playbackSession = playbackSession
        self.dependencies = dependencies
        self.usesLandscapeChrome = usesLandscapeChrome
        self.controlsAccessory = controlsAccessory
        self.onRequestFullscreen = onRequestFullscreen
        self.onExitFullscreen = onExitFullscreen
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        playerContainer.backgroundColor = .black
        view.addSubview(playerContainer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerContainer.frame = view.bounds
        bindSurface()
    }

    func update(
        playbackSession: PlaybackSession,
        usesLandscapeChrome: Bool
    ) {
        self.playbackSession = playbackSession
        self.usesLandscapeChrome = usesLandscapeChrome
        guard isViewLoaded else { return }
        bindSurface()
    }

    private func bindSurface() {
        let layout = PlayerSurfaceLayout(
            frame: playerContainer.bounds,
            videoAspectRatio: 16.0 / 9.0,
            videoGravity: .resizeAspect,
            usesLandscapeChrome: usesLandscapeChrome,
            isTransitioning: false
        )
        surfaceController.bind(to: playbackSession, layout: layout)
    }
}

@MainActor
final class LiveRoomSurfaceHost: UIView, PlayerSurfaceHosting {
    @MainActor
    final class State: ObservableObject {
        @Published var playerViewModel: PlayerStateViewModel
        @Published var usesLandscapeChrome = false
        @Published var isBareSurfaceTransitionActive = false
        @Published var videoAspectRatio: CGFloat = 16.0 / 9.0

        init(playerViewModel: PlayerStateViewModel) {
            self.playerViewModel = playerViewModel
        }
    }

    private let state: State
    private var videoGravity: AVLayerVideoGravity = .resizeAspect
    private let hostingController: UIHostingController<LiveRoomSurfaceRoot>
    private var rotationChromePrewarmGeneration = 0
    private var isRotationChromePrewarming = false
    private var rotationChromePrewarmOriginalLandscape: Bool?

    init(
        playerViewModel: PlayerStateViewModel,
        viewModel: LiveRoomViewModel,
        dependencies: AppDependencies,
        controlsAccessory: @escaping (Bool) -> AnyView,
        onRequestFullscreen: @escaping (PlayerStateViewModel?) -> Void,
        onExitFullscreen: @escaping (PlayerStateViewModel?) -> Void,
        onNavigateBack: @escaping () -> Void = {}
    ) {
        let state = State(playerViewModel: playerViewModel)
        self.state = state
        self.hostingController = UIHostingController(
            rootView: LiveRoomSurfaceRoot(
                state: state,
                viewModel: viewModel,
                dependencies: dependencies,
                controlsAccessory: controlsAccessory,
                onRequestFullscreen: onRequestFullscreen,
                onExitFullscreen: onExitFullscreen,
                onNavigateBack: onNavigateBack
            )
        )
        super.init(frame: .zero)

        backgroundColor = .black
        hostingController.view.backgroundColor = .black
        if #available(iOS 16.4, *) {
            hostingController.safeAreaRegions = []
        }
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var surfaceView: UIView { self }

    func attach(to parent: UIViewController) {
        parent.addChild(hostingController)
        hostingController.didMove(toParent: parent)
    }

    func setPlayerViewModel(_ playerViewModel: PlayerStateViewModel) {
        guard state.playerViewModel !== playerViewModel else { return }
        state.playerViewModel = playerViewModel
        playerViewModel.setVideoGravity(videoGravity)
    }

    func setVideoGravity(_ gravity: AVLayerVideoGravity) {
        guard videoGravity != gravity else { return }
        videoGravity = gravity
        state.playerViewModel.setVideoGravity(gravity)
    }

    func setVideoAspectRatio(_ aspectRatio: CGFloat) {
        guard aspectRatio > 0.1,
              abs(state.videoAspectRatio - aspectRatio) > 0.001
        else { return }
        state.videoAspectRatio = aspectRatio
    }

    func setLandscape(_ landscape: Bool) {
        guard state.usesLandscapeChrome != landscape else { return }
        state.usesLandscapeChrome = landscape
    }

    func setBareSurfaceTransitionActive(_ active: Bool, retainsChromeTree _: Bool) {
        cancelRotationChromePrewarm()
        guard state.isBareSurfaceTransitionActive != active else { return }
        state.isBareSurfaceTransitionActive = active
    }

    func prewarmRotationChrome() {
        guard !isRotationChromePrewarming,
              !state.isBareSurfaceTransitionActive
        else { return }
        isRotationChromePrewarming = true
        rotationChromePrewarmGeneration &+= 1
        let generation = rotationChromePrewarmGeneration
        let originalLandscape = state.usesLandscapeChrome
        rotationChromePrewarmOriginalLandscape = originalLandscape

        UIView.performWithoutAnimation {
            state.isBareSurfaceTransitionActive = true
            state.usesLandscapeChrome = !originalLandscape
        }
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.isRotationChromePrewarming,
                  self.rotationChromePrewarmGeneration == generation
            else { return }
            self.layoutRotationChromePrewarm()
            UIView.performWithoutAnimation {
                self.state.usesLandscapeChrome = originalLandscape
            }
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.isRotationChromePrewarming,
                      self.rotationChromePrewarmGeneration == generation
                else { return }
                self.layoutRotationChromePrewarm()
                UIView.performWithoutAnimation {
                    self.state.isBareSurfaceTransitionActive = false
                }
                self.isRotationChromePrewarming = false
                self.rotationChromePrewarmOriginalLandscape = nil
            }
        }
    }

    func cancelRotationChromePrewarm() {
        guard isRotationChromePrewarming else { return }
        rotationChromePrewarmGeneration &+= 1
        isRotationChromePrewarming = false
        let originalLandscape = rotationChromePrewarmOriginalLandscape
        rotationChromePrewarmOriginalLandscape = nil
        UIView.performWithoutAnimation {
            if let originalLandscape {
                state.usesLandscapeChrome = originalLandscape
            }
            state.isBareSurfaceTransitionActive = false
        }
    }

    func refreshLayoutImmediately() {
        UIView.performWithoutAnimation {
            setNeedsLayout()
            layoutIfNeeded()
            hostingController.view.setNeedsLayout()
            hostingController.view.layoutIfNeeded()
            state.playerViewModel.refreshSurfaceLayout()
        }
    }

    private func layoutRotationChromePrewarm() {
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
    }
}

private struct LiveRoomSurfaceRoot: View {
    @ObservedObject var state: LiveRoomSurfaceHost.State
    @ObservedObject var viewModel: LiveRoomViewModel
    let dependencies: AppDependencies
    let controlsAccessory: (Bool) -> AnyView
    let onRequestFullscreen: (PlayerStateViewModel?) -> Void
    let onExitFullscreen: (PlayerStateViewModel?) -> Void
    let onNavigateBack: () -> Void

    var body: some View {
        let playerViewModel = state.playerViewModel
        BiliPlayerView(
            viewModel: playerViewModel,
            historyVideo: nil,
            historyCID: nil,
            options: BiliPlayerViewOptions(
                presentation: state.usesLandscapeChrome ? .fullScreen : .embedded,
                showsNavigationChrome: false,
                showsPlaybackControls: !state.isBareSurfaceTransitionActive,
                showsStartupLoadingIndicator: !state.isBareSurfaceTransitionActive,
                pausesOnDisappear: false,
                surfaceOverlay: AnyView(
                    LiveDanmakuOverlay(
                        store: viewModel.liveDanmakuRenderStore,
                        playerViewModel: playerViewModel,
                        usesLandscapeChrome: state.usesLandscapeChrome
                    )
                ),
                controlsAccessory: nil,
                topLeadingControlsAccessory: AnyView(
                    VideoDetailPlayerSurfaceBackButtonHost {
                        if state.usesLandscapeChrome {
                            onExitFullscreen(playerViewModel)
                        } else {
                            onNavigateBack()
                        }
                    }
                ),
                controlLayout: .live,
                moreControlsContent: AnyView(
                    LivePlayerMoreControlsContent(viewModel: viewModel)
                ),
                replacesStandardMoreControls: true,
                isDanmakuEnabled: viewModel.isDanmakuEnabled,
                keepsPlayerSurfaceStable: true,
                fullscreenMode: state.usesLandscapeChrome ? .landscape(.landscapeRight) : nil,
                isLayoutTransitioning: state.isBareSurfaceTransitionActive,
                usesLiveSurfaceDuringLayoutTransition: true,
                disablesSurfaceImplicitLayoutAnimations: true,
                showsRotationTransitionSnapshot: false,
                onRequestFullscreen: {
                    onRequestFullscreen(playerViewModel)
                },
                onExitFullscreen: {
                    onExitFullscreen(playerViewModel)
                }
            )
        )
        .id(ObjectIdentifier(playerViewModel))
        .background {
            PlaybackDetailPlayerReadinessProbe(
                playerViewModel: playerViewModel,
                context: .live(roomID: viewModel.roomID, title: viewModel.title)
            )
        }
        .environmentObject(dependencies)
        .environmentObject(viewModel.libraryStore)
        .environment(\.appThemeTintColor, viewModel.libraryStore.appTintColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .ignoresSafeArea()
    }
}
