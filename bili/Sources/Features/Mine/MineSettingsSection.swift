import SwiftUI

struct MineSettingsSection: View {
    @ObservedObject var libraryStore: LibraryStore

    var body: some View {
        Section("设置") {
            NavigationLink {
                MineDisplayAndHomeSettingsView(libraryStore: libraryStore)
            } label: {
                SettingsNavigationRow(
                    title: "显示与首页",
                    subtitle: visibleTabSummary,
                    systemImage: "rectangle.3.group"
                )
            }

            NavigationLink {
                MinePlaybackSettingsView(libraryStore: libraryStore)
            } label: {
                SettingsNavigationRow(
                    title: "播放偏好",
                    subtitle: playbackSettingsSummary,
                    systemImage: "play.rectangle"
                )
            }

            NavigationLink {
                MineContentFilterSettingsView(libraryStore: libraryStore)
            } label: {
                SettingsNavigationRow(
                    title: "内容过滤",
                    subtitle: contentFilterSummary,
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }

            NavigationLink {
                MinePrivacySettingsView(libraryStore: libraryStore)
            } label: {
                SettingsNavigationRow(
                    title: "隐私",
                    subtitle: privacySummary,
                    systemImage: "hand.raised"
                )
            }
        }
    }

    private var visibleTabSummary: String {
        libraryStore.visibleRootTabs
            .filter(\.participatesInRootTabVisibilitySettings)
            .map(\.title)
            .joined(separator: "、")
    }

    private var privacySummary: String {
        var enabled = [String]()
        if libraryStore.incognitoModeEnabled {
            enabled.append("无痕")
        }
        if libraryStore.guestModeEnabled {
            enabled.append("游客")
        }
        return enabled.isEmpty ? "默认" : enabled.joined(separator: "、")
    }

    private var contentFilterSummary: String {
        var parts = ["动态 \(libraryStore.blockedDynamicKeywords.count) 个关键词"]
        if libraryStore.videoRecommendationFilterConfiguration.isActive {
            parts.append("推荐过滤开启")
        }
        return parts.joined(separator: "，")
    }

    private var playbackSettingsSummary: String {
        var parts = [
            libraryStore.playbackAutoOptimizationMode.title,
            libraryStore.videoCodecPreference.title,
            libraryStore.dolbyVisionRenderingPolicy.title
        ]
        if libraryStore.forceHardwareDecodeEnabled {
            parts.append("硬解优先")
        }
        return parts.joined(separator: " · ")
    }
}
