import SwiftUI

struct LivePlayerLiveEdgeButton: View {
    @Environment(\.playerNativeControlMetrics) private var metrics
    @ObservedObject var viewModel: LiveRoomViewModel

    var body: some View {
        Button {
            viewModel.refreshLiveToLatest()
        } label: {
            Group {
                if viewModel.isRefreshingLiveEdge {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: metrics.iconSize, weight: .semibold))
                }
            }
            .frame(width: metrics.controlHeight, height: metrics.controlHeight)
        }
        .biliPlayerCompactGlassCircle(metrics: metrics)
        .accessibilityLabel("刷新到直播最新进度")
    }
}

/// PiliPod 布局把刷新和画质直接放在播放按钮之后，保持一眼可见的直播控制行。
struct LivePlayerPiliPodAccessory: View {
    @ObservedObject var viewModel: LiveRoomViewModel

    var body: some View {
        HStack(spacing: 8) {
            LivePlayerLiveEdgeButton(viewModel: viewModel)
            LivePlayerPiliPodQualityMenu(viewModel: viewModel)
        }
    }
}

/// PiliPod 在播放层只呈现当前画质文字，不额外放入功能图标，减少直播控制行的视觉噪音。
private struct LivePlayerPiliPodQualityMenu: View {
    @Environment(\.playerNativeControlMetrics) private var metrics
    @ObservedObject var viewModel: LiveRoomViewModel

    var body: some View {
        if viewModel.hasMultipleQualities || viewModel.currentQualityTitle != nil {
            Menu {
                ForEach(viewModel.qualityMenuItems) { item in
                    Button {
                        viewModel.selectQuality(qn: item.qn)
                    } label: {
                        if item.isSelected {
                            Label(item.title, systemImage: "checkmark")
                        } else {
                            Text(item.title)
                        }
                    }
                }
            } label: {
                Text(viewModel.currentQualityTitle ?? "画质")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(minHeight: metrics.controlHeight)
            }
            .biliPlayerClearGlass(interactive: true, in: Capsule())
            .accessibilityLabel("直播画质：\(viewModel.currentQualityTitle ?? "未选择")")
        }
    }
}

struct LivePlayerPiliPodFullscreenBackButton: View {
    @Environment(\.playerNativeControlMetrics) private var metrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: metrics.iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: metrics.controlHeight, height: metrics.controlHeight)
        }
        .biliPlayerCompactGlassCircle(metrics: metrics)
        .accessibilityLabel("退出全屏")
    }
}

struct LivePlayerAccessory: View {
    @ObservedObject var viewModel: LiveRoomViewModel
    let usesCompactLayout: Bool

    init(viewModel: LiveRoomViewModel, usesCompactLayout: Bool = false) {
        self.viewModel = viewModel
        self.usesCompactLayout = usesCompactLayout
    }

    var body: some View {
        Group {
            if usesCompactLayout {
                LiveCompactSettingsMenu(viewModel: viewModel)
            } else {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        LiveQualityMenu(viewModel: viewModel)
                        LiveStreamMenu(viewModel: viewModel)
                        Spacer(minLength: 0)
                        LiveDanmakuToggleButton(viewModel: viewModel)
                        LiveDanmakuDiagnosticsButton(viewModel: viewModel)
                    }
                }
            }
        }
    }
}

struct LivePlayerMoreControlsContent: View {
    @ObservedObject var viewModel: LiveRoomViewModel

