import SwiftUI
import UIKit

struct PlaybackDetailPageHost<Content: View>: View {
    @Binding var hidesSystemChrome: Bool
    let background: Color
    let hidesRootTabBar: Bool
    let navigationBarVisibility: Visibility?
    let hidesBackButton: Bool
    let statusBarStyle: UIStatusBarStyle
    let performanceContext: PlaybackDetailPerformanceContext?
    let content: () -> Content

    init(
        hidesSystemChrome: Binding<Bool>,
        background: Color = Color(.systemGroupedBackground),
        hidesRootTabBar: Bool = true,
        navigationBarVisibility: Visibility? = nil,
        hidesBackButton: Bool = false,
        statusBarStyle: UIStatusBarStyle = .lightContent,
        performanceContext: PlaybackDetailPerformanceContext? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _hidesSystemChrome = hidesSystemChrome
        self.background = background
        self.hidesRootTabBar = hidesRootTabBar
        self.navigationBarVisibility = navigationBarVisibility
        self.hidesBackButton = hidesBackButton
        self.statusBarStyle = statusBarStyle
        self.performanceContext = performanceContext
        self.content = content
    }

    var body: some View {
        content()
            .playbackDetailViewChrome(
                hidesRootTabBar: hidesRootTabBar,
                navigationBarVisibility: navigationBarVisibility,
                hidesBackButton: hidesBackButton
            )
            .background(background)
            .onPreferenceChange(PlaybackDetailChromeHiddenPreferenceKey.self) { isHidden in
                hidesSystemChrome = isHidden
            }
            .playbackDetailSystemChrome(
                isHidden: hidesSystemChrome,
                statusBarStyle: statusBarStyle
            )
            .onAppear {
                guard let performanceContext else { return }
                PlaybackDetailPerformanceMonitor.shared.begin(performanceContext)
                PlaybackDetailPerformanceMonitor.shared.mark(.pageAppeared, context: performanceContext)
            }
            .onDisappear {
                guard let performanceContext else { return }
                PlaybackDetailPerformanceMonitor.shared.end(performanceContext)
            }
    }
}
