import Combine
import SwiftUI

/// 直播详情页的内容区和视频详情页使用同一套“顶部播放器 + 下方滚动内容”结构。
/// 直播只提供标题和主播头像，不引入视频详情的分集、评论或相关推荐数据。
struct LiveRoomShellContentView: View {
    @MainActor
    final class State: ObservableObject {
        @Published private(set) var layoutWidth: CGFloat
        @Published private(set) var topInset: CGFloat = 0

        init(layoutWidth: CGFloat = 393) {
            self.layoutWidth = layoutWidth
        }

        func update(layoutWidth: CGFloat, topInset: CGFloat) {
            if abs(self.layoutWidth - layoutWidth) > 0.5 {
                self.layoutWidth = layoutWidth
            }
            if abs(self.topInset - topInset) > 0.5 {
                self.topInset = topInset
            }
        }
    }

    @ObservedObject var viewModel: LiveRoomViewModel
    @ObservedObject var state: State

    var body: some View {
        PlaybackDetailScrollPage(
            layoutWidth: state.layoutWidth,
            topInset: state.topInset,
            background: VideoDetailTheme.background
        ) {
            PlaybackDetailContentPage(
                layoutWidth: state.layoutWidth,
                horizontalPadding: PlaybackDetailContentMetrics.horizontalPadding,
                topPadding: PlaybackDetailContentMetrics.topPadding,
                bottomPadding: 28,
                spacing: PlaybackDetailContentMetrics.spacing,
                background: VideoDetailTheme.background
            ) { contentWidth in
                LiveRoomMinimalDetailHeader(viewModel: viewModel)
                    .frame(width: contentWidth, alignment: .leading)
            }
        }
        .background(VideoDetailTheme.background)
    }
}