    var body: some View {
        Section {
            if viewModel.hasMultipleQualities || viewModel.currentQualityTitle != nil {
                Menu {
                    ForEach(viewModel.qualityMenuItems) { item in
                        Button {
                            viewModel.selectQuality(qn: item.qn)
                        } label: {
                            Label(
                                item.title,
                                systemImage: item.isSelected ? "checkmark" : "slider.horizontal.3"
                            )
                        }
                    }
                } label: {
                    LivePlayerMoreControlsRow(
                        title: "画质",
                        systemImage: "slider.horizontal.3",
                        value: viewModel.currentQualityTitle
                    )
                }
            }

            if viewModel.hasMultipleStreamCandidates || viewModel.currentStreamTitle != nil {
                Menu {
                    ForEach(viewModel.streamMenuItems) { item in
                        Button {
                            viewModel.selectStreamCandidate(id: item.id)
                        } label: {
                            Label(
                                item.title,
                                systemImage: item.isSelected
                                    ? "checkmark"
                                    : "antenna.radiowaves.left.and.right"
                            )
                        }
                    }
                } label: {
                    LivePlayerMoreControlsRow(
                        title: "线路",
                        systemImage: "antenna.radiowaves.left.and.right",
                        value: viewModel.currentStreamTitle
                    )
                }
            }

            Button {
                viewModel.showLivePlaybackDiagnostics()
            } label: {
                LivePlayerMoreControlsRow(
                    title: "播放诊断",
                    systemImage: "waveform.path.ecg.rectangle",
                    value: nil
                )
            }

            Menu {
                Button {
                    viewModel.toggleDanmaku()
                } label: {
                    Label(
                        viewModel.isDanmakuEnabled ? "关闭弹幕" : "开启弹幕",
                        systemImage: viewModel.isDanmakuEnabled ? "text.bubble.fill" : "text.bubble"
                    )
                }

                Toggle(
                    "竖屏时隐藏弹幕",
                    isOn: Binding(
                        get: { viewModel.danmakuSettings.hidesInPortrait },
                        set: { viewModel.setDanmakuHidesInPortrait($0) }
                    )
                )

                Button {
                    viewModel.toggleLiveDanmakuDiagnostics()
                } label: {
                    Label(
                        viewModel.isLiveDanmakuDiagnosticsEnabled ? "关闭弹幕诊断" : "开启弹幕诊断",
                        systemImage: "waveform.path.ecg"
                    )
                }
            } label: {
                LivePlayerMoreControlsRow(
                    title: "弹幕设置",
                    systemImage: "text.bubble",
                    value: viewModel.isDanmakuEnabled ? "已开启" : "已关闭"
                )
            }
        }
    }
}

private struct LivePlayerMoreControlsRow: View {
    let title: String
    let systemImage: String
    let value: String?

