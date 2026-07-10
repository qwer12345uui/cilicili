import SwiftUI
import UIKit

struct LiveRoomContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var viewModel: LiveRoomViewModel
    @State var isShowingDescription = false
    @State var fullscreenMode: PlayerFullscreenMode?
    @State var isCompletingFullscreenExit = false
    @State var pendingFullscreenExitTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            let layout = LiveRoomContentLayout(
                proxySize: proxy.size,
                fullscreenGeometry: proxy.liveDetailFullscreenContainerGeometry,
                fullscreenMode: fullscreenMode,
                isCompletingFullscreenExit: isCompletingFullscreenExit
            )

            standardPlaybackPage(
                viewModel,
                screenSize: layout.screenSize,
                isLandscape: layout.isLandscape,
                isInlineFullscreen: layout.isInlineFullscreen
            )
            .frame(
                width: layout.frameSize.width,
                height: layout.frameSize.height
            )
            .offset(layout.frameOffset)
            .background(layout.isLandscape ? Color.black : VideoDetailTheme.background)
            .ignoresSafeArea(.container, edges: layout.ignoresContainerSafeArea ? .all : [])
            .preference(key: PlaybackDetailChromeHiddenPreferenceKey.self, value: layout.shouldHideSystemChrome)
        }
        .background(VideoDetailTheme.background)
        .overlay {
            if let fullPageFailureMessage {
                ErrorStateView(
                    title: "直播加载失败",
                    message: fullPageFailureMessage,
                    retry: viewModel.reload
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VideoDetailTheme.background.opacity(0.96))
            }
        }
        .task(id: viewModel.roomID) {
            viewModel.startLoading()
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            allowLiveAutoRotation()
            updateLiveFullscreenOrientation(UIDevice.current.orientation)
        }
        .onDisappear {
            pendingFullscreenExitTask?.cancel()
            viewModel.stopPlaybackForNavigation()
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            AppOrientationLock.restorePortrait()
            fullscreenMode = nil
            isCompletingFullscreenExit = false
        }
        .sheet(isPresented: $isShowingDescription) {
            LiveRoomDescriptionSheet(viewModel: viewModel)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if fullscreenMode == nil {
                    allowLiveAutoRotation()
                }
                viewModel.resumeLiveDanmakuIfNeeded()
            case .background:
                viewModel.suspendLiveDanmaku()
            default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateLiveFullscreenOrientation(UIDevice.current.orientation)
        }
        .ignoresSafeArea(.container, edges: (fullscreenMode != nil || isCompletingFullscreenExit) ? .all : [])
    }

    private var fullPageFailureMessage: String? {
        guard case .failed(let message) = viewModel.state, viewModel.playerViewModel == nil else {
            return nil
        }
        return message
    }

    private func standardPlaybackPage(
        _ viewModel: LiveRoomViewModel,
        screenSize: CGSize,
        isLandscape: Bool,
        isInlineFullscreen: Bool
    ) -> some View {
        let standardPlayerHeight = PlaybackDetailPlayerMetrics.standardHeight(for: screenSize.width)
        let expandsToFullscreen = isLandscape || isInlineFullscreen

        return PlaybackDetailPlayerStage(
            screenSize: screenSize,
            showsContent: !isLandscape,
            contentOpacity: isInlineFullscreen ? 0 : 1,
            allowsContentHitTesting: !isInlineFullscreen,
            showsFullscreenBackdrop: expandsToFullscreen,
            background: VideoDetailTheme.background
        ) {
            PlaybackDetailScrollPage(
                layoutWidth: screenSize.width,
                topInset: standardPlayerHeight,
                background: VideoDetailTheme.background
            ) {
                detailScrollPage(viewModel, layoutWidth: screenSize.width)
                    .frame(width: screenSize.width, alignment: .top)
            }
        } player: {
            playerHero(
                viewModel,
                isLandscape: isLandscape,
                fullscreenMode: fullscreenMode,
                playerWidth: isLandscape ? screenSize.width : nil,
                playerHeight: expandsToFullscreen ? screenSize.height : standardPlayerHeight
            )
        }
    }

    private func playerHero(
        _ viewModel: LiveRoomViewModel,
        isLandscape: Bool,
        fullscreenMode: PlayerFullscreenMode?,
        playerWidth: CGFloat?,
        playerHeight: CGFloat
    ) -> some View {
        LiveRoomPlayerHero(
            viewModel: viewModel,
            isLandscape: isLandscape,
            fullscreenMode: fullscreenMode,
            playerWidth: playerWidth,
            playerHeight: playerHeight,
            controlsAccessory: { AnyView(livePlayerAccessory(viewModel)) },
            loadingPlaceholder: { AnyView(liveLoadingPlaceholder(viewModel)) },
            onRequestFullscreen: enterInlineFullscreenPlayback(playerViewModel:),
            onExitFullscreen: exitInlineFullscreenPlayback(playerViewModel:)
        )
    }
}
