import Foundation
import Photos
import SwiftUI
import UIKit

@main
struct CiliCiliCompatibilityApp: App {
    var body: some Scene {
        WindowGroup {
            CompatibilityRootView()
        }
    }
}

private enum CompatibilityTab: String, CaseIterable, Identifiable {
    case home
    case mine
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "首页"
        case .mine:
            return "我的"
        case .search:
            return "搜索"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .mine:
            return "person.crop.circle.fill"
        case .search:
            return "magnifyingglass"
        }
    }
}

private struct CompatibilityRootView: View {
    @AppStorage("cc.bili.compat.selectedRootTab.v2") private var storedTab = CompatibilityTab.home.rawValue
    @State private var selectedTab = CompatibilityTab.home

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            activeScreen
                .padding(.bottom, 106)

            FloatingCompatibilityTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .accentColor(CompatibilityPalette.pink)
        .onAppear {
            selectedTab = CompatibilityTab(rawValue: storedTab) ?? .home
        }
        .onChange(of: selectedTab) { value in
            storedTab = value.rawValue
        }
    }

    @ViewBuilder
    private var activeScreen: some View {
        switch selectedTab {
        case .home:
            CompatibilityHomeView()
        case .mine:
            CompatibilityMineView()
        case .search:
            CompatibilitySearchView()
        }
    }
}

private struct FloatingCompatibilityTabBar: View {
    @Binding var selectedTab: CompatibilityTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CompatibilityTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 27, weight: .semibold))
                            .frame(height: 29)
                        Text(tab.title)
                            .font(.system(size: 13, weight: selectedTab == tab ? .bold : .semibold))
                    }
                    .foregroundColor(selectedTab == tab ? CompatibilityPalette.pink : .primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
                    .background(selectionBackground(for: tab))
                    .contentShape(Capsule())
                }
                .buttonStyle(CompatibilityPressStyle())
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.64), lineWidth: 0.9)
                )
        )
        .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 8)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func selectionBackground(for tab: CompatibilityTab) -> some View {
        if selectedTab == tab {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [CompatibilityPalette.pink.opacity(0.18), CompatibilityPalette.pink.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(1)
        } else {
            Color.clear
        }
    }
}

private struct CompatibilityHomeView: View {
    private let highlights = [
        CompatibilityHighlight(title: "发现精彩内容", subtitle: "原生推荐框架", symbol: "sparkles", colors: [Color(red: 0.97, green: 0.42, blue: 0.61), Color(red: 0.45, green: 0.29, blue: 0.76)]),
        CompatibilityHighlight(title: "旅行与人文", subtitle: "在城市之间漫游", symbol: "map.fill", colors: [Color(red: 0.13, green: 0.62, blue: 0.68), Color(red: 0.07, green: 0.23, blue: 0.42)]),
        CompatibilityHighlight(title: "音乐现场", subtitle: "聆听此刻心动", symbol: "music.note", colors: [Color(red: 0.98, green: 0.57, blue: 0.20), Color(red: 0.73, green: 0.17, blue: 0.39)])
    ]

    private let cards = [
        CompatibilityFeedCard(title: "夏日城市漫游指南", caption: "带着相机，记录傍晚的风", duration: "08:42", symbol: "building.2.crop.circle.fill", colors: [Color(red: 0.20, green: 0.53, blue: 0.76), Color(red: 0.79, green: 0.89, blue: 0.94)]),
        CompatibilityFeedCard(title: "厨房里的治愈时光", caption: "今天也要好好吃饭", duration: "12:18", symbol: "fork.knife.circle.fill", colors: [Color(red: 0.97, green: 0.61, blue: 0.35), Color(red: 0.86, green: 0.29, blue: 0.30)]),
        CompatibilityFeedCard(title: "一场关于光影的练习", caption: "把日常拍成电影", duration: "05:36", symbol: "camera.fill", colors: [Color(red: 0.24, green: 0.23, blue: 0.42), Color(red: 0.67, green: 0.46, blue: 0.69)]),
        CompatibilityFeedCard(title: "周末书单分享", caption: "留给自己的安静片刻", duration: "10:02", symbol: "book.closed.fill", colors: [Color(red: 0.31, green: 0.54, blue: 0.42), Color(red: 0.88, green: 0.81, blue: 0.45)])
    ]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                CompatibilityPageHeader(title: "首页", subtitle: "为你准备的原生内容")

