import Combine
import SwiftUI

private enum LiveRoomChatLayoutMetrics {
    static let chatOverlaySpacing: CGFloat = 12
    static let bottomContentClearance: CGFloat = 24
}

private enum LiveRoomTheme {
    static let background = Color(.systemGroupedBackground)
    static let chatBubble = Color(.systemGray5)
    static let chatSender = Color(.secondaryLabel)
    static let highlightedChatBubble = Color.orange.opacity(0.16)
    static let highlightedChatSender = Color.orange
}

struct LiveRoomChatTimelineSnapshot: Equatable {
    var items: [DanmakuItem]
    var itemsRevision: Int
    var isEnabled: Bool
    var connectionPhase: LiveDanmakuDiagnosticPhase
    var connectionError: String?
    var isLoadingHistory: Bool
    var historyError: String?

    init(store: LiveDanmakuRenderStore) {
        items = store.chatItems
        itemsRevision = store.chatItemsRevision
        isEnabled = store.isEnabled
        connectionPhase = store.connectionPhase
        connectionError = store.connectionError
        isLoadingHistory = store.isLoadingHistory
        historyError = store.historyError
    }
}

/// Chat can receive several messages per second. During the experimental
/// rotation path, retain the rendered list and publish its newest snapshot once
/// the player surface has settled.
@MainActor
final class LiveRoomChatTimelineState: ObservableObject {
    @Published private(set) var snapshot: LiveRoomChatTimelineSnapshot

    private let store: LiveDanmakuRenderStore
    private let rotationState: LiveRotationSurfaceAlignmentState
    private var cancellables = Set<AnyCancellable>()
    private var publishTask: Task<Void, Never>?
    private var defersUpdates = false
    private var hasDeferredSnapshotUpdate = false

    init(
        store: LiveDanmakuRenderStore,
        rotationState: LiveRotationSurfaceAlignmentState
    ) {
        self.store = store
        self.rotationState = rotationState
        self.snapshot = LiveRoomChatTimelineSnapshot(store: store)

        store.$chatItems
            .sink { [weak self] _ in self?.schedulePublish() }
            .store(in: &cancellables)
        store.$chatItemsRevision
            .sink { [weak self] _ in self?.schedulePublish() }
            .store(in: &cancellables)
        store.$isEnabled
            .sink { [weak self] _ in self?.schedulePublish() }
            .store(in: &cancellables)
        store.$connectionPhase
            .sink { [weak self] _ in self?.schedulePublish() }
            .store(in: &cancellables)
        store.$connectionError
            .sink { [weak self] _ in self?.schedulePublish() }
            .store(in: &cancellables)
        store.$isLoadingHistory
            .sink { [weak self] _ in self?.schedulePublish() }
            .store(in: &cancellables)
        store.$historyError
            .sink { [weak self] _ in self?.schedulePublish() }
            .store(in: &cancellables)
    }

    deinit {
        publishTask?.cancel()
    }

    func setUpdatesDeferred(_ deferred: Bool) {
        guard defersUpdates != deferred else { return }
        defersUpdates = deferred
        if !deferred {
            publishTask?.cancel()
            publishTask = nil
            publishCurrentSnapshot()
        }
    }

    private func schedulePublish() {
        // The rendered list is hidden during rotation. Recording one dirty bit
        // avoids repeatedly copying up to 120 rows on the main actor.
        if defersUpdates {
            markDeferredSnapshotUpdateIfNeeded()
            return
        }
        guard publishTask == nil else { return }
        publishTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            self.publishTask = nil
            self.publishCurrentSnapshot()
        }
    }

    private func publishCurrentSnapshot() {
        let nextSnapshot = LiveRoomChatTimelineSnapshot(store: store)
        guard nextSnapshot != snapshot else {
            hasDeferredSnapshotUpdate = false
            return
        }
        if defersUpdates {
            markDeferredSnapshotUpdateIfNeeded()
            return
        }

        let hadDeferredSnapshotUpdate = hasDeferredSnapshotUpdate
        hasDeferredSnapshotUpdate = false
        snapshot = nextSnapshot
        if hadDeferredSnapshotUpdate {
            rotationState.recordChatFlush()
        }
    }

    private func markDeferredSnapshotUpdateIfNeeded() {
        guard !hasDeferredSnapshotUpdate else { return }
        hasDeferredSnapshotUpdate = true
        rotationState.recordChatDeferred()
    }
}