    var body: some View {
        HStack(spacing: 10) {
            Label(title, systemImage: systemImage)

            Spacer(minLength: 12)

            if let value {
                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct LiveCompactSettingsMenu: View {
    @ObservedObject var viewModel: LiveRoomViewModel

    var body: some View {
        Menu {
            if viewModel.hasMultipleQualities || viewModel.currentQualityTitle != nil {
                Menu("画质") {
                    ForEach(viewModel.qualityMenuItems) { item in
                        Button {
                            viewModel.selectQuality(qn: item.qn)
                        } label: {
                            Label(
                                item.title,
                                systemImage: item.isSelected ? "checkmark" : "slider.horizontal.3"
                            )
                        }
                    }
                }
            }

            if viewModel.hasMultipleStreamCandidates || viewModel.currentStreamTitle != nil {
                Menu("线路") {
                    ForEach(viewModel.streamMenuItems) { item in
                        Button {
                            viewModel.selectStreamCandidate(id: item.id)
                        } label: {
                            Label(
                                item.title,
                                systemImage: item.isSelected ? "checkmark" : "antenna.radiowaves.left.and.right"
                            )
                        }
                    }
                }
            }

            Divider()

            Button {
                viewModel.showLivePlaybackDiagnostics()
            } label: {
                Label("播放诊断", systemImage: "waveform.path.ecg.rectangle")
            }

            Divider()

            Button {
                viewModel.toggleDanmaku()
            } label: {
                Label(
                    viewModel.isDanmakuEnabled ? "关闭弹幕" : "开启弹幕",
                    systemImage: viewModel.isDanmakuEnabled ? "text.bubble.fill" : "text.bubble"
                )
            }

            Toggle(
                "竖屏时隐藏弹幕",
                isOn: Binding(
                    get: { viewModel.danmakuSettings.hidesInPortrait },
                    set: { viewModel.setDanmakuHidesInPortrait($0) }
                )
            )

            Button {
                viewModel.toggleLiveDanmakuDiagnostics()
            } label: {
                Label(
                    viewModel.isLiveDanmakuDiagnosticsEnabled ? "关闭弹幕诊断" : "开启弹幕诊断",
                    systemImage: "waveform.path.ecg"
                )
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
        }
        .biliPlayerGlassButtonStyle()
        .biliLiquidGlassForeground(shadowOpacity: 0.20)
        .accessibilityLabel("直播设置")
    }
}

struct LiveStreamMenu: View {
    @ObservedObject var viewModel: LiveRoomViewModel

    var body: some View {
        if viewModel.hasMultipleStreamCandidates || viewModel.currentStreamTitle != nil {
            Menu {
                ForEach(viewModel.streamMenuItems) { item in
                    Button {
                        viewModel.selectStreamCandidate(id: item.id)
                    } label: {
                        if item.isSelected {
                            Label(item.title, systemImage: "checkmark")
                        } else {
                            Text(item.title)
                        }
                    }
                }
            } label: {
                Label(viewModel.currentStreamTitle ?? "线路", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .biliPlayerGlassButtonStyle()
            .biliLiquidGlassForeground(shadowOpacity: 0.20)
        }
    }
}

struct LiveQualityMenu: View {
    @ObservedObject var viewModel: LiveRoomViewModel

    var body: some View {
        if viewModel.hasMultipleQualities || viewModel.currentQualityTitle != nil {
            Menu {
                ForEach(viewModel.qualityMenuItems) { item in
                    Button {
                        viewModel.selectQuality(qn: item.qn)
                    } label: {
                        if item.isSelected {
                            Label(item.title, systemImage: "checkmark")
                        } else {
                            Text(item.title)
                        }
                    }
                }
            } label: {
                Label(viewModel.currentQualityTitle ?? "画质", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .biliPlayerGlassButtonStyle()
            .biliLiquidGlassForeground(shadowOpacity: 0.20)
        }
    }
}

private struct LiveDanmakuToggleButton: View {
    @ObservedObject var viewModel: LiveRoomViewModel

    var body: some View {
        Button {
            viewModel.toggleDanmaku()
        } label: {
            Label(
                viewModel.isDanmakuEnabled ? "弹幕开" : "弹幕关",
                systemImage: viewModel.isDanmakuEnabled ? "text.bubble.fill" : "text.bubble"
            )
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .biliPlayerGlassButtonStyle(prominent: viewModel.isDanmakuEnabled)
        .tint(viewModel.isDanmakuEnabled ? .white : .secondary)
        .accessibilityLabel(viewModel.isDanmakuEnabled ? "关闭直播弹幕" : "开启直播弹幕")
    }
}

private struct LiveDanmakuDiagnosticsButton: View {
    @ObservedObject var viewModel: LiveRoomViewModel

    var body: some View {
        Button {
            viewModel.toggleLiveDanmakuDiagnostics()
        } label: {
            Label(
                viewModel.isLiveDanmakuDiagnosticsEnabled ? "诊断开" : "诊断",
                systemImage: "waveform.path.ecg"
            )
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .biliPlayerGlassButtonStyle(prominent: viewModel.isLiveDanmakuDiagnosticsEnabled)
        .tint(viewModel.isLiveDanmakuDiagnosticsEnabled ? .white : .secondary)
        .accessibilityLabel(viewModel.isLiveDanmakuDiagnosticsEnabled ? "关闭直播弹幕诊断" : "开启直播弹幕诊断")
    }
}
