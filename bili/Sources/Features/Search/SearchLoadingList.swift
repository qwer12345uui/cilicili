import SwiftUI

struct SearchLoadingList: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                SearchLoadingContent(scope: .comprehensive)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 18)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SearchBottomControlsSkeleton()
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollBounceBehavior(.always, axes: .vertical)
        .background(Color(.systemBackground))
        .nativeTopScrollEdgeEffect()
    }
}

private struct SearchBottomControlsSkeleton: View {
    var body: some View {
        HStack(spacing: 8) {
            SkeletonBlock(height: 36, shape: .rounded(18))
                .frame(maxWidth: .infinity)

            SkeletonBlock(width: 78, height: 36, shape: .rounded(18))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .allowsHitTesting(false)
        .accessibilityLabel("正在加载搜索类型和排序")
    }
}
