import AVFoundation
import Combine
import QuartzCore
import SwiftUI
import UIKit

/// 直播详情的 UIKit 播放外壳。
///
/// 页面结构、播放器挂载和旋转恢复路径与视频详情保持一致；直播专属的
/// 拉流、清晰度、线路和弹幕仍由 `LiveRoomViewModel` 与 surface host 管理。
@MainActor
final class LiveRoomShellViewController: UIViewController {
    private let viewModel: LiveRoomViewModel
    private let dependencies: AppDependencies
    private let onNavigateBack: () -> Void
    private let playerContainer = UIView()
    private let contentState: LiveRoomShellContentView.State
    private let contentHost: UIHostingController<LiveRoomShellContentView>
    private let loadingHost: UIHostingController<LiveRoomShellLoadingOverlay>
    private var rotationRecoveryDisplayLink: CADisplayLink?
    private var pendingRotationPreparation: (() -> Void)?
    private var pendingRotationRecovery: (() -> Void)?
    private var pendingRotationGeneration: Int?
    private var rotationRecoveryNotBefore: TimeInterval?
    private var rotationGeneration = 0
    private var rotationProbeGeneration = 0
    private var isSystemRotationTransitioning = false
    private var isViewActive = false
    private let rotationFrameProbe = VideoRotationFrameProbe()
    private var cancellables = Set<AnyCancellable>()

    private lazy var playerSurfaceController: PlayerSurfaceController = {
        PlayerSurfaceController(
            parentViewController: self,
            containerView: playerContainer,
            makeHost: { [weak self] playerViewModel in
                guard let self else { return nil }
                return LiveRoomSurfaceHost(
                    playerViewModel: playerViewModel,
                    viewModel: self.viewModel,
                    dependencies: self.dependencies,
                    controlsAccessory: { [weak self] usesCompactLayout in
                        guard let self else { return AnyView(EmptyView()) }
                        return AnyView(
                            LivePlayerAccessory(
                                viewModel: self.viewModel,
                                usesCompactLayout: usesCompactLayout
                            )
                        )
                    },
                    onRequestFullscreen: { [weak self] _ in
                        self?.requestFullscreen()
                    },
                    onExitFullscreen: { [weak self] _ in
                        self?.requestExitFullscreen()
                    },
                    onNavigateBack: { [weak self] in
                        self?.handleBackButton()
                    }
                )
            }
        )
    }()

