import SwiftUI

struct LiveRoomDetailView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    let seedRoom: LiveRoom
    @StateObject private var holder = LiveRoomViewModelHolder()
    @State private var hidesPlayerSystemChrome = false

    var body: some View {
        PlaybackDetailPageHost(
            hidesSystemChrome: $hidesPlayerSystemChrome,
            background: VideoDetailTheme.background,
            navigationBarVisibility: hidesPlayerSystemChrome ? .hidden : .visible,
            statusBarStyle: hidesPlayerSystemChrome ? .lightContent : .default,
            performanceContext: .live(seedRoom),
            lifecycleActions: pageLifecycleActions
        ) {
            PlaybackDetailLoadedStatePage(
                holder.viewModel,
                performanceContext: .live(seedRoom)
            ) { viewModel in
                LiveRoomContentView(viewModel: viewModel)
            } initialContent: {
                LiveRoomInitialPlaceholder(room: seedRoom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    livePrincipalToolbarContent
                }
                ToolbarItem(placement: .topBarTrailing) {
                    liveShareToolbarButton
                }
            }
        }
        .task(id: seedRoom.id) {
            configureAndStartPlaybackIfNeeded()
        }
    }

    private var pageLifecycleActions: PlaybackDetailPageLifecycleActions {
        PlaybackDetailPageLifecycleActions(
            onAppear: {
                holder.viewModel?.resumePlaybackAfterCoveredNavigationIfNeeded()
            },
            onScenePhaseChanged: { phase in
                guard let viewModel = holder.viewModel else { return }
                switch phase {
                case .active:
                    viewModel.resumeLiveDanmakuIfNeeded()
                case .background:
                    viewModel.suspendLiveDanmaku()
                default:
                    break
                }
            },
            onDisappear: {
                holder.viewModel?.stopPlaybackForNavigation()
            }
        )
    }

    private func configureAndStartPlaybackIfNeeded() {
        holder.configure(
            room: seedRoom,
            api: dependencies.api,
            libraryStore: dependencies.libraryStore
        )
        holder.viewModel?.resumePlaybackAfterCoveredNavigationIfNeeded()
    }

    @ViewBuilder
    private var livePrincipalToolbarContent: some View {
        let viewModel = holder.viewModel
        let owner = viewModel?.anchorOwner ?? seedRoom.anchorOwner
        if owner.mid > 0 {
            NavigationLink(value: owner) {
                DetailNavigationOwnerFollowGroup(
                    avatarURLString: owner.face,
                    name: owner.name,
                    subtitle: liveToolbarSubtitle
                ) {
                    liveFollowToolbarButton
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开 \(owner.name) 的主页")
        } else {
            DetailNavigationOwnerFollowGroup(
                avatarURLString: owner.face,
                name: owner.name,
                subtitle: liveToolbarSubtitle
            ) {
                liveFollowToolbarButton
            }
        }
    }

    private var liveToolbarSubtitle: String? {
        guard let viewModel = holder.viewModel else {
            return seedRoom.isLive ? "直播中" : nil
        }
        if let liveTimeText = viewModel.liveTimeText, !liveTimeText.isEmpty {
            return "开播于 \(liveTimeText)"
        }
        return viewModel.isLive ? "直播中" : "未开播"
    }

    @ViewBuilder
    private var liveFollowToolbarButton: some View {
        if let viewModel = holder.viewModel {
            DetailToolbarFollowButton(
                isFollowing: viewModel.isFollowingAnchor,
                isLoading: viewModel.isMutatingAnchorFollow,
                canFollow: viewModel.anchorUIDForFollow != nil
            ) {
                Haptics.light()
                Task {
                    await viewModel.toggleFollowAnchor()
                    Haptics.success()
                }
            }
        } else {
            DetailToolbarFollowButton(
                isFollowing: false,
                isLoading: true,
                canFollow: false,
                action: {}
            )
            .hidden()
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var liveShareToolbarButton: some View {
        let roomID = holder.viewModel?.roomID ?? seedRoom.roomID
        let title = holder.viewModel?.title ?? seedRoom.title
        if let url = LiveRoomDetailView.liveShareURL(roomID: roomID) {
            ShareLink(
                item: url,
                subject: Text(title),
                message: Text(title)
            )
            .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
            .accessibilityLabel("分享直播间")
        } else {
            Button {} label: {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(true)
            .accessibilityLabel("分享直播间")
        }
    }

    private static func liveShareURL(roomID: Int) -> URL? {
        guard roomID > 0 else { return nil }
        return URL(string: "https://live.bilibili.com/\(roomID)")
    }
}
