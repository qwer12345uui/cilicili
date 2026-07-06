import Combine
import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UIKit

struct ZoomyFullScreenImageViewer: View {
    let initialImage: UIImage?
    let url: URL?
    let items: [ZoomyImagePreviewItem]
    let initialItemID: String
    let viewerGroup: ZoomyImagePreviewGroup?
    let targetPixelSize: Int
    let onSelectedItemChanged: (ZoomyImagePreviewItem, UIImage?) -> Void
    let onDismissDragChanged: (CGFloat) -> Void
    let onImageUpdated: (UIImage) -> Void
    @Binding var isPresented: Bool
    @State private var selectedItemID: String
    @State private var dismissDragOffset: CGFloat = 0
    @State private var dismissLockedItemID: String?
    @State private var selectedSnapshot: ZoomyViewerMediaSnapshot?
    @State private var isSavingImage = false
    @State private var sharePayload: ZoomySharePayload?
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    init(
        initialImage: UIImage?,
        url: URL?,
        items: [ZoomyImagePreviewItem],
        initialItemID: String,
        viewerGroup: ZoomyImagePreviewGroup?,
        targetPixelSize: Int,
        isPresented: Binding<Bool>,
        onSelectedItemChanged: @escaping (ZoomyImagePreviewItem, UIImage?) -> Void,
        onDismissDragChanged: @escaping (CGFloat) -> Void,
        onImageUpdated: @escaping (UIImage) -> Void
    ) {
        self.initialImage = initialImage
        self.url = url
        self.items = items
        self.initialItemID = initialItemID
        self.viewerGroup = viewerGroup
        self.targetPixelSize = targetPixelSize
        self.onSelectedItemChanged = onSelectedItemChanged
        self.onDismissDragChanged = onDismissDragChanged
        self.onImageUpdated = onImageUpdated
        _isPresented = isPresented
        _selectedItemID = State(initialValue: initialItemID)
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            ZStack {
                if let dismissLockedItemID {
                    imagePage(for: item(withID: dismissLockedItemID))
                        .ignoresSafeArea()
                } else if items.count > 1 {
                    TabView(selection: $selectedItemID) {
                        ForEach(items) { item in
                            imagePage(for: item)
                                .tag(item.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea()
                    .allowsHitTesting(dismissLockedItemID == nil)
                } else {
                    imagePage(for: items.first)
                        .ignoresSafeArea()
                }

                pageIndicator
            }
            .offset(y: dismissDragOffset)
        }
        .simultaneousGesture(dismissDragGesture)
        .onAppear {
            syncSelectedItemContext()
            prewarmNeighborImages()
        }
        .onChange(of: selectedItemID) { _, newItemID in
            if let dismissLockedItemID, newItemID != dismissLockedItemID {
                selectedItemID = dismissLockedItemID
                return
            }
            syncSelectedItemContext()
            prewarmNeighborImages()
        }
        .sheet(item: $sharePayload) { payload in
            ZoomyActivityView(activityItems: payload.activityItems)
        }
        .onDisappear {
            toastTask?.cancel()
        }
        .statusBarHidden(true)
        .accessibilityLabel("图片预览")
    }

    private var backgroundOpacity: Double {
        let progress = min(max(abs(dismissDragOffset) / 260, 0), 1)
        return 1 - progress * 0.45
    }

    @ViewBuilder
    private var pageIndicator: some View {
        VStack {
            Spacer()
            HStack(spacing: 18) {
                viewerActionButton(systemImage: "square.and.arrow.down", accessibilityLabel: "保存图片") {
                    saveCurrentImage()
                }
                .disabled(selectedSnapshot == nil || isSavingImage)

                if items.count > 1 {
                    ZoomyViewerPageControl(numberOfPages: items.count, currentPage: selectedIndex)
                        .frame(width: min(CGFloat(items.count) * 18 + 24, 180), height: 22)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                viewerActionButton(systemImage: "square.and.arrow.up", accessibilityLabel: "分享图片") {
                    shareCurrentImage()
                }
                .disabled(selectedSnapshot == nil && selectedItem.displayURL == nil)
            }
            .biliLiquidGlassForeground(shadowOpacity: 0.22)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .biliPlayerClearGlass(interactive: true, in: Capsule())
            .padding(.bottom, 22)
            .opacity(pageIndicatorOpacity)

            if let toastMessage {
                Text(toastMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(.black.opacity(0.58), in: Capsule())
                    .padding(.bottom, 10)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func viewerActionButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var pageIndicatorOpacity: Double {
        let progress = min(max(abs(dismissDragOffset) / 180, 0), 1)
        return 1 - progress
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                let verticalTravel = value.translation.height
                let horizontalTravel = abs(value.translation.width)
                guard verticalTravel > 0, verticalTravel > horizontalTravel * 1.15 else { return }
                if dismissLockedItemID == nil {
                    dismissLockedItemID = selectedItemID
                }
                dismissDragOffset = verticalTravel
                onDismissDragChanged(verticalTravel)
            }
            .onEnded { value in
                let verticalTravel = value.translation.height
                let horizontalTravel = abs(value.translation.width)
                let predictedTravel = value.predictedEndTranslation.height
                guard verticalTravel > 0, verticalTravel > horizontalTravel * 1.15 else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                        dismissDragOffset = 0
                        dismissLockedItemID = nil
                        onDismissDragChanged(0)
                    }
                    return
                }
                if verticalTravel > 120 || predictedTravel > 220 {
                    onDismissDragChanged(verticalTravel)
                    isPresented = false
                } else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                        dismissDragOffset = 0
                        dismissLockedItemID = nil
                        onDismissDragChanged(0)
                    }
                }
            }
    }

    @ViewBuilder
    private func imagePage(for item: ZoomyImagePreviewItem?) -> some View {
        if let item {
            ZoomyViewerImagePage(
                item: item,
                initialImage: initialImage(for: item),
                targetPixelSize: targetPixelSize,
                isPresented: $isPresented,
                onMediaUpdated: { itemID, snapshot in
                    if let image = snapshot.image {
                        viewerGroup?.setImage(image, for: itemID)
                    }
                    if itemID == selectedItemID {
                        updateSelectedMedia(itemID: itemID, snapshot: snapshot)
                    }
                }
            )
        } else if let url {
            ZoomyViewerImagePage(
                item: ZoomyImagePreviewItem(id: url.absoluteString, viewerURL: url),
                initialImage: initialImage,
                targetPixelSize: targetPixelSize,
                isPresented: $isPresented,
                onMediaUpdated: { _, snapshot in
                    selectedSnapshot = snapshot
                    if let image = snapshot.image {
                        onImageUpdated(image)
                    }
                }
            )
        } else {
            ProgressView()
                .tint(.white)
        }
    }

    private var selectedIndex: Int {
        items.firstIndex { $0.id == selectedItemID } ?? 0
    }

    private var selectedItem: ZoomyImagePreviewItem {
        let item = items.indices.contains(selectedIndex) ? items[selectedIndex] : items.first
        return item ?? ZoomyImagePreviewItem(
            id: url?.absoluteString ?? initialItemID,
            viewerURL: url
        )
    }

    private func item(withID id: String) -> ZoomyImagePreviewItem? {
        items.first { $0.id == id }
    }

    private func initialImage(for item: ZoomyImagePreviewItem) -> UIImage? {
        if item.id == initialItemID {
            return initialImage ?? viewerGroup?.image(for: item.id)
        }
        return viewerGroup?.image(for: item.id)
    }

    private func syncSelectedItemContext() {
        guard let item = items.first(where: { $0.id == selectedItemID }) else { return }
        let cachedImage = viewerGroup?.image(for: item.id)
        onSelectedItemChanged(item, cachedImage)
        selectedSnapshot = item.needsOriginalMedia ? nil : cachedImage.map { ZoomyViewerMediaSnapshot(image: $0) }
        if let cachedImage {
            onImageUpdated(cachedImage)
        }
    }

    private func prewarmNeighborImages() {
        guard items.count > 1 else { return }
        let neighborIndices = [selectedIndex - 1, selectedIndex + 1]
        let sources = neighborIndices.compactMap { index -> RemoteImageSource? in
            guard items.indices.contains(index),
                  let url = items[index].displayURL
            else { return nil }
            return RemoteImageSource(url: url)
        }
        guard !sources.isEmpty else { return }
        Task(priority: .utility) {
            await RemoteImageCache.shared.prefetch(
                sources,
                targetPixelSize: targetPixelSize,
                maximumConcurrentLoads: 2
            )
        }
    }

    func cancelLoading() {
    }

    private func updateSelectedMedia(itemID: String, snapshot: ZoomyViewerMediaSnapshot) {
        guard itemID == selectedItemID else { return }
        selectedSnapshot = snapshot
        if let image = snapshot.image {
            onImageUpdated(image)
        }
    }

    private func saveCurrentImage() {
        guard let snapshot = selectedSnapshot else {
            showToast("图片还在加载")
            return
        }
        guard !isSavingImage else { return }
        isSavingImage = true
        showToast("正在保存")
        Task { @MainActor in
            let didSave = await ZoomyPhotoLibrarySaver.save(snapshot)
            isSavingImage = false
            if didSave {
                Haptics.success()
                showToast("已保存到照片")
            } else {
                showToast("保存失败")
            }
        }
    }

    private func shareCurrentImage() {
        let items = ZoomyShareItemBuilder.activityItems(
            snapshot: selectedSnapshot,
            item: selectedItem
        )
        guard !items.isEmpty else {
            showToast("图片还在加载")
            return
        }
        Haptics.light()
        sharePayload = ZoomySharePayload(activityItems: items)
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.snappy(duration: 0.18)) {
            toastMessage = message
        }
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: 0.18)) {
                toastMessage = nil
            }
        }
    }
}