    init(
        viewModel: LiveRoomViewModel,
        dependencies: AppDependencies,
        onNavigateBack: @escaping () -> Void
    ) {
        let contentState = LiveRoomShellContentView.State()
        self.viewModel = viewModel
        self.dependencies = dependencies
        self.onNavigateBack = onNavigateBack
        self.contentState = contentState
        self.contentHost = UIHostingController(
            rootView: LiveRoomShellContentView(
                viewModel: viewModel,
                state: contentState
            )
        )
        self.loadingHost = UIHostingController(
            rootView: LiveRoomShellLoadingOverlay(viewModel: viewModel)
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationLock.supportedOrientations
    }

    override var prefersStatusBarHidden: Bool {
        isLandscape
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        isLandscape
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        playerContainer.backgroundColor = .black

        contentHost.view.backgroundColor = .clear
        loadingHost.view.backgroundColor = .clear
        loadingHost.view.isOpaque = false
        if #available(iOS 16.4, *) {
            contentHost.safeAreaRegions = []
            loadingHost.safeAreaRegions = []
        }

        addChild(contentHost)
        view.addSubview(contentHost.view)
        contentHost.didMove(toParent: self)

        view.addSubview(playerContainer)
        addChild(loadingHost)
        playerContainer.addSubview(loadingHost.view)
        loadingHost.didMove(toParent: self)

        viewModel.$playerViewModel
            .receive(on: RunLoop.main)
            .sink { [weak self] playerViewModel in
                self?.loadingHost.view.isUserInteractionEnabled = playerViewModel == nil
            }
            .store(in: &cancellables)

        bindPlayerSurface()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isViewActive = true
        AppStatusBarCompatibility.applyPlaybackPresentation(isHidden: isLandscape)
        updateOrientationLock()
        restoreSystemBackGestures()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isViewActive = false
        AppStatusBarCompatibility.restoreDefaultPresentation()
        cancelPendingRotationRecovery()
        playerSurfaceController.cancelRotationChromePrewarm()
        rotationFrameProbe.cancel()
        AppOrientationLock.restorePortrait(in: view.window?.windowScene)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isViewActive = false
        cancelPendingRotationRecovery()
        playerSurfaceController.cancelRotationChromePrewarm()
        AppOrientationLock.restorePortrait(in: view.window?.windowScene)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyLayout()
        restoreSystemBackGestures()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        let toLandscape = size.width > size.height
        AppStatusBarCompatibility.applyPlaybackPresentation(isHidden: toLandscape)
        rotationGeneration &+= 1
        let generation = rotationGeneration
        cancelPendingRotationRecovery()
        playerSurfaceController.cancelRotationChromePrewarm()
        startRotationFrameProbe(
            toLandscape: toLandscape,
            coordinator: coordinator
        )
        PlaybackDetailPerformanceMonitor.shared.mark(
            .fullscreenTransitionStarted,
            context: performanceContext,
            detail: "to=\(toLandscape ? "landscape" : "portrait")"
        )

        // 旋转期间只保留稳定的视频层，避免标题和播放器控件同时参与布局动画。
        contentHost.view.isHidden = true
        contentHost.view.isUserInteractionEnabled = false
        isSystemRotationTransitioning = true
        setBareSurfaceTransitionActive(true)
        // 提前切换隐藏的控件树，把首次布局成本移出系统结束帧。
        playerSurfaceController.setLandscape(toLandscape)
        rotationFrameProbe.mark("旋转开始：目标方向控件已预热")

        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.rotationFrameProbe.mark("系统动画布局开始")
            self.applyLayout(forBoundsSize: size)
            self.view.layoutIfNeeded()
            self.refreshSurfaceLayoutImmediately()
            self.setNeedsStatusBarAppearanceUpdate()
            self.setNeedsUpdateOfHomeIndicatorAutoHidden()
            self.rotationFrameProbe.mark("系统动画布局完成")
        }, completion: { [weak self] _ in
            guard let self, self.rotationGeneration == generation else { return }
            self.finishSystemRotation(toLandscape: toLandscape, generation: generation)
        })
    }

    private var isLandscape: Bool {
        view.bounds.width > view.bounds.height
    }

    private var performanceContext: PlaybackDetailPerformanceContext {
        .live(roomID: viewModel.roomID, title: viewModel.title)
    }

    private func updateOrientationLock() {
        guard isViewActive else { return }
        AppOrientationLock.update(to: .allButUpsideDown, in: view.window?.windowScene)
    }

    private func applyLayout(forBoundsSize size: CGSize? = nil) {
        let bounds = CGRect(origin: .zero, size: size ?? view.bounds.size)
        let landscape = bounds.width > bounds.height
        view.backgroundColor = .black
        let playerHeight = PlaybackDetailShellLayout.standardPlayerHeight(for: bounds.width)
        let layout = PlaybackDetailShellLayout(
            bounds: bounds,
            safeAreaTop: view.safeAreaInsets.top,
            playerHeight: playerHeight,
            contentTopInset: playerHeight,
            usesFullscreenLayout: landscape
        )

        contentHost.view.frame = layout.contentFrame
        playerContainer.frame = layout.playerFrame
        loadingHost.view.frame = playerContainer.bounds
        if let contentTopInset = layout.contentTopInset {
            contentState.update(
                layoutWidth: bounds.width,
                topInset: contentTopInset
            )
        }
        updateSurfaceLayout(usesLandscapeChrome: landscape)
    }

    private func bindPlayerSurface() {
        playerSurfaceController.bind(
            to: viewModel.playbackSession,
            layout: currentSurfaceLayout(usesLandscapeChrome: isLandscape)
        )
    }

    private func currentSurfaceLayout(usesLandscapeChrome: Bool) -> PlayerSurfaceLayout {
        PlayerSurfaceLayout(
            frame: playerContainer.bounds,
            videoAspectRatio: 16.0 / 9.0,
            videoGravity: .resizeAspect,
            usesLandscapeChrome: usesLandscapeChrome,
            isTransitioning: isSystemRotationTransitioning
        )
    }

    private func updateSurfaceLayout(usesLandscapeChrome: Bool) {
        playerSurfaceController.updateLayout(
            currentSurfaceLayout(usesLandscapeChrome: usesLandscapeChrome)
        )
    }

    private func setBareSurfaceTransitionActive(_ active: Bool) {
        playerSurfaceController.setBareSurfaceTransitionActive(
            active,
            retainsChromeTree: active
        )
    }

    private func refreshSurfaceLayoutImmediately() {
        playerSurfaceController.refreshLayoutImmediately()
    }

    private func requestFullscreen() {
        let scene = view.window?.windowScene
        AppOrientationLock.update(to: .allButUpsideDown, in: scene)
        AppOrientationLock.requestGeometryUpdate(to: .landscapeRight, in: scene)
    }

    private func requestExitFullscreen() {
        let scene = view.window?.windowScene
        AppOrientationLock.update(to: .allButUpsideDown, in: scene)
        AppOrientationLock.requestGeometryUpdate(to: .portrait, in: scene)
    }

    private func handleBackButton() {
        if isLandscape {
            requestExitFullscreen()
        } else {
            onNavigateBack()
        }
    }

    private func startRotationFrameProbe(
        toLandscape: Bool,
        coordinator: UIViewControllerTransitionCoordinator
    ) {
        guard dependencies.libraryStore.videoRotationFrameReportOverlayEnabled else { return }
        let roomID = viewModel.roomID
        guard roomID > 0 else { return }
        rotationProbeGeneration &+= 1
        let durationMs = Int((coordinator.transitionDuration * 1000).rounded())
        rotationFrameProbe.start(
            metricsID: "live-\(roomID)",
            title: viewModel.title,
            mode: "liveDetailShell",
            generation: rotationProbeGeneration,
            toLandscape: toLandscape,
            coordinatorSummary: "coordinatorDuration=\(durationMs)ms animated=\(coordinator.isAnimated) interactive=\(coordinator.isInteractive) completionRecovery=retainedChromeStagedDisplayFrames",
            maximumFrameRate: view.window?.windowScene?.screen.maximumFramesPerSecond ?? 60
        )
    }

    private func finishSystemRotation(toLandscape: Bool, generation: Int) {
        rotationFrameProbe.mark("系统完成：保持视频层与已挂载控件树")
        contentHost.view.isHidden = true
        contentHost.view.isUserInteractionEnabled = false

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyLayout()
        CATransaction.commit()
        rotationFrameProbe.mark("视频层几何已提交，等待下一帧")

        scheduleRotationRecovery(
            generation: generation,
            preparation: { [weak self] in
                guard let self, self.rotationGeneration == generation else { return }
                self.rotationFrameProbe.mark("第一帧：预热已挂载控件状态")
                self.playerSurfaceController.setLandscape(toLandscape)
                self.rotationFrameProbe.mark("第一帧：控件方向已就绪")
            },
            recovery: { [weak self] in
                guard let self, self.rotationGeneration == generation else { return }
                self.rotationFrameProbe.mark("第二帧：恢复内容开始")
                self.isSystemRotationTransitioning = false
                self.contentHost.view.isHidden = toLandscape
                self.contentHost.view.isUserInteractionEnabled = !toLandscape
                self.rotationFrameProbe.mark("第二帧：内容已恢复")
                self.setBareSurfaceTransitionActive(false)
                self.rotationFrameProbe.mark("第二帧：叠层和手势已恢复")
                PlaybackDetailPerformanceMonitor.shared.mark(
                    .fullscreenLayoutUpdated,
                    context: self.performanceContext,
                    detail: "landscape=\(toLandscape) strategy=retainedChromeStagedDisplayFrames"
                )
                self.rotationFrameProbe.finish(
                    reason: "系统旋转完成 landscape=\(toLandscape) strategy=retainedChromeStagedDisplayFrames"
                )
            }
        )
    }

    private func scheduleRotationRecovery(
        generation: Int,
        preparation: @escaping () -> Void,
        recovery: @escaping () -> Void
    ) {
        cancelPendingRotationRecovery()
        pendingRotationPreparation = preparation
        pendingRotationRecovery = recovery
        pendingRotationGeneration = generation
        rotationRecoveryNotBefore = CACurrentMediaTime()
            + PlaybackDetailRotationTiming.recoverySettleDelay
        let displayLink = CADisplayLink(
            target: self,
            selector: #selector(runPendingRotationRecovery(_:))
        )
        if #available(iOS 15.0, *) {
            let maximumFrameRate = Float(max(view.window?.windowScene?.screen.maximumFramesPerSecond ?? 60, 60))
            displayLink.preferredFrameRateRange = CAFrameRateRange(
                minimum: 30,
                maximum: maximumFrameRate,
                preferred: maximumFrameRate
            )
        }
        displayLink.add(to: .main, forMode: .common)
        rotationRecoveryDisplayLink = displayLink
    }

    @objc private func runPendingRotationRecovery(_ displayLink: CADisplayLink) {
        guard rotationRecoveryDisplayLink === displayLink,
              let generation = pendingRotationGeneration,
              let recovery = pendingRotationRecovery
        else { return }

        guard generation == rotationGeneration else {
            cancelPendingRotationRecovery()
            return
        }
        if let notBefore = rotationRecoveryNotBefore,
           CACurrentMediaTime() < notBefore {
            return
        }
        rotationRecoveryNotBefore = nil
        if let preparation = pendingRotationPreparation {
            pendingRotationPreparation = nil
            preparation()
            return
        }

        cancelPendingRotationRecovery()
        recovery()
    }

    private func cancelPendingRotationRecovery() {
        rotationRecoveryDisplayLink?.invalidate()
        rotationRecoveryDisplayLink = nil
        pendingRotationPreparation = nil
        pendingRotationRecovery = nil
        pendingRotationGeneration = nil
        rotationRecoveryNotBefore = nil
    }

    private func restoreSystemBackGestures() {
        guard let navigationController else { return }
        navigationController.interactivePopGestureRecognizer?.isEnabled = true
        navigationController.interactivePopGestureRecognizer?.delegate = self
        navigationController.interactiveContentPopGestureRecognizer?.isEnabled = true
        navigationController.interactiveContentPopGestureRecognizer?.delegate = self
    }

    private func isSystemBackGesture(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController else { return false }
        return gestureRecognizer === navigationController.interactivePopGestureRecognizer
            || gestureRecognizer === navigationController.interactiveContentPopGestureRecognizer
    }
}

extension LiveRoomShellViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard isSystemBackGesture(gestureRecognizer) else { return true }
        guard !isLandscape else { return false }
        return navigationController?.viewControllers.count ?? 0 > 1
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard isSystemBackGesture(gestureRecognizer) else { return true }
        guard !isLandscape else { return false }
        return !playerContainer.frame.contains(touch.location(in: view))
    }
}

private struct LiveRoomShellLoadingOverlay: View {
    @ObservedObject var viewModel: LiveRoomViewModel

    var body: some View {
        Group {
            if viewModel.playerViewModel == nil {
                ZStack {
                    Color.black

                    switch viewModel.state {
                    case .failed(let message):
                        LivePlayerFailurePlaceholder(message: message, retry: viewModel.reload)
                    default:
                        LivePlayerLoadingPlaceholder(
                            title: viewModel.title.nilIfEmpty ?? "正在进入直播间",
                            subtitle: viewModel.currentQualityTitle
                                ?? viewModel.currentStreamTitle
                                ?? "正在拉取直播流"
                        )
                    }
                }
            } else {
                Color.clear
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
