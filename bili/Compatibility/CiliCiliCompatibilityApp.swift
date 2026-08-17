import AVFoundation
import AVKit
import Combine
import CoreImage
import Foundation
import Photos
import Security
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
    @StateObject private var authStore = NativeAuthStore()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            activeScreen
                .environmentObject(authStore)
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
    @StateObject private var feedStore = NativeFeedStore()
    @State private var selectedVideo: NativeVideo?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                CompatibilityPageHeader(title: "首页", subtitle: "原生推荐与视频播放")

                NativeFeatureBanner(
                    title: "发现精彩视频",
                    subtitle: feedStore.statusText,
                    symbol: "play.rectangle.fill"
                )

                HStack(alignment: .firstTextBaseline) {
                    Text("热门推荐")
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    Button("换一换") { feedStore.reload() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(CompatibilityPalette.pink)
                        .buttonStyle(PlainButtonStyle())
                }

                if feedStore.isLoading && feedStore.videos.isEmpty {
                    NativeLoadingPanel(text: "正在加载推荐视频")
                } else if let message = feedStore.errorMessage, feedStore.videos.isEmpty {
                    NativeErrorPanel(message: message, retry: feedStore.reload)
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(feedStore.videos) { video in
                            Button { selectedVideo = video } label: {
                                NativeVideoCard(video: video)
                            }
                            .buttonStyle(CompatibilityPressStyle())
                            .accessibilityLabel("播放 \(video.title)")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
        }
        .onAppear { feedStore.loadIfNeeded() }
        .sheet(item: $selectedVideo) { video in
            NativePlayerView(video: video)
        }
    }
}

private struct CompatibilitySearchView: View {
    @State private var keyword = ""
    @StateObject private var searchStore = NativeSearchStore()
    @State private var selectedVideo: NativeVideo?

