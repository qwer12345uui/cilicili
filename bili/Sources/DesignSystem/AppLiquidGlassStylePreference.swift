import Foundation

enum AppLiquidGlassStylePreference: String, CaseIterable, Identifiable {
    case current
    case appleRecommended

    static let storageKey = "cc.bili.display.liquidGlassStylePreference.v1"
    static let defaultValue: AppLiquidGlassStylePreference = .appleRecommended

    var id: String { rawValue }

    init(storedRawValue: String?) {
        self = Self(rawValue: storedRawValue ?? "") ?? Self.defaultValue
    }

    var title: String {
        switch self {
        case .current:
            return "当前效果"
        case .appleRecommended:
            return "Apple 官方推荐"
        }
    }

    var detail: String {
        switch self {
        case .current:
            return "保留现有偏透明、轻着色和播放器清透玻璃效果。"
        case .appleRecommended:
            return "优先使用系统 regular glass，减少自定义 tint，交互控件保留系统响应。"
        }
    }
}