                TabView {
                    ForEach(highlights) { item in
                        CompatibilityHighlightCard(item: item)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 196)

                HStack(alignment: .firstTextBaseline) {
                    Text("热门推荐")
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    Text("换一换")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(CompatibilityPalette.pink)
                }

                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(cards) { card in
                        CompatibilityFeedCardView(card: card)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
        }
    }
}

private struct CompatibilitySearchView: View {
    @State private var keyword = ""
    @State private var submittedKeyword = ""

    private let hotWords = ["城市漫游", "音乐现场", "美食记录", "摄影", "阅读"]
    private let suggestions = [
        CompatibilitySearchSuggestion(title: "原生界面体验", subtitle: "更贴近应用的浏览与搜索体验", symbol: "rectangle.3.group.fill"),
        CompatibilitySearchSuggestion(title: "本地内容保存", subtitle: "支持系统照片图库授权与写入", symbol: "photo.on.rectangle.angled"),
        CompatibilitySearchSuggestion(title: "收藏你的灵感", subtitle: "在“我的”页面管理个人偏好", symbol: "heart.fill")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                CompatibilityPageHeader(title: "搜索", subtitle: "搜索你感兴趣的内容")

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("视频、用户、话题", text: $keyword, onCommit: submit)
                        .textFieldStyle(PlainTextFieldStyle())
                    if !keyword.isEmpty {
                        Button {
                            keyword = ""
                            submittedKeyword = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Button("搜索", action: submit)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(CompatibilityPalette.pink)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: Capsule())

                if submittedKeyword.isEmpty {
                    Text("热门搜索")
                        .font(.system(size: 20, weight: .bold))

                    CompatibilityFlowLayout(items: hotWords) { word in
                        Button(word) {
                            keyword = word
                            submit()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(CompatibilityPalette.pink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(CompatibilityPalette.pink.opacity(0.10), in: Capsule())
                        .buttonStyle(PlainButtonStyle())
                    }

                    Text("推荐功能")
                        .font(.system(size: 20, weight: .bold))
                        .padding(.top, 2)

                    VStack(spacing: 10) {
                        ForEach(suggestions) { suggestion in
                            CompatibilitySuggestionRow(suggestion: suggestion)
                        }
                    }
                } else {
                    Text("“\(submittedKeyword)” 的搜索结果")
                        .font(.system(size: 20, weight: .bold))

                    ForEach(searchResults, id: \.self) { result in
                        CompatibilityResultRow(title: result, keyword: submittedKeyword)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
        }
    }

    private var searchResults: [String] {
        [
            "与 \(submittedKeyword) 有关的精选内容",
            "\(submittedKeyword) 创作灵感与经验分享",
            "正在讨论 \(submittedKeyword) 的用户动态"
        ]
    }

    private func submit() {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        submittedKeyword = trimmed
    }
}

private struct CompatibilityMineView: View {
    @State private var saveStatus = "尚未选择图片"
    @State private var showsPhotoPicker = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                CompatibilityPageHeader(title: "我的", subtitle: "管理账户与本地偏好")

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(CompatibilityPalette.pink.opacity(0.16))
                            .frame(width: 64, height: 64)
                        Image(systemName: "person.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(CompatibilityPalette.pink)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("欢迎使用 cilicili")
                            .font(.system(size: 19, weight: .bold))
                        Text("原生 iOS 15 兼容界面")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Text("本地功能")
                    .font(.system(size: 20, weight: .bold))
                    .padding(.top, 2)

                Button {
                    showsPhotoPicker = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundColor(CompatibilityPalette.pink)
                            .frame(width: 34)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("保存图片到系统相册")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(saveStatus)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(CompatibilityPressStyle())

                Text("偏好设置")
                    .font(.system(size: 20, weight: .bold))
                    .padding(.top, 2)

                VStack(spacing: 1) {
                    CompatibilitySettingRow(icon: "bell.fill", title: "通知与提醒", detail: "系统设置")
                    CompatibilitySettingRow(icon: "paintbrush.fill", title: "界面外观", detail: "跟随系统")
                    CompatibilitySettingRow(icon: "lock.shield.fill", title: "隐私与安全", detail: "本地管理")
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
        }
        .sheet(isPresented: $showsPhotoPicker) {
            CompatibilityPhotoPicker { image in
                CompatibilityPhotoSaver.save(image) { result in
                    switch result {
                    case .success:
                        saveStatus = "图片已保存到系统相册"
                    case .failure(let error):
                        saveStatus = "保存失败：\(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

private struct CompatibilityPageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 31, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

private struct CompatibilityHighlight: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let colors: [Color]
}

private struct CompatibilityHighlightCard: View {
    let item: CompatibilityHighlight

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing))

            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 148, height: 148)
                .offset(x: 170, y: -70)

            Image(systemName: item.symbol)
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.white.opacity(0.88))
                .offset(x: 218, y: -43)

            VStack(alignment: .leading, spacing: 7) {
                Text(item.title)
                    .font(.system(size: 25, weight: .bold))
                Text(item.subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.86))
            }
            .foregroundColor(.white)
            .padding(22)
        }
        .padding(.horizontal, 2)
    }
}

private struct CompatibilityFeedCard: Identifiable {
    let id = UUID()
    let title: String
    let caption: String
    let duration: String
    let symbol: String
    let colors: [Color]
}

private struct CompatibilityFeedCardView: View {
    let card: CompatibilityFeedCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: card.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 118)

                Image(systemName: card.symbol)
                    .font(.system(size: 43, weight: .bold))
                    .foregroundColor(.white.opacity(0.84))

                Text(card.duration)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.46), in: Capsule())
                    .padding(9)
            }

            Text(card.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)

            Text(card.caption)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