    private let hotWords = ["动画", "音乐", "游戏", "科技", "知识"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                CompatibilityPageHeader(title: "搜索", subtitle: "搜索视频、用户与话题")

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("视频、用户、话题", text: $keyword, onCommit: submit)
                        .textFieldStyle(PlainTextFieldStyle())
                    if !keyword.isEmpty {
                        Button { keyword = "" } label: {
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

                if searchStore.query.isEmpty {
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
                } else {
                    Text("“\(searchStore.query)” 的搜索结果")
                        .font(.system(size: 20, weight: .bold))
                    if searchStore.isLoading {
                        NativeLoadingPanel(text: "正在搜索")
                    } else if let message = searchStore.errorMessage {
                        NativeErrorPanel(message: message, retry: submit)
                    } else if searchStore.results.isEmpty {
                        NativeEmptyPanel(text: "没有找到可播放的视频")
                    } else {
                        ForEach(searchStore.results) { video in
                            Button { selectedVideo = video } label: {
                                NativeSearchVideoRow(video: video)
                            }
                            .buttonStyle(CompatibilityPressStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
        }
        .sheet(item: $selectedVideo) { video in
            NativePlayerView(video: video)
        }
    }

    private func submit() {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchStore.search(trimmed)
    }
}

private struct CompatibilityMineView: View {
    @EnvironmentObject private var authStore: NativeAuthStore
    @State private var saveStatus = "尚未选择图片"
    @State private var showsPhotoPicker = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                CompatibilityPageHeader(title: "我的", subtitle: "账号、播放与本地保存")

                NativeAccountCard(authStore: authStore)

                Text("账号")
                    .font(.system(size: 20, weight: .bold))
                Button {
                    authStore.showsLogin = true
                } label: {
                    CompatibilitySettingRow(
                        icon: authStore.isLoggedIn ? "checkmark.seal.fill" : "qrcode",
                        title: authStore.isLoggedIn ? "已登录：\(authStore.displayName)" : "扫码登录账号",
                        detail: authStore.isLoggedIn ? "管理登录状态" : "安全二维码登录"
                    )
                }
                .buttonStyle(CompatibilityPressStyle())

                Text("保存")
                    .font(.system(size: 20, weight: .bold))
                Button {
                    showsPhotoPicker = true
                } label: {
                    CompatibilitySettingRow(
                        icon: "photo.fill",
                        title: "保存图片到系统相册",
                        detail: saveStatus
                    )
                }
                .buttonStyle(CompatibilityPressStyle())

                Text("偏好设置")
                    .font(.system(size: 20, weight: .bold))
                VStack(spacing: 1) {
                    CompatibilitySettingRow(icon: "play.rectangle.fill", title: "视频播放", detail: "原生 AVPlayer")
                    CompatibilitySettingRow(icon: "camera.viewfinder", title: "视频画面", detail: "可保存单帧")
                    CompatibilitySettingRow(icon: "lock.shield.fill", title: "凭据存储", detail: "系统钥匙串")
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
        .sheet(isPresented: $authStore.showsLogin) {
            NativeLoginView(authStore: authStore)
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


// MARK: - Native video, search and account services

private struct NativeVideo: Identifiable, Hashable {
    let bvid: String
    let title: String
    let author: String
    let coverURL: URL?
    let durationText: String
    let description: String

    var id: String { bvid }
}

private enum NativeMediaError: LocalizedError {
    case invalidResponse
    case missingVideoID
    case unavailablePlayback
    case service(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务返回的数据格式无法识别"
        case .missingVideoID:
            return "该视频缺少可播放的标识"
        case .unavailablePlayback:
            return "当前视频暂时没有可用的播放地址，可能需要登录或不支持当前清晰度"
        case let .service(code, message):
            return "服务请求失败（\(code)）：\(message)"
        }
    }
}

private struct NativeBiliResponse<Payload: Decodable>: Decodable {
    let code: Int
    let message: String?
    let data: Payload?
}

private struct NativePopularPayload: Decodable {
    let list: [NativeVideoDTO]?
}

private struct NativeSearchPayload: Decodable {
    let result: [NativeSearchSection]?
}

private struct NativeSearchSection: Decodable {
    let resultType: String?
    let data: [NativeVideoDTO]?

    enum CodingKeys: String, CodingKey {
        case resultType = "result_type"
        case data
    }
}

private struct NativeVideoDTO: Decodable {
    let bvid: String?
    let title: String?
    let pic: String?
    let author: String?
    let ownerName: String?
    let description: String?
    let durationText: String?

    enum CodingKeys: String, CodingKey {
        case bvid, title, pic, author, owner, desc, duration, durationText = "duration_text"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bvid = container.nativeString(forKey: .bvid)
        title = container.nativeString(forKey: .title)
        pic = container.nativeString(forKey: .pic)
        author = container.nativeString(forKey: .author)
        description = container.nativeString(forKey: .desc)
        durationText = container.nativeString(forKey: .durationText) ?? container.nativeString(forKey: .duration)
        if let owner = try? container.decode(NativeOwner.self, forKey: .owner) {
            ownerName = owner.name
        } else {
            ownerName = nil
        }
    }

    func asNativeVideo() -> NativeVideo? {
        guard let bvid, !bvid.isEmpty else { return nil }
        let normalizedCover = NativeURL.httpsURL(from: pic)
        return NativeVideo(
            bvid: bvid,
            title: NativeText.clean(title ?? "未命名视频"),
            author: ownerName ?? author ?? "哔哩哔哩用户",
            coverURL: normalizedCover,
            durationText: durationText ?? "视频",
            description: NativeText.clean(description ?? "")
        )
    }
}

private struct NativeOwner: Decodable {
    let name: String?
}

private struct NativeViewPayload: Decodable {
    let cid: Int?
    let title: String?
    let pic: String?
    let owner: NativeOwner?
    let desc: String?
    let duration: Int?
}

private struct NativePlayPayload: Decodable {
    let durl: [NativePlaySegment]?
}

private struct NativePlaySegment: Decodable {
    let url: String?
}

private struct NativeQRGeneratePayload: Decodable {
    let url: String?
    let qrcodeKey: String?

    enum CodingKeys: String, CodingKey {
        case url
        case qrcodeKey = "qrcode_key"
    }
}

private struct NativeQRPollPayload: Decodable {
    let code: Int?
    let message: String?
    let url: String?
}

private struct NativeNavPayload: Decodable {
    let isLogin: Bool?
    let uname: String?
    let face: String?
}

private extension KeyedDecodingContainer {
    func nativeString(forKey key: Key) -> String? {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        return nil
    }
}

private enum NativeText {
    static func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum NativeURL {
    static func httpsURL(from rawValue: String?) -> URL? {
        guard var rawValue, !rawValue.isEmpty else { return nil }
        if rawValue.hasPrefix("//") {
            rawValue = "https:\(rawValue)"
        }
        guard var components = URLComponents(string: rawValue) else { return nil }
        if components.scheme?.lowercased() == "http" {
            components.scheme = "https"
        }
        return components.url
    }
}

private enum NativeCredentialVault {
    private static let service = "cc.bili.compat.native"
    private static let account = "bilibili.cookie.header"

    static func cookieHeader() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    static func save(cookieHeader: String) throws {
        let data = Data(cookieHeader.utf8)
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        var insert = baseQuery
        insert[kSecValueData] = data
        insert[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let insertStatus = SecItemAdd(insert as CFDictionary, nil)
        guard insertStatus == errSecSuccess else {
            throw NSError(domain: "NativeCredentialVault", code: Int(insertStatus), userInfo: [NSLocalizedDescriptionKey: "无法写入系统钥匙串"])
        }
    }

    static func clear() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private enum NativeBiliAPI {
    private static let apiBase = URL(string: "https://api.bilibili.com")!
    private static let passportBase = URL(string: "https://passport.bilibili.com")!
    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 Version/15.0 Mobile/15E148 Safari/604.1"

    static func popularVideos() async throws -> [NativeVideo] {
        let payload: NativePopularPayload = try await request(
            base: apiBase,
            path: "/x/web-interface/popular",
            query: ["pn": "1", "ps": "20"]
        )
        return (payload.list ?? []).compactMap { $0.asNativeVideo() }
    }

    static func searchVideos(keyword: String) async throws -> [NativeVideo] {
        let payload: NativeSearchPayload = try await request(
            base: apiBase,
            path: "/x/web-interface/search/all/v2",
            query: ["keyword": keyword]
        )
        let section = payload.result?.first(where: { $0.resultType == "video" })
        return (section?.data ?? []).compactMap { $0.asNativeVideo() }
    }

    static func playbackURL(for video: NativeVideo) async throws -> URL {
        let detail: NativeViewPayload = try await request(
            base: apiBase,
            path: "/x/web-interface/view",
            query: ["bvid": video.bvid]
        )
        guard let cid = detail.cid else { throw NativeMediaError.missingVideoID }
        let payload: NativePlayPayload = try await request(
            base: apiBase,
            path: "/x/player/playurl",
            query: ["bvid": video.bvid, "cid": String(cid), "qn": "32", "fnval": "0", "fourk": "1"],
            referer: "https://www.bilibili.com/video/\(video.bvid)"
        )
        guard let rawURL = payload.durl?.first?.url,
              let url = URL(string: rawURL)
        else { throw NativeMediaError.unavailablePlayback }
        return url
    }

    static func generateQRCode() async throws -> NativeQRGeneratePayload {
        try await request(
            base: passportBase,
            path: "/x/passport-login/web/qrcode/generate",
            query: [:],
            referer: "https://passport.bilibili.com/login"
        )
    }

    static func pollQRCode(key: String) async throws -> NativeQRPollPayload {
        try await request(
            base: passportBase,
            path: "/x/passport-login/web/qrcode/poll",
            query: ["qrcode_key": key],
            referer: "https://passport.bilibili.com/login"
        )
    }

    static func currentUser() async throws -> NativeNavPayload {
        try await request(base: apiBase, path: "/x/web-interface/nav", query: [:])
    }

    static func clearCookies() {
        let hosts = ["https://api.bilibili.com", "https://passport.bilibili.com", "https://www.bilibili.com"]
        for host in hosts {
            guard let url = URL(string: host) else { continue }
            for cookie in HTTPCookieStorage.shared.cookies(for: url) ?? [] {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }

    private static func request<Payload: Decodable>(
        base: URL,
        path: String,
        query: [String: String],
        referer: String? = nil
    ) async throws -> Payload {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else { throw NativeMediaError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(referer ?? "https://www.bilibili.com", forHTTPHeaderField: "Referer")
        if let cookie = NativeCredentialVault.cookieHeader(), !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200 ..< 300 ~= http.statusCode else {
            throw NativeMediaError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(NativeBiliResponse<Payload>.self, from: data)
        guard decoded.code == 0 else {
            throw NativeMediaError.service(code: decoded.code, message: decoded.message ?? "未知错误")
        }
        guard let payload = decoded.data else { throw NativeMediaError.invalidResponse }
        return payload
    }

    static func persistCookiesFromSharedStorage() throws {
        let urls = [URL(string: "https://api.bilibili.com")!, URL(string: "https://passport.bilibili.com")!]
        var values: [String: String] = [:]
        for url in urls {
            for cookie in HTTPCookieStorage.shared.cookies(for: url) ?? [] {
                values[cookie.name] = cookie.value
            }
        }
        let header = values.keys.sorted().map { "\($0)=\(values[$0] ?? "")" }.joined(separator: "; ")
        guard !header.isEmpty else {
            throw NativeMediaError.service(code: -1, message: "登录已确认，但尚未获取到可保存的会话信息")
        }
        try NativeCredentialVault.save(cookieHeader: header)
    }
}

@MainActor
private final class NativeFeedStore: ObservableObject {
    @Published private(set) var videos: [NativeVideo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var statusText: String {
        if isLoading { return "正在加载推荐内容" }
        if let errorMessage { return errorMessage }
        return videos.isEmpty ? "点击换一换获取推荐" : "已加载 \(videos.count) 个可打开的视频"
    }

    func loadIfNeeded() {
        guard videos.isEmpty else { return }
        reload()
    }

    func reload() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                videos = try await NativeBiliAPI.popularVideos()
                if videos.isEmpty { errorMessage = "当前没有可显示的推荐视频" }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

@MainActor
private final class NativeSearchStore: ObservableObject {
    @Published private(set) var query = ""
    @Published private(set) var results: [NativeVideo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func search(_ keyword: String) {
        guard !keyword.isEmpty else { return }
        query = keyword
        isLoading = true
        errorMessage = nil
        results = []
        Task {
            do {
                results = try await NativeBiliAPI.searchVideos(keyword: keyword)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

@MainActor
private final class NativeAuthStore: ObservableObject {
    @Published var showsLogin = false
    @Published private(set) var isLoggedIn = false
    @Published private(set) var displayName = "未登录"
    @Published private(set) var faceURL: URL?
    @Published private(set) var qrURL = ""
    @Published private(set) var qrState = "准备生成二维码"
    @Published private(set) var errorMessage: String?

    private var pollingTask: Task<Void, Never>?
    private var qrKey = ""

    init() {
        Task { await refreshAccount() }
    }

    func prepareLogin() {
        pollingTask?.cancel()
        qrState = "正在生成二维码"
        errorMessage = nil
        qrURL = ""
        Task {
            do {
                let info = try await NativeBiliAPI.generateQRCode()
                guard let url = info.url, let key = info.qrcodeKey else {
                    throw NativeMediaError.invalidResponse
                }
                qrURL = url
                qrKey = key
                qrState = "请使用哔哩哔哩扫描二维码"
                startPolling()
            } catch {
                errorMessage = error.localizedDescription
                qrState = "二维码生成失败"
            }
        }
    }

    func cancelLogin() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func logout() {
        cancelLogin()
        NativeCredentialVault.clear()
        NativeBiliAPI.clearCookies()
        isLoggedIn = false
        displayName = "未登录"
        faceURL = nil
    }

    func refreshAccount() async {
        do {
            let account = try await NativeBiliAPI.currentUser()
            isLoggedIn = account.isLogin == true
            displayName = account.uname ?? (isLoggedIn ? "已登录用户" : "未登录")
            faceURL = URL(string: account.face ?? "")
        } catch {
            isLoggedIn = false
            displayName = "未登录"
            faceURL = nil
        }
    }

    private func startPolling() {
        let key = qrKey
        pollingTask = Task {
            for _ in 0 ..< 90 where !Task.isCancelled {
                do {
                    let result = try await NativeBiliAPI.pollQRCode(key: key)
                    switch result.code {
                    case 0:
                        try NativeBiliAPI.persistCookiesFromSharedStorage()
                        qrState = "登录已确认"
                        await refreshAccount()
                        showsLogin = false
                        pollingTask = nil
                        return
                    case 860:
                        qrState = "已扫码，请在账号中确认"
                    case 861:
                        qrState = "请使用哔哩哔哩扫描二维码"
                    case 862:
                        qrState = "二维码已过期，请刷新"
                        pollingTask = nil
                        return
                    default:
                        qrState = result.message ?? "正在等待扫码"
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    pollingTask = nil
                    return
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            if !Task.isCancelled { qrState = "二维码已过期，请刷新" }
        }
    }
}

@MainActor
private final class NativePlayerController: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var isLoading = true
    @Published private(set) var isReadyToPlay = false
    @Published private(set) var errorMessage: String?

    private let video: NativeVideo
    private var statusObservation: NSKeyValueObservation?
    private var failureObserver: NSObjectProtocol?

    init(video: NativeVideo) {
        self.video = video
    }

    func prepare() {
        cleanupObservers()
        player.pause()
        player.replaceCurrentItem(with: nil)
        isLoading = true
        isReadyToPlay = false
        errorMessage = nil
        Task {
            do {
                let url = try await NativeBiliAPI.playbackURL(for: video)
                let item = AVPlayerItem(url: url)
                observePlaybackState(of: item)
                player.replaceCurrentItem(with: item)
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func stop() {
        cleanupObservers()
        player.pause()
        player.replaceCurrentItem(with: nil)
        isReadyToPlay = false
    }

    func captureCurrentFrame(completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard isReadyToPlay, let asset = player.currentItem?.asset else {
            completion(.failure(NativeMediaError.unavailablePlayback))
            return
        }
        let time = player.currentTime()
        DispatchQueue.global(qos: .userInitiated).async {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            do {
                let image = try generator.copyCGImage(at: time, actualTime: nil)
                DispatchQueue.main.async { completion(.success(UIImage(cgImage: image))) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func observePlaybackState(of item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            let status = observedItem.status
            let itemError = observedItem.error
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.isLoading = false
                    self.isReadyToPlay = true
                    self.player.play()
                case .failed:
                    self.isLoading = false
                    self.isReadyToPlay = false
                    self.errorMessage = itemError?.localizedDescription ?? NativeMediaError.unavailablePlayback.localizedDescription
                case .unknown:
                    break
                @unknown default:
                    self.isLoading = false
                }
            }
        }
        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let failure = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = false
                self.isReadyToPlay = false
                self.errorMessage = failure?.localizedDescription ?? NativeMediaError.unavailablePlayback.localizedDescription
            }
        }
    }

    private func cleanupObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
        failureObserver = nil
    }
}

private enum NativeExternalPlayer {
    static func open(_ video: NativeVideo) {
        guard let webURL = URL(string: "https://www.bilibili.com/video/\(video.bvid)") else { return }
        let appURL = URL(string: "bilibili://video/\(video.bvid)")!
        UIApplication.shared.open(appURL, options: [:]) { opened in
            if !opened {
                UIApplication.shared.open(webURL, options: [:])
            }
        }
    }
}

private enum NativeOfficialLogin {
    static func open() {
        guard let url = URL(string: "https://passport.bilibili.com/login") else { return }
        UIApplication.shared.open(url, options: [:])
    }
}

// MARK: - Native feature views

private struct NativeFeatureBanner: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [CompatibilityPalette.pink, Color(red: 0.32, green: 0.27, blue: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 155, height: 155)
                .offset(x: 190, y: -68)
            Image(systemName: symbol)
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .offset(x: 215, y: -40)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 25, weight: .bold))
                Text(subtitle).font(.system(size: 14, weight: .medium)).lineLimit(2)
            }
            .foregroundColor(.white)
            .padding(22)
        }
        .frame(height: 174)
    }
}

private struct NativeVideoCard: View {
    let video: NativeVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                NativeCoverImage(url: video.coverURL)
                    .frame(height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                LinearGradient(colors: [Color.clear, Color.black.opacity(0.34)], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Image(systemName: "play.fill")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.white.opacity(0.94))
                    .shadow(color: .black.opacity(0.34), radius: 4, y: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(video.durationText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.65), in: Capsule())
                    .padding(9)
            }
            Text(video.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
            Text(video.author)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

private struct NativeSearchVideoRow: View {
    let video: NativeVideo

    var body: some View {
        HStack(spacing: 12) {
            NativeCoverImage(url: video.coverURL)
                .frame(width: 122, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(video.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(video.author)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                if !video.description.isEmpty {
                    Text(video.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct NativeCoverImage: View {
    let url: URL?

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                case .empty:
                    Color(UIColor.tertiarySystemFill)
                        .overlay(ProgressView().tint(CompatibilityPalette.pink))
                case .failure:
                    Color(UIColor.tertiarySystemFill)
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: "photo")
                                    .font(.system(size: 21, weight: .semibold))
                                Text("封面加载失败")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        )
                @unknown default:
                    Color(UIColor.tertiarySystemFill)
                }
            }
        }
        .clipped()
    }
}

private struct NativeLoadingPanel: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(text).font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
            Spacer()
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct NativeEmptyPanel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 116)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct NativeErrorPanel: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("内容加载失败").font(.system(size: 16, weight: .bold))
            Text(message).font(.system(size: 13)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("重试", action: retry)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(CompatibilityPalette.pink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct NativeAccountCard: View {
    @ObservedObject var authStore: NativeAuthStore

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(CompatibilityPalette.pink.opacity(0.16)).frame(width: 64, height: 64)
                if let url = authStore.faceURL {
                    AsyncImage(url: url) { phase in
                        if case let .success(image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(CompatibilityPalette.pink)
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(CompatibilityPalette.pink)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(authStore.isLoggedIn ? authStore.displayName : "欢迎使用 cilicili")
                    .font(.system(size: 19, weight: .bold))
                Text(authStore.isLoggedIn ? "账号状态已保存到本机钥匙串" : "登录后可使用账号相关内容")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct NativeLoginView: View {
    @ObservedObject var authStore: NativeAuthStore
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("扫码登录")
                    .font(.system(size: 25, weight: .bold))
                Text("请使用哔哩哔哩客户端扫描二维码并确认。登录凭据只保存在此设备的系统钥匙串中。")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                if let image = NativeQRCodeRenderer.image(from: authStore.qrURL) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 214, height: 214)
                        .padding(12)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.black.opacity(0.08), radius: 9, y: 4)
                } else {
                    ProgressView().frame(width: 214, height: 214)
                }
                Text(authStore.qrState)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                if let error = authStore.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                Button("刷新二维码") { authStore.prepareLogin() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(CompatibilityPalette.pink, in: Capsule())
                VStack(spacing: 10) {
                    Text("也可在官方页面登录")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            NativeOfficialLogin.open()
                        } label: {
                            Label("手机号验证码登录", systemImage: "number")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        Button {
                            NativeOfficialLogin.open()
                        } label: {
                            Label("账号密码登录", systemImage: "lock.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }
                    .foregroundColor(CompatibilityPalette.pink)
                    Text("手机号、验证码和密码仅在官方页面中输入，本应用不会读取或保存。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                if authStore.isLoggedIn {
                    Button("退出当前账号") { authStore.logout() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                }
                Spacer()
            }
            .padding(.top, 32)
            .navigationBarItems(trailing: Button("完成") {
                authStore.cancelLogin()
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear { authStore.prepareLogin() }
        .onDisappear { authStore.cancelLogin() }
    }
}

private enum NativeQRCodeRenderer {
    static func image(from value: String) -> UIImage? {
        guard !value.isEmpty,
              let filter = CIFilter(name: "CIQRCodeGenerator")
        else { return nil }
        filter.setValue(Data(value.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private struct NativePlayerView: View {
    let video: NativeVideo
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var controller: NativePlayerController
    @State private var saveStatus = "内嵌播放成功后可保存当前画面"

    init(video: NativeVideo) {
        self.video = video
        _controller = StateObject(wrappedValue: NativePlayerController(video: video))
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack {
                        NativeCoverImage(url: video.coverURL)
                        Color.black.opacity(controller.isReadyToPlay ? 0 : 0.16)
                        if controller.isReadyToPlay {
                            NativeAVPlayerView(player: controller.player)
                        }
                        if controller.isLoading {
                            ProgressView("正在验证播放地址")
                                .tint(.white)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.46), in: Capsule())
                        } else if !controller.isReadyToPlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundColor(.white.opacity(0.92))
                                .shadow(color: .black.opacity(0.45), radius: 5, y: 2)
                        }
                    }
                    .frame(height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text(video.title)
                        .font(.system(size: 21, weight: .bold))
                    Text("UP：\(video.author) · \(video.durationText)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    if !video.description.isEmpty {
                        Text(video.description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    if let error = controller.errorMessage {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("内嵌播放不可用")
                                .font(.system(size: 16, weight: .bold))
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("重新尝试内嵌播放", action: controller.prepare)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(CompatibilityPalette.pink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    Button {
                        NativeExternalPlayer.open(video)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 22, weight: .semibold))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("使用官方播放器打开")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("优先唤起哔哩哔哩；未安装时打开官方网页")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .padding(15)
                        .background(CompatibilityPalette.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(CompatibilityPressStyle())
                    Button {
                        controller.captureCurrentFrame { result in
                            switch result {
                            case let .success(image):
                                CompatibilityPhotoSaver.save(image) { saveResult in
                                    switch saveResult {
                                    case .success:
                                        saveStatus = "当前视频画面已保存到系统相册"
                                    case let .failure(error):
                                        saveStatus = "画面保存失败：\(error.localizedDescription)"
                                    }
                                }
                            case let .failure(error):
                                saveStatus = "无法抓取当前画面：\(error.localizedDescription)"
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                            VStack(alignment: .leading, spacing: 3) {
                                Text("保存当前视频画面").font(.system(size: 16, weight: .semibold))
                                Text(saveStatus).font(.system(size: 13)).foregroundColor(.secondary).lineLimit(2)
                            }
                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .padding(15)
                        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(CompatibilityPressStyle())
                    .disabled(!controller.isReadyToPlay)
                    .opacity(controller.isReadyToPlay ? 1 : 0.58)
                }
                .padding(16)
            }
            .navigationBarTitle("视频播放", displayMode: .inline)
            .navigationBarItems(trailing: Button("完成") { presentationMode.wrappedValue.dismiss() })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear { controller.prepare() }
        .onDisappear { controller.stop() }
    }
}

private struct NativeAVPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context _: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context _: Context) {
        controller.player = player
    }
}