private struct ZoomyViewerImagePage: View {
    let item: ZoomyImagePreviewItem
    let initialImage: UIImage?
    let targetPixelSize: Int
    @Binding var isPresented: Bool
    let onMediaUpdated: (String, ZoomyViewerMediaSnapshot) -> Void
    @StateObject private var loader: ZoomyViewerImageLoader

    init(
        item: ZoomyImagePreviewItem,
        initialImage: UIImage?,
        targetPixelSize: Int,
        isPresented: Binding<Bool>,
        onMediaUpdated: @escaping (String, ZoomyViewerMediaSnapshot) -> Void
    ) {
        self.item = item
        self.initialImage = initialImage
        self.targetPixelSize = targetPixelSize
        _isPresented = isPresented
        self.onMediaUpdated = onMediaUpdated
        _loader = StateObject(wrappedValue: ZoomyViewerImageLoader(initialImage: initialImage))
    }

    var body: some View {
        ZStack {
            if let livePhoto = loader.snapshot?.livePhoto,
               let image = loader.snapshot?.image {
                ZoomyLivePhotoView(livePhoto: livePhoto, placeholderImage: image) {
                    isPresented = false
                }
                .ignoresSafeArea()
                .onAppear {
                    reportSnapshotIfNeeded()
                }
            } else if let image = loader.snapshot?.image {
                ZoomyZoomableImageView(image: image) {
                    isPresented = false
                }
                .ignoresSafeArea()
                .onAppear {
                    reportSnapshotIfNeeded()
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: item.displayURL?.absoluteString ?? item.id) {
            await loader.load(item: item, targetPixelSize: targetPixelSize)
        }
        .onAppear {
            reportSnapshotIfNeeded()
        }
        .onChange(of: loader.snapshotVersion) { _, _ in
            reportSnapshotIfNeeded()
        }
        .onDisappear {
            loader.cancel()
        }
    }

    private func reportSnapshotIfNeeded() {
        guard let snapshot = loader.snapshot else { return }
        if item.needsOriginalMedia, !snapshot.isFinal {
            return
        }
        onMediaUpdated(item.id, snapshot)
    }
}

@MainActor
private final class ZoomyViewerImageLoader: ObservableObject {
    @Published private(set) var snapshot: ZoomyViewerMediaSnapshot?
    @Published private(set) var snapshotVersion = 0
    private var task: Task<Void, Never>?

    init(initialImage: UIImage?) {
        snapshot = initialImage.map { ZoomyViewerMediaSnapshot(image: $0, isFinal: false) }
    }

    func load(item: ZoomyImagePreviewItem, targetPixelSize: Int) async {
        task?.cancel()
        let url = item.displayURL
        guard let url else { return }

        task = Task(priority: .userInitiated) { [weak self] in
            let snapshot: ZoomyViewerMediaSnapshot?
            if item.isLiveImage, let liveVideoURL = item.liveVideoURL {
                snapshot = await ZoomyViewerMediaLoader.loadLivePhoto(
                    imageURL: url,
                    videoURL: liveVideoURL,
                    targetPixelSize: targetPixelSize
                )
            } else if item.isAnimatedGIF {
                snapshot = await ZoomyViewerMediaLoader.loadAnimatedGIF(
                    url: url,
                    targetPixelSize: targetPixelSize
                )
            } else {
                snapshot = await ZoomyViewerMediaLoader.loadStaticImage(
                    url: url,
                    targetPixelSize: targetPixelSize
                )
            }

            guard !Task.isCancelled else { return }
            if let snapshot {
                await MainActor.run {
                    self?.setSnapshot(snapshot)
                }
                return
            }

            let fallbackImage = await RemoteImageCache.shared.load(
                url: url,
                scale: 1,
                targetPixelSize: targetPixelSize
            )
            guard !Task.isCancelled, let fallbackImage else { return }
            await MainActor.run {
                self?.setSnapshot(ZoomyViewerMediaSnapshot(image: fallbackImage, isFinal: true))
            }
        }
        await task?.value
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private func setSnapshot(_ snapshot: ZoomyViewerMediaSnapshot) {
        self.snapshot = snapshot
        snapshotVersion += 1
    }
}

private extension ZoomyImagePreviewItem {
    var isAnimatedGIF: Bool {
        mediaBadgeText?.caseInsensitiveCompare("GIF") == .orderedSame
            || displayURL?.absoluteString.lowercased().contains(".gif") == true
    }

    var isLiveImage: Bool {
        mediaBadgeText?.caseInsensitiveCompare("LIVE") == .orderedSame
            || liveVideoURL != nil
    }

    var needsOriginalMedia: Bool {
        isAnimatedGIF || isLiveImage
    }
}

private struct ZoomyViewerMediaSnapshot {
    let image: UIImage?
    let imageData: Data?
    let imageFileURL: URL?
    let liveVideoFileURL: URL?
    let livePhoto: PHLivePhoto?
    let isAnimatedGIF: Bool
    let isLivePhoto: Bool
    let isFinal: Bool

    init(
        image: UIImage?,
        imageData: Data? = nil,
        imageFileURL: URL? = nil,
        liveVideoFileURL: URL? = nil,
        livePhoto: PHLivePhoto? = nil,
        isAnimatedGIF: Bool = false,
        isLivePhoto: Bool = false,
        isFinal: Bool = true
    ) {
        self.image = image
        self.imageData = imageData
        self.imageFileURL = imageFileURL
        self.liveVideoFileURL = liveVideoFileURL
        self.livePhoto = livePhoto
        self.isAnimatedGIF = isAnimatedGIF
        self.isLivePhoto = isLivePhoto || liveVideoFileURL != nil
        self.isFinal = isFinal
    }
}

private struct ZoomySharePayload: Identifiable {
    let id = UUID()
    let activityItems: [Any]
}

private struct ZoomyActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

private enum ZoomyShareItemBuilder {
    static func activityItems(
        snapshot: ZoomyViewerMediaSnapshot?,
        item: ZoomyImagePreviewItem
    ) -> [Any] {
        guard let snapshot else {
            return item.displayURL.map { [$0] } ?? []
        }

        if snapshot.isLivePhoto {
            let resources = [snapshot.imageFileURL, snapshot.liveVideoFileURL].compactMap(\.self)
            if !resources.isEmpty {
                return resources
            }
        }

        if snapshot.isAnimatedGIF {
            if let fileURL = snapshot.imageFileURL {
                return [fileURL]
            }
            if let data = snapshot.imageData,
               let fileURL = try? ZoomyViewerMediaLoader.writeTemporaryFile(
                   data: data,
                   originalURL: item.displayURL,
                   fallbackExtension: "gif"
               ) {
                return [fileURL]
            }
        }

        if let image = snapshot.image {
            return [image]
        }
        return item.displayURL.map { [$0] } ?? []
    }
}

@MainActor
private enum ZoomyPhotoLibrarySaver {
    static func save(_ snapshot: ZoomyViewerMediaSnapshot) async -> Bool {
        guard await requestAddAuthorization() else { return false }

        if snapshot.isLivePhoto,
           let imageFileURL = snapshot.imageFileURL,
           let liveVideoFileURL = snapshot.liveVideoFileURL,
           await saveLivePhoto(imageFileURL: imageFileURL, videoFileURL: liveVideoFileURL) {
            return true
        }

        if snapshot.isAnimatedGIF {
            let fileURL = snapshot.imageFileURL
                ?? snapshot.imageData.flatMap {
                    try? ZoomyViewerMediaLoader.writeTemporaryFile(
                        data: $0,
                        originalURL: nil,
                        fallbackExtension: "gif"
                    )
                }
            if let fileURL,
               await saveImageFile(fileURL) {
                return true
            }
        }

        if let image = snapshot.image {
            return await saveStaticImage(image)
        }
        return false
    }

    private static func requestAddAuthorization() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    continuation.resume(returning: status)
                }
            }
            return status == .authorized || status == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private static func saveStaticImage(_ image: UIImage) async -> Bool {
        await performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    private static func saveImageFile(_ fileURL: URL) async -> Bool {
        await performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
        }
    }

    private static func saveLivePhoto(imageFileURL: URL, videoFileURL: URL) async -> Bool {
        await performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: imageFileURL, options: nil)
            request.addResource(with: .pairedVideo, fileURL: videoFileURL, options: nil)
        }
    }

    private static func performChanges(_ changes: @escaping () -> Void) async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges(changes) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}

