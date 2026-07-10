import SwiftUI

struct LiveInlineControlStrip: View {
    @ObservedObject var viewModel: LiveRoomViewModel
    let showDescription: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button(action: showDescription) {
                        LiveInlineMetadataButtonLabel(title: "简介", systemImage: "text.alignleft")
                    }
                    .buttonBorderShape(.capsule)
                    .controlSize(.mini)
                    .biliGlassButtonStyle()

                    LiveStreamInlineMenu(viewModel: viewModel)
                    LiveQualityInlineMenu(viewModel: viewModel)
                    LiveInlineDanmakuButton(viewModel: viewModel)
                    LiveInlineDanmakuDiagnosticsButton(viewModel: viewModel)
                }
                .frame(height: 32)
            }
        }
        .scrollIndicators(.hidden)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.primary)
    }
}

private struct LiveInlineDanmakuButton: View {
    @Environment(\.appThemeTintColor) private var appTintColor

    @ObservedObject var viewModel: LiveRoomViewModel

    var body: some View {
        Button {
            viewModel.toggleDanmaku()
        } label: {
            LiveInlineMetadataButtonLabel(
                title: viewModel.isDanmakuEnabled ? "弹幕开" : "弹幕关",
                systemImage: viewModel.isDanmakuEnabled ? "text.bubble.fill" : "text.bubble"
            )
        }
        .buttonBorderShape(.capsule)
        .controlSize(.mini)
        .biliGlassButtonStyle()
        .foregroundStyle(viewModel.isDanmakuEnabled ? appTintColor : .secondary)
    }
}

private struct LiveInlineDanmakuDiagnosticsButton: View {
    @Environment(\.appThemeTintColor) private var appTintColor

    @ObservedObject var viewModel: LiveRoomViewModel

    var body: some View {
        Button {
            viewModel.toggleLiveDanmakuDiagnostics()
        } label: {
            LiveInlineMetadataButtonLabel(
                title: viewModel.isLiveDanmakuDiagnosticsEnabled ? "诊断开" : "诊断",
                systemImage: "waveform.path.ecg"
            )
        }
        .buttonBorderShape(.capsule)
        .controlSize(.mini)
        .biliGlassButtonStyle()
        .foregroundStyle(viewModel.isLiveDanmakuDiagnosticsEnabled ? appTintColor : .secondary)
    }
}