/// 直播详情的非播放器底层，承载背景、主播栏和聊天时间线。
struct LiveRoomShellContentView: View {
    @MainActor
    final class State: ObservableObject {
        struct Layout: Equatable {
            var width: CGFloat
            var height: CGFloat
            var topSafeAreaInset: CGFloat
            var bottomSafeAreaInset: CGFloat
            var playerHeight: CGFloat
        }

        @Published private(set) var layout: Layout
        let chatTimelineState: LiveRoomChatTimelineState

        var layoutWidth: CGFloat { layout.width }
        var layoutHeight: CGFloat { layout.height }
        var topSafeAreaInset: CGFloat { layout.topSafeAreaInset }
        var bottomSafeAreaInset: CGFloat { layout.bottomSafeAreaInset }
        var playerHeight: CGFloat { layout.playerHeight }

        init(
            layoutWidth: CGFloat = 393,
            layoutHeight: CGFloat = 852,
            chatStore: LiveDanmakuRenderStore,
            rotationState: LiveRotationSurfaceAlignmentState
        ) {
            self.layout = Layout(
                width: layoutWidth,
                height: layoutHeight,
                topSafeAreaInset: 0,
                bottomSafeAreaInset: 0,
                playerHeight: 0
            )
            self.chatTimelineState = LiveRoomChatTimelineState(
                store: chatStore,
                rotationState: rotationState
            )
        }

        func setChatUpdatesDeferred(_ deferred: Bool) {
            chatTimelineState.setUpdatesDeferred(deferred)
        }

        func update(
            layoutWidth: CGFloat,
            layoutHeight: CGFloat,
            topSafeAreaInset: CGFloat,
            bottomSafeAreaInset: CGFloat,
            playerHeight: CGFloat
        ) {
            let nextLayout = Layout(
                width: resolvedLayoutValue(current: layout.width, candidate: layoutWidth),
                height: resolvedLayoutValue(current: layout.height, candidate: layoutHeight),
                topSafeAreaInset: resolvedLayoutValue(
                    current: layout.topSafeAreaInset,
                    candidate: topSafeAreaInset
                ),
                bottomSafeAreaInset: resolvedLayoutValue(
                    current: layout.bottomSafeAreaInset,
                    candidate: bottomSafeAreaInset
                ),
                playerHeight: resolvedLayoutValue(
                    current: layout.playerHeight,
                    candidate: playerHeight
                )
            )
            guard nextLayout != layout else { return }
            layout = nextLayout
        }

        private func resolvedLayoutValue(current: CGFloat, candidate: CGFloat) -> CGFloat {
            abs(current - candidate) > 0.5 ? candidate : current
        }
    }

    @ObservedObject var viewModel: LiveRoomViewModel
    @ObservedObject var state: State
    let onNavigateBack: () -> Void

    var body: some View {
        LiveRoomPiliPodLayoutView(
            viewModel: viewModel,
            state: state,
            onNavigateBack: onNavigateBack
        )
        .frame(width: state.layoutWidth, height: state.layoutHeight, alignment: .top)
        .clipped()
        .ignoresSafeArea()
    }
}

/// A separate, stable background layer lets the shell freeze its chat tree
/// through system rotation without exposing the UIKit fallback color.
struct LiveRoomVisualBackdrop: View {
    @ObservedObject var viewModel: LiveRoomViewModel

    var body: some View {
        CachedRemoteImage(
            url: viewModel.coverURL.flatMap(URL.init(string:)),
            targetPixelSize: 1_120,
            displayCachePolicy: .retained,
            animatesAppearance: false
        ) { image in
            image
                .resizable()
                .scaledToFill()
                .blur(radius: 18)
                .scaleEffect(1.08)
        } placeholder: {
            Color.black
        }
        .overlay(Color.black.opacity(0.52))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
    }
}

private struct LiveRoomPiliPodLayoutView: View {
    @ObservedObject var viewModel: LiveRoomViewModel
    @ObservedObject var state: LiveRoomShellContentView.State
    let onNavigateBack: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                    .frame(
                        height: state.topSafeAreaInset
                            + LiveRoomPiliPodLayoutPolicy.headerContentHeight,
                        alignment: .bottom
                    )

                // UIKit 播放器覆盖这段空间，保留它是为了让下方标题和聊天区
                // 严格跟随直播播放器下沿。
                Color.clear
                    .frame(height: state.playerHeight)

