import Photos
import SwiftUI
import UIKit
import WebKit

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
            return "house"
        case .mine:
            return "person.crop.circle"
        case .search:
            return "magnifyingglass"
        }
    }
}

private struct CompatibilityRootView: View {
    @AppStorage("cc.bili.compat.selectedRootTab.v1") private var selectedTab = CompatibilityTab.home.rawValue

    var body: some View {
        TabView(selection: $selectedTab) {
            CompatibilityHomeView()
                .tabItem {
                    Label(CompatibilityTab.home.title, systemImage: CompatibilityTab.home.systemImage)
                }
                .tag(CompatibilityTab.home.rawValue)

            CompatibilityMineView()
                .tabItem {
                    Label(CompatibilityTab.mine.title, systemImage: CompatibilityTab.mine.systemImage)
                }
                .tag(CompatibilityTab.mine.rawValue)

            CompatibilitySearchView()
                .tabItem {
                    Label(CompatibilityTab.search.title, systemImage: CompatibilityTab.search.systemImage)
                }
                .tag(CompatibilityTab.search.rawValue)
        }
        .accentColor(Color(red: 0.89, green: 0.25, blue: 0.51))
        .onAppear {
            selectedTab = normalizedTab(selectedTab)
        }
        .onChange(of: selectedTab) { value in
            selectedTab = normalizedTab(value)
        }
    }

    private func normalizedTab(_ value: String) -> String {
        CompatibilityTab(rawValue: value)?.rawValue ?? CompatibilityTab.home.rawValue
    }
}

private struct CompatibilityHomeView: View {
    var body: some View {
        CompatibilityBrowserContainer(
            title: CompatibilityTab.home.title,
            url: URL(string: "https://www.bilibili.com")!
        )
    }
}

private struct CompatibilitySearchView: View {
    @State private var keyword = ""
    @State private var searchURL = URL(string: "https://search.bilibili.com")!

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("搜索视频、用户或话题", text: $keyword, onCommit: submit)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityLabel("搜索关键词")
                Button("搜索", action: submit)
                    .buttonStyle(BorderlessButtonStyle())
                    .accessibilityLabel("开始搜索")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            CompatibilityWebView(url: searchURL)
        }
        .navigationBarTitle(CompatibilityTab.search.title, displayMode: .inline)
    }

    private func submit() {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var components = URLComponents(string: "https://search.bilibili.com/all")
        components?.queryItems = [URLQueryItem(name: "keyword", value: trimmed)]
        if let url = components?.url {
            searchURL = url
        }
    }
}

private struct CompatibilityMineView: View {
    @State private var saveStatus = "尚未选择图片"
    @State private var showsPhotoPicker = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("账户")) {
                    Link("打开网页账户中心", destination: URL(string: "https://space.bilibili.com")!)
                    Link("打开网页登录", destination: URL(string: "https://passport.bilibili.com/login")!)
                }

                Section(header: Text("保存")) {
                    Button("从系统相册选择图片并保存") {
                        showsPhotoPicker = true
                    }
                    Text(saveStatus)
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }

                Section(header: Text("兼容性说明")) {
                    Text("本版本为 iOS 15 兼容界面，保留首页、我的、搜索三个底部入口，并使用系统组件维持稳定导航与保存体验。")
                        .font(.footnote)
                }
            }
            .navigationBarTitle(CompatibilityTab.mine.title, displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
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

private struct CompatibilityBrowserContainer: View {
    let title: String
    let url: URL

    var body: some View {
        NavigationView {
            CompatibilityWebView(url: url)
                .navigationBarTitle(title, displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct CompatibilityWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context _: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context _: Context) {
        guard webView.url?.absoluteString != url.absoluteString else { return }
        webView.load(URLRequest(url: url))
    }
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