private enum ZoomyViewerMediaLoader {
    static func loadStaticImage(url: URL, targetPixelSize: Int) async -> ZoomyViewerMediaSnapshot? {
        if let cachedImage = await RemoteImageCache.shared.image(for: url, scale: 1, targetPixelSize: targetPixelSize) {
            return ZoomyViewerMediaSnapshot(image: cachedImage, isFinal: true)
        }

        try? await Task.sleep(nanoseconds: 90_000_000)
        guard !Task.isCancelled else { return nil }
        guard let image = await RemoteImageCache.shared.load(
            url: url,
            scale: 1,
            targetPixelSize: targetPixelSize
        ) else { return nil }
        return ZoomyViewerMediaSnapshot(image: image, isFinal: true)
    }

    static func loadAnimatedGIF(url: URL, targetPixelSize: Int) async -> ZoomyViewerMediaSnapshot? {
        do {
            let data = try await fetchData(from: url, acceptsVideo: false)
            guard !Task.isCancelled else { return nil }
            let image = animatedGIFImage(data: data, targetPixelSize: targetPixelSize)
                ?? UIImage(data: data)
            guard let image else { return nil }
            let fileURL = try? writeTemporaryFile(data: data, originalURL: url, fallbackExtension: "gif")
            return ZoomyViewerMediaSnapshot(
                image: image,
                imageData: data,
                imageFileURL: fileURL,
                isAnimatedGIF: true,
                isFinal: true
            )
        } catch {
            return nil
        }
    }

