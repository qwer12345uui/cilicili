import SwiftUI

/// iOS 15–25 的兼容主界面。
///
/// 使用系统 `TabView` 的 `tabItem` API，保留截图中的首页、我的和搜索三个核心入口。
/// 入口选择会写入 UserDefaults，应用重启后仍恢复到上次使用的位置。
@available(iOS 15.0, *)
struct LegacyRootTabView: View {
    @EnvironmentObject private var libraryStore: LibraryStore
    @AppStorage("cc.bili.compat.selectedRootTab.v1") private var storedTab = AppTab.home.rawValue
    @State private var selectedTab: String

    init() {
        let savedValue = UserDefaults.standard.string(forKey: "cc.bili.compat.selectedRootTab.v1")
        _selectedTab = State(initialValue: Self.normalizedTabValue(savedValue))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LegacyHomeTab()
                .tabItem {
                    Label(AppTab.home.title, systemImage: AppTab.home.systemImage)
                }
                .tag(AppTab.home.rawValue)

            LegacyMineTab()
                .tabItem {
                    Label(AppTab.mine.title, systemImage: AppTab.mine.systemImage)
                }
                .tag(AppTab.mine.rawValue)

            LegacySearchTab()
                .tabItem {
                    Label(AppTab.search.title, systemImage: AppTab.search.systemImage)
                }
                .tag(AppTab.search.rawValue)
        }
        .accentColor(libraryStore.appTintColor)
        .background(RootTabBarAppearanceInstaller(tintColorHex: libraryStore.appTintColorHex))
        .onChange(of: selectedTab) { value in
            storedTab = Self.normalizedTabValue(value)
        }
    }

    private static func normalizedTabValue(_ value: String?) -> String {
        switch value {
        case AppTab.home.rawValue, AppTab.mine.rawValue, AppTab.search.rawValue:
            return value ?? AppTab.home.rawValue
        default:
            return AppTab.home.rawValue
        }
    }
}

@available(iOS 15.0, *)
private struct LegacyHomeTab: View {
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: AppTab.home.systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text(AppTab.home.title)
                    .font(.title.bold())
                Text("兼容模式保留首页入口与底部导航，使用系统组件以确保 iOS 15 上稳定显示。")
                    .font(.body)
                    .foregroundColor(.secondary)
                Link("打开网页版首页", destination: URL(string: "https://www.bilibili.com")!)
                    .font(.headline)
                Spacer()
            }
            .padding(24)
            .navigationBarTitle(AppTab.home.title, displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

@available(iOS 15.0, *)
private struct LegacyMineTab: View {
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: AppTab.mine.systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text(AppTab.mine.title)
                    .font(.title.bold())
                Text("兼容模式下保留“我的”入口，避免较新系统的导航 API 在旧系统上导致启动失败。")
                    .font(.body)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(24)
            .navigationBarTitle(AppTab.mine.title, displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

@available(iOS 15.0, *)
private struct LegacySearchTab: View {
    @State private var query = ""

    private var searchURL: URL? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return nil }
        var components = URLComponents(string: "https://search.bilibili.com/all")
        components?.queryItems = [URLQueryItem(name: "keyword", value: trimmedQuery)]
        return components?.url
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: AppTab.search.systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text(AppTab.search.title)
                    .font(.title.bold())
                TextField("输入搜索内容", text: $query)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                if let searchURL {
                    Link("搜索", destination: searchURL)
                        .font(.headline)
                } else {
                    Text("输入关键词后可继续搜索。")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(24)
            .navigationBarTitle(AppTab.search.title, displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