                detailSection
            }
            .frame(
                width: state.layoutWidth,
                height: state.layoutHeight,
                alignment: .top
            )
            .clipped()
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onNavigateBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .biliPlayerClearGlass(interactive: true, in: Circle())
            .biliLiquidGlassForeground(shadowOpacity: 0.20)
            .accessibilityLabel("返回")

            PlaybackDetailOwnerAvatar(
                owner: viewModel.anchorOwner,
                fallbackURLString: viewModel.anchorFace,
                side: 34,
                pixelSize: 96
            )

            Text(viewModel.title)
                .appTypography(.liveRoomTitle, fallback: .system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("直播间：\(viewModel.title)")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var detailSection: some View {
        LiveRoomPiliPodDanmakuTimeline(
            renderState: state.chatTimelineState,
            isDanmakuEnabled: viewModel.isDanmakuEnabled,
            bottomSafeAreaInset: state.bottomSafeAreaInset,
            onEnableDanmaku: viewModel.toggleDanmaku
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
    }
}

private struct LiveRoomPiliPodDanmakuTimeline: View {
    @ObservedObject var renderState: LiveRoomChatTimelineState
    let isDanmakuEnabled: Bool
    let bottomSafeAreaInset: CGFloat
    let onEnableDanmaku: () -> Void
    @State private var followsLatest = true
    private let bottomAnchorID = "live-room-pilipod-danmaku-bottom"

    private var visibleItems: ArraySlice<DanmakuItem> {
        renderState.snapshot.items.suffix(120)
    }

    private var latestAnchorID: String {
        "\(bottomAnchorID)-\(renderState.snapshot.itemsRevision)"
    }

    private var bottomContentInset: CGFloat {
        max(bottomSafeAreaInset, 0) + LiveRoomChatLayoutMetrics.bottomContentClearance
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if !isDanmakuEnabled || !renderState.snapshot.isEnabled {
                Button(action: onEnableDanmaku) {
                    Label("开启弹幕", systemImage: "text.bubble")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .biliPlayerClearGlass(interactive: true, in: Capsule())
                .biliLiquidGlassForeground(shadowOpacity: 0.20)
                .padding(.trailing, 12)
                .padding(.bottom, bottomContentInset + LiveRoomChatLayoutMetrics.chatOverlaySpacing)
                .accessibilityLabel("开启直播弹幕")
            } else {
                timeline
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(visibleItems) { item in
                        LiveRoomPiliPodDanmakuRow(item: item)
                            .id(item.id)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(latestAnchorID)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .padding(.bottom, bottomContentInset)
            }
            .scrollIndicators(.hidden)
            .simultaneousGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { _ in followsLatest = false }
            )
            .onAppear {
                scrollToLatest(using: proxy, anchorID: latestAnchorID)
            }
            .onChange(of: renderState.snapshot.itemsRevision) { _, _ in
                guard followsLatest else { return }
                scrollToLatest(using: proxy, anchorID: latestAnchorID)
            }
            .overlay(alignment: .bottomTrailing) {
                if !followsLatest {
                    Button {
                        followsLatest = true
                        scrollToLatest(using: proxy, anchorID: latestAnchorID)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .biliPlayerClearGlass(interactive: true, in: Circle())
                    .biliLiquidGlassForeground(shadowOpacity: 0.20)
                    .padding(.trailing, 12)
                    .padding(.bottom, bottomContentInset + LiveRoomChatLayoutMetrics.chatOverlaySpacing)
                    .accessibilityLabel("回到最新弹幕")
                }
            }
        }
    }

    private func scrollToLatest(using proxy: ScrollViewProxy, anchorID: String) {
        DispatchQueue.main.async {
            proxy.scrollTo(anchorID, anchor: .bottom)
        }
    }
}

private struct LiveRoomPiliPodDanmakuRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let item: DanmakuItem

    private var sender: (name: String, usesFallback: Bool) {
        guard let senderName = item.senderName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        else {
            return ("匿名用户", true)
        }
        return (senderName, false)
    }

    var body: some View {
        messageContent
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var messageContent: some View {
        if item.inlineEmotes.isEmpty {
            Text(
                "\(Text("\(sender.name)：").font(senderFont).foregroundColor(senderColor))\(Text(item.text).font(messageFont).foregroundColor(.white))"
            )
                .fixedSize(horizontal: false, vertical: true)
        } else {
            BiliEmoteText(
                content: nil,
                plainText: item.text,
                inlineEmotes: item.inlineEmotes,
                font: .system(size: 15),
                textColor: .white,
                emoteSize: 24,
                leadingName: sender.name,
                leadingNameColor: senderColor,
                showsLinkButtons: false,
                fillsAvailableWidth: true,
                typographyRole: .liveChatBody,
                leadingNameTypographyRole: .liveChatName
            )
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var senderColor: Color {
        sender.usesFallback ? Color.white.opacity(0.62) : Color.teal
    }

    private var senderFont: Font {
        Font(
            AppTypography.Role.liveChatName.uiFont(
                contentSizeCategory: dynamicTypeSize.uiContentSizeCategory
            )
        )
    }

    private var messageFont: Font {
        Font(
            AppTypography.Role.liveChatBody.uiFont(
                contentSizeCategory: dynamicTypeSize.uiContentSizeCategory
            )
        )
    }

    private var accessibilityLabel: String {
        "直播弹幕，\(sender.name)：\(item.text)"
    }
}

private struct LiveDanmakuShellDiagnosticsOverlay: View {
    @ObservedObject var store: LiveDanmakuDiagnosticsStore

    var body: some View {
        LiveDanmakuDiagnosticsHUD(snapshot: store.snapshot, isExpanded: false)
            .allowsHitTesting(false)
    }
}

private struct LiveRoomPortraitHeader: View {
    @ObservedObject var viewModel: LiveRoomViewModel
    let onNavigateBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onNavigateBack) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 21, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .contentShape(Circle())
            .biliRegularGlassEffect(interactive: true, in: Circle())
            .accessibilityLabel("返回")

            PlaybackDetailOwnerAvatar(
                owner: viewModel.anchorOwner,
                fallbackURLString: viewModel.anchorFace,
                side: 42,
                pixelSize: 128
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.anchorName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(liveStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            followButton
        }
        .padding(.horizontal, 10)
        .background(LiveRoomTheme.background)
    }

    private var liveStatusText: String {
        if viewModel.isLive {
            return "\(viewModel.onlineText)  正在直播"
        }
        return viewModel.onlineText
    }

    private var followButton: some View {
        DetailToolbarFollowButton(
            isFollowing: viewModel.isFollowingAnchor,
            isLoading: viewModel.isMutatingAnchorFollow,
            canFollow: viewModel.anchorUIDForFollow != nil
        ) {
            Task {
                await viewModel.toggleFollowAnchor()
            }
        }
    }
}

private struct LiveRoomDanmakuTimeline: View {
    @ObservedObject var renderState: LiveRoomChatTimelineState
    let isDanmakuEnabled: Bool
    let bottomSafeAreaInset: CGFloat
    let onEnableDanmaku: () -> Void
    @State private var followsLatest = true

    private var visibleItems: ArraySlice<DanmakuItem> {
        renderState.snapshot.items.suffix(120)
    }

    var body: some View {
        let snapshot = renderState.snapshot
        ZStack(alignment: .bottomTrailing) {
            if !isDanmakuEnabled || !snapshot.isEnabled {
                Button(action: onEnableDanmaku) {
                    Label("开启弹幕", systemImage: "text.bubble")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("开启直播弹幕")
            } else if visibleItems.isEmpty {
                LiveRoomDanmakuEmptyState(
                    phase: snapshot.connectionPhase,
                    error: snapshot.connectionError,
                    isLoadingHistory: snapshot.isLoadingHistory,
                    historyError: snapshot.historyError
                )
            } else {
                timeline
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LiveRoomTheme.background)
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 9) {
                    ForEach(visibleItems) { item in
                        LiveRoomDanmakuBubble(
                            item: item
                        )
                            .id(item.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(
                    .bottom,
                    bottomSafeAreaInset + LiveRoomChatLayoutMetrics.chatOverlaySpacing
                )
            }
            .scrollIndicators(.hidden)
            .simultaneousGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { _ in
                        followsLatest = false
                    }
            )
            .onAppear {
                scrollToLatest(using: proxy)
            }
            .onChange(of: renderState.snapshot.itemsRevision) { _, _ in
                guard followsLatest else { return }
                scrollToLatest(using: proxy)
            }
            .overlay(alignment: .bottomTrailing) {
                if !followsLatest {
                    Button {
                        followsLatest = true
                        scrollToLatest(using: proxy)
                    } label: {
                        Image(systemName: "arrow.down.to.line.compact")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .contentShape(Circle())
                    .biliRegularGlassEffect(interactive: true, in: Circle())
                    .padding(.trailing, 16)
                    .padding(
                        .bottom,
                        bottomSafeAreaInset + 4
                    )
                    .accessibilityLabel("回到最新弹幕")
                }
            }
        }
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let latestID = visibleItems.last?.id else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(latestID, anchor: .bottom)
        }
    }
}

private struct LiveRoomDanmakuEmptyState: View {
    let phase: LiveDanmakuDiagnosticPhase
    let error: String?
    let isLoadingHistory: Bool
    let historyError: String?

    var body: some View {
        VStack(spacing: 10) {
            if showsLoadingIndicator {
                ProgressView()
                    .tint(foregroundColor)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(foregroundColor)
            }

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(primaryTextColor)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(foregroundColor)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var showsLoadingIndicator: Bool {
        if isLoadingHistory {
            return true
        }
        switch phase {
        case .idle, .fetchingConfig, .connecting, .authenticating:
            return true
        case .waitingForPackets, .receiving, .rendering, .reconnecting, .stopped, .failed:
            return false
        }
    }

    private var systemImage: String {
        switch phase {
        case .reconnecting:
            return "arrow.clockwise"
        case .failed:
            return "exclamationmark.triangle"
        case .stopped:
            return "pause.circle"
        case .waitingForPackets, .receiving, .rendering:
            return "text.bubble"
        case .idle, .fetchingConfig, .connecting, .authenticating:
            return "text.bubble"
        }
    }

    private var title: String {
        if isLoadingHistory {
            return "正在加载最近弹幕"
        }
        if historyError != nil {
            return "最近弹幕暂时无法加载"
        }
        switch phase {
        case .waitingForPackets, .receiving, .rendering:
            return "暂时没有新弹幕"
        case .reconnecting:
            return "弹幕正在重新连接"
        case .failed:
            return "弹幕暂时不可用"
        case .stopped:
            return "弹幕已暂停"
        case .idle, .fetchingConfig, .connecting, .authenticating:
            return "正在连接直播弹幕"
        }
    }

    private var subtitle: String? {
        if historyError != nil {
            return "实时弹幕仍会继续接收"
        }
        switch phase {
        case .reconnecting:
            return error?.nilIfEmpty ?? "网络恢复后会继续显示"
        case .failed:
            return error?.nilIfEmpty ?? "请稍后再试"
        default:
            return nil
        }
    }

    private var accessibilityLabel: String {
        [title, subtitle]
            .compactMap { $0 }
            .joined(separator: "，")
    }

    private var primaryTextColor: Color {
        .primary
    }

    private var foregroundColor: Color {
        .secondary
    }
}

private struct LiveRoomDanmakuBubble: View {
    let item: DanmakuItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let senderName {
                Text(senderName)
                    .appTypography(.liveChatName, fallback: .caption.weight(.semibold))
                    .foregroundStyle(senderColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 4)
            }

            messageContent
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(bubbleBackground, in: IncomingMessageBubbleShape())
                .frame(maxWidth: 320, alignment: .leading)
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
    }

    private var senderName: String? {
        guard let name = item.senderName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else { return nil }
        return name
    }

    private var bubbleBackground: Color {
        return item.mode == 5 ? LiveRoomTheme.highlightedChatBubble : LiveRoomTheme.chatBubble
    }

    @ViewBuilder
    private var messageContent: some View {
        if item.inlineEmotes.isEmpty {
            Text(item.text)
                .appTypography(.liveChatBody, fallback: .body)
                .foregroundStyle(messageColor)
        } else {
            BiliEmoteText(
                content: nil,
                plainText: item.text,
                inlineEmotes: item.inlineEmotes,
                font: .body,
                textColor: messageColor,
                emoteSize: 26,
                showsLinkButtons: false,
                fillsAvailableWidth: false,
                typographyRole: .liveChatBody
            )
        }
    }

    private var senderColor: Color {
        return item.mode == 5 ? LiveRoomTheme.highlightedChatSender : LiveRoomTheme.chatSender
    }

    private var messageColor: Color {
        .primary
    }

    private var accessibilityLabel: String {
        if let senderName {
            return "直播弹幕，\(senderName)：\(item.text)"
        }
        return "直播弹幕：\(item.text)"
    }
}

/// 左侧收到消息的非对称圆角，接近系统信息的气泡比例，并避免长弹幕占满整行。
private struct IncomingMessageBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: 5,
            bottomTrailingRadius: 18,
            topTrailingRadius: 18,
            style: .continuous
        )
        .path(in: rect)
    }

}