    static func loadLivePhoto(
        imageURL: URL,
        videoURL: URL,
        targetPixelSize: Int
    ) async -> ZoomyViewerMediaSnapshot? {
        do {
            async let imageDataTask = fetchData(from: imageURL, acceptsVideo: false)
            async let videoDataTask = fetchData(from: videoURL, acceptsVideo: true)
            let (imageData, videoData) = try await (imageDataTask, videoDataTask)
            guard !Task.isCancelled else { return nil }
            let imageFileURL = try writeTemporaryFile(data: imageData, originalURL: imageURL, fallbackExtension: "jpg")
            let videoFileURL = try writeTemporaryFile(data: videoData, originalURL: videoURL, fallbackExtension: "mov")
            let image = downsampledImage(data: imageData, targetPixelSize: targetPixelSize)
                ?? UIImage(data: imageData)
            let livePhoto = await requestLivePhoto(
                imageFileURL: imageFileURL,
                videoFileURL: videoFileURL,
                placeholderImage: image
            )
            return ZoomyViewerMediaSnapshot(
                image: image,
                imageData: imageData,
                imageFileURL: imageFileURL,
                liveVideoFileURL: videoFileURL,
                livePhoto: livePhoto,
                isLivePhoto: true,
                isFinal: true
            )
        } catch {
            return await loadStaticImage(url: imageURL, targetPixelSize: targetPixelSize)
        }
    }