private struct CompatibilitySearchSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
}

private struct CompatibilitySuggestionRow: View {
    let suggestion: CompatibilitySearchSuggestion

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: suggestion.symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(CompatibilityPalette.pink)
                .frame(width: 34, height: 34)
                .background(CompatibilityPalette.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(suggestion.title)
                    .font(.system(size: 16, weight: .semibold))
                Text(suggestion.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CompatibilityResultRow: View {
    let title: String
    let keyword: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 24))
                .foregroundColor(CompatibilityPalette.pink)
                .frame(width: 38, height: 38)
                .background(CompatibilityPalette.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                Text("原生搜索结果 · \(keyword)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CompatibilitySettingRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(CompatibilityPalette.pink)
                .frame(width: 34, height: 34)
                .background(CompatibilityPalette.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(.system(size: 16, weight: .medium))
            Spacer()
            Text(detail)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
}

private struct CompatibilityFlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                ForEach(Array(items.prefix(3)), id: \.self) { item in
                    content(item)
                }
            }
            HStack(spacing: 9) {
                ForEach(Array(items.dropFirst(3)), id: \.self) { item in
                    content(item)
                }
            }
        }
    }
}

private struct CompatibilityPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private enum CompatibilityPalette {
    static let pink = Color(red: 0.89, green: 0.25, blue: 0.51)
}

private struct CompatibilityPhotoPicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected, dismiss: { presentationMode.wrappedValue.dismiss() })
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onImageSelected: (UIImage) -> Void
        private let dismiss: () -> Void

        init(onImageSelected: @escaping (UIImage) -> Void, dismiss: @escaping () -> Void) {
            self.onImageSelected = onImageSelected
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(
            _: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImageSelected(image)
            }
            dismiss()
        }
    }
}

private enum CompatibilityPhotoSaver {
    static func save(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            write(image, completion: completion)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    guard status == .authorized || status == .limited else {
                        completion(.failure(CompatibilityPhotoSaveError.permissionDenied))
                        return
                    }
                    write(image, completion: completion)
                }
            }
        case .denied, .restricted:
            completion(.failure(CompatibilityPhotoSaveError.permissionDenied))
        @unknown default:
            completion(.failure(CompatibilityPhotoSaveError.permissionDenied))
        }
    }

    private static func write(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(error ?? CompatibilityPhotoSaveError.writeFailed))
                }
            }
        }
    }
}

private enum CompatibilityPhotoSaveError: LocalizedError {
    case permissionDenied
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "未获得写入系统相册的权限"
        case .writeFailed:
            return "系统相册未完成图片写入"
        }
    }
}
