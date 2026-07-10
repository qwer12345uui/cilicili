import SwiftUI

struct MinePlaybackToolsSection: View {
    @ObservedObject var libraryStore: LibraryStore

    var body: some View {
        Section("播放工具") {
            Toggle(isOn: Binding(
                get: { libraryStore.sponsorBlockEnabled },
                set: { libraryStore.setSponsorBlockEnabled($0) }
            )) {
                Label("空降助手", systemImage: "forward.end")
            }

            Toggle(isOn: Binding(
                get: { libraryStore.playerPerformanceOverlayEnabled },
                set: { libraryStore.setPlayerPerformanceOverlayEnabled($0) }
            )) {
                Label("播放性能浮窗", systemImage: "waveform.path.ecg.rectangle")
            }

            Toggle(isOn: Binding(
                get: { libraryStore.videoRotationFrameReportOverlayEnabled },
                set: { libraryStore.setVideoRotationFrameReportOverlayEnabled($0) }
            )) {
                Label("旋转帧报告", systemImage: "rotate.right")
            }

            Toggle(isOn: Binding(
                get: { libraryStore.playerControlEdgeScrimEnabled },
                set: { libraryStore.setPlayerControlEdgeScrimEnabled($0) }
            )) {
                Label("播放控件边缘遮罩", systemImage: "rectangle.dashed")
            }

            Toggle(isOn: Binding(
                get: { libraryStore.showsVideoDetailNetworkDiagnosticsButton },
                set: { libraryStore.setShowsVideoDetailNetworkDiagnosticsButton($0) }
            )) {
                Label("视频详情网络诊断", systemImage: "stethoscope")
            }

            Toggle(isOn: Binding(
                get: { libraryStore.showsVideoDetailPinnedProgressBar },
                set: { libraryStore.setShowsVideoDetailPinnedProgressBar($0) }
            )) {
                Label("视频窗口底部进度条", systemImage: "line.3.horizontal.decrease")
            }

            Toggle(isOn: Binding(
                get: { libraryStore.videoDetailPerformanceExperimentEnabled },
                set: { libraryStore.setVideoDetailPerformanceExperimentEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("视频详情页省刷新实验", systemImage: "rectangle.on.rectangle.angled")

                    Text("减少详情内容和播放器叠层的无关刷新，不会自动显示任何浮窗。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            NavigationLink {
                PlayerPerformanceLogView()
            } label: {
                SettingsNavigationRow(
                    title: "播放性能日志",
                    subtitle: "首帧、缓冲、自动优化记录",
                    systemImage: "speedometer"
                )
            }

            NavigationLink {
                ResourceCacheManagementView()
            } label: {
                SettingsNavigationRow(
                    title: "资源缓存",
                    subtitle: "图片、接口、视频分片缓存",
                    systemImage: "internaldrive"
                )
            }
        }
    }
}