    static func writeTemporaryFile(
        data: Data,
        originalURL: URL?,
        fallbackExtension: String
    ) throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: "ZoomyMedia", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(
            path: "\(UUID().uuidString).\(preferredFileExtension(for: originalURL, fallback: fallbackExtension))"
        )
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    private static func fetchData(from url: URL, acceptsVideo: Bool) async throws -> Data {
        var request = URLRequest(url: url)
        var headers = BiliURLSessionFactory.imageHeaders()
        if acceptsVideo {
            headers["Accept"] = "*/*"
        }
        headers.forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }

        let session = BiliURLSessionFactory.makeImageSession()
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        if let response = response as? HTTPURLResponse,
           !(200..<300).contains(response.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func animatedGIFImage(data: Data, targetPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else { return UIImage(data: data) }

        var frames: [UIImage] = []
        var duration: TimeInterval = 0
        let maxPixelSize = max(targetPixelSize, 1)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else { continue }
            frames.append(UIImage(cgImage: cgImage, scale: 1, orientation: .up))
            duration += gifFrameDuration(source: source, index: index)
        }

        guard frames.count > 1 else { return frames.first }
        return UIImage.animatedImage(with: frames, duration: max(duration, Double(frames.count) * 0.08))
    }

    private static func gifFrameDuration(source: CGImageSource, index: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else { return 0.08 }
        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? TimeInterval
        return max(unclamped ?? clamped ?? 0.08, 0.02)
    }

    private static func downsampledImage(data: Data, targetPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(targetPixelSize, 1)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    private static func requestLivePhoto(
        imageFileURL: URL,
        videoFileURL: URL,
        placeholderImage: UIImage?
    ) async -> PHLivePhoto? {
        await withCheckedContinuation { continuation in
            var didResume = false
            PHLivePhoto.request(
                withResourceFileURLs: [imageFileURL, videoFileURL],
                placeholderImage: placeholderImage,
                targetSize: .zero,
                contentMode: .aspectFit
            ) { livePhoto, info in
                let isDegraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) == true
                guard !isDegraded, !didResume else { return }
                didResume = true
                continuation.resume(returning: livePhoto)
            }
        }
    }

    private static func preferredFileExtension(for url: URL?, fallback: String) -> String {
        guard let absoluteString = url?.absoluteString.lowercased() else { return fallback }
        for fileExtension in ["gif", "jpg", "jpeg", "png", "heic", "heif", "webp", "mov", "mp4"] {
            if absoluteString.contains(".\(fileExtension)") {
                return fileExtension
            }
        }
        return fallback
    }
}

private struct ZoomyViewerPageControl: UIViewRepresentable {
    let numberOfPages: Int
    let currentPage: Int

    private var indicatorColor: UIColor {
        .white
    }

    func makeUIView(context _: Context) -> UIPageControl {
        let control = UIPageControl()
        control.isUserInteractionEnabled = false
        control.allowsContinuousInteraction = false
        control.backgroundStyle = .minimal
        return control
    }

    func updateUIView(_ control: UIPageControl, context _: Context) {
        control.numberOfPages = numberOfPages
        control.currentPage = min(max(currentPage, 0), max(numberOfPages - 1, 0))
        control.isHidden = numberOfPages <= 1
        control.currentPageIndicatorTintColor = indicatorColor
        control.pageIndicatorTintColor = indicatorColor.withAlphaComponent(0.36)
    }
}

private struct ZoomyLivePhotoView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    let placeholderImage: UIImage
    let onTapExit: () -> Void

    func makeUIView(context _: Context) -> ZoomyLivePhotoHostView {
        let view = ZoomyLivePhotoHostView()
        view.onTapExit = onTapExit
        return view
    }

    func updateUIView(_ view: ZoomyLivePhotoHostView, context _: Context) {
        view.onTapExit = onTapExit
        view.setLivePhoto(livePhoto, placeholderImage: placeholderImage)
    }
}

private final class ZoomyLivePhotoHostView: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var onTapExit: (() -> Void)?

    private let scrollView = UIScrollView()
    private let livePhotoView = PHLivePhotoView()
    private var currentLivePhotoIdentifier: ObjectIdentifier?
    private var placeholderImageSize: CGSize = .zero
    private var lastLayoutSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false

        scrollView.backgroundColor = .clear
        scrollView.isOpaque = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        addSubview(scrollView)

        livePhotoView.backgroundColor = .clear
        livePhotoView.contentMode = .scaleAspectFit
        livePhotoView.isMuted = true
        scrollView.addSubview(livePhotoView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        tap.numberOfTapsRequired = 1
        tap.delegate = self

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        tap.require(toFail: doubleTap)

        scrollView.addGestureRecognizer(doubleTap)
        scrollView.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setLivePhoto(_ livePhoto: PHLivePhoto, placeholderImage: UIImage) {
        let identifier = ObjectIdentifier(livePhoto)
        guard currentLivePhotoIdentifier != identifier else { return }
        currentLivePhotoIdentifier = identifier
        placeholderImageSize = placeholderImage.size
        livePhotoView.livePhoto = livePhoto
        resetZoomLayout()
        livePhotoView.startPlayback(with: .full)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        guard bounds.size != lastLayoutSize else {
            centerContent()
            return
        }
        lastLayoutSize = bounds.size
        resetZoomLayout()
    }

    func viewForZooming(in _: UIScrollView) -> UIView? {
        livePhotoView
    }

    func scrollViewDidZoom(_: UIScrollView) {
        centerContent()
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer is UITapGestureRecognizer || otherGestureRecognizer is UITapGestureRecognizer
    }

    @objc private func handleSingleTap() {
        onTapExit?()
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard livePhotoView.livePhoto != nil else { return }
        let targetScale: CGFloat
        if scrollView.zoomScale <= scrollView.minimumZoomScale + 0.01 {
            targetScale = min(scrollView.maximumZoomScale, max(scrollView.minimumZoomScale * 2.4, 2.4))
        } else {
            targetScale = scrollView.minimumZoomScale
        }

        if targetScale <= scrollView.minimumZoomScale + 0.01 {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let location = recognizer.location(in: livePhotoView)
            scrollView.zoom(to: zoomRect(for: targetScale, centeredAt: location), animated: true)
        }
    }

    private func resetZoomLayout() {
        guard bounds.width > 1,
              bounds.height > 1,
              placeholderImageSize.width > 0,
              placeholderImageSize.height > 0
        else { return }

        scrollView.zoomScale = 1
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5

        let fittedSize = aspectFitSize(imageSize: placeholderImageSize, boundsSize: bounds.size)
        livePhotoView.frame = CGRect(origin: .zero, size: fittedSize)
        scrollView.contentSize = fittedSize
        centerContent()
    }

    private func centerContent() {
        let horizontalInset = max((bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let verticalInset = max((bounds.height - scrollView.contentSize.height) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }

    private func aspectFitSize(imageSize: CGSize, boundsSize: CGSize) -> CGSize {
        let scale = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)
        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    private func zoomRect(for scale: CGFloat, centeredAt center: CGPoint) -> CGRect {
        let width = scrollView.bounds.width / scale
        let height = scrollView.bounds.height / scale
        return CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
    }
}

private struct ZoomyZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let onTapExit: () -> Void

    func makeUIView(context _: Context) -> ZoomyZoomableImageHostView {
        let view = ZoomyZoomableImageHostView()
        view.onTapExit = onTapExit
        return view
    }

    func updateUIView(_ view: ZoomyZoomableImageHostView, context _: Context) {
        view.onTapExit = onTapExit
        view.setImage(image)
    }
}

private final class ZoomyZoomableImageHostView: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var onTapExit: (() -> Void)?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var currentImageIdentifier: ObjectIdentifier?
    private var lastLayoutSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false

        scrollView.backgroundColor = .clear
        scrollView.isOpaque = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        addSubview(scrollView)

        imageView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        scrollView.addSubview(imageView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        tap.numberOfTapsRequired = 1
        tap.delegate = self

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        tap.require(toFail: doubleTap)

        scrollView.addGestureRecognizer(doubleTap)
        scrollView.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(_ image: UIImage) {
        let identifier = ObjectIdentifier(image)
        guard currentImageIdentifier != identifier else { return }
        currentImageIdentifier = identifier
        imageView.image = image
        if image.images != nil {
            imageView.startAnimating()
        }
        resetZoomLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        guard bounds.size != lastLayoutSize else {
            centerImage()
            return
        }
        lastLayoutSize = bounds.size
        resetZoomLayout()
    }

    func viewForZooming(in _: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_: UIScrollView) {
        centerImage()
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer is UITapGestureRecognizer || otherGestureRecognizer is UITapGestureRecognizer
    }

    @objc private func handleSingleTap() {
        onTapExit?()
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard imageView.image != nil else { return }
        let targetScale: CGFloat
        if scrollView.zoomScale <= scrollView.minimumZoomScale + 0.01 {
            targetScale = min(scrollView.maximumZoomScale, max(scrollView.minimumZoomScale * 2.4, 2.4))
        } else {
            targetScale = scrollView.minimumZoomScale
        }

        if targetScale <= scrollView.minimumZoomScale + 0.01 {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let location = recognizer.location(in: imageView)
            scrollView.zoom(to: zoomRect(for: targetScale, centeredAt: location), animated: true)
        }
    }

    private func resetZoomLayout() {
        guard let image = imageView.image,
              bounds.width > 1,
              bounds.height > 1,
              image.size.width > 0,
              image.size.height > 0
        else { return }

        scrollView.zoomScale = 1
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5

        let fittedSize = aspectFitSize(imageSize: image.size, boundsSize: bounds.size)
        imageView.frame = CGRect(origin: .zero, size: fittedSize)
        scrollView.contentSize = fittedSize
        centerImage()
    }

    private func centerImage() {
        let horizontalInset = max((bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let verticalInset = max((bounds.height - scrollView.contentSize.height) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }

    private func aspectFitSize(imageSize: CGSize, boundsSize: CGSize) -> CGSize {
        let scale = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)
        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    private func zoomRect(for scale: CGFloat, centeredAt center: CGPoint) -> CGRect {
        let width = scrollView.bounds.width / scale
        let height = scrollView.bounds.height / scale
        return CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
    }
}
