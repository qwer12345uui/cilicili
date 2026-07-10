import Combine
import SwiftUI
import UIKit
import XCTest
@testable import bili

final class PlaybackDetailSharedLayoutTests: XCTestCase {
    func testPortraitWidthUsesSmallestAvailableShortSide() {
        XCTAssertEqual(
            PlaybackDetailStableLayout.portraitWidth(
                containerSize: CGSize(width: 844, height: 390),
                fullscreenSize: CGSize(width: 852, height: 393),
                windowSize: CGSize(width: 375, height: 812)
            ),
            375
        )
    }

    func testPortraitWidthWorksWithoutWindowSize() {
        XCTAssertEqual(
            PlaybackDetailStableLayout.portraitWidth(
                containerSize: CGSize(width: 393, height: 852),
                fullscreenSize: CGSize(width: 852, height: 393),
                windowSize: nil
            ),
            393
        )
    }

    func testSharedPlayerAndContentMetrics() {
        XCTAssertEqual(PlaybackDetailPlayerMetrics.standardHeight(for: 393), 221.0625)
        XCTAssertEqual(PlaybackDetailContentMetrics.contentWidth(for: 393), 369)
        XCTAssertEqual(PlaybackDetailContentMetrics.contentWidth(for: 12), 0)
    }

    func testFullscreenGeometryFallsBackToSafeAreaExpansion() {
        let geometry = PlaybackDetailFullscreenGeometry.resolve(
            containerSize: CGSize(width: 375, height: 734),
            safeAreaInsets: EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0),
            localFrame: .zero,
            window: nil,
            resolveSize: { _, _ in
                XCTFail("Fallback geometry must not resolve a window size")
                return .zero
            }
        )

        XCTAssertEqual(geometry.size, CGSize(width: 375, height: 815))
        XCTAssertEqual(geometry.offset, CGSize(width: 0, height: -47))
    }

    @MainActor
    func testFullscreenGeometryUsesWindowCoordinateSpaceWhenAvailable() {
        let controller = UIViewController()
        let window = UIWindow(frame: CGRect(x: 40, y: 30, width: 390, height: 844))
        window.rootViewController = controller
        window.layoutIfNeeded()

        let localFrame = CGRect(x: 84, y: 126, width: 300, height: 600)
        let frameInWindow = controller.view.convert(localFrame, from: nil)
        let expectedSize = CGSize(width: 844, height: 390)
        let geometry = PlaybackDetailFullscreenGeometry.resolve(
            containerSize: CGSize(width: 300, height: 600),
            safeAreaInsets: EdgeInsets(top: 10, leading: 5, bottom: 20, trailing: 5),
            localFrame: localFrame,
            window: window,
            resolveSize: { _, rootView in
                XCTAssertTrue(rootView === controller.view)
                return expectedSize
            }
        )

        XCTAssertEqual(geometry.size, expectedSize)
        XCTAssertEqual(
            geometry.offset,
            CGSize(width: -frameInWindow.minX, height: -frameInWindow.minY)
        )
    }

    @MainActor
    func testLoadedPageRemovesInitialContentAfterLoadedContentAppears() async throws {
        let model = PlaybackDetailLoadedValueModel()
        let recorder = PlaybackDetailLifecycleRecorder()
        let controller = UIHostingController(
            rootView: PlaybackDetailLoadedStateHarness(model: model, recorder: recorder)
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        try await waitUntil { recorder.events.contains("initial appeared") }

        model.value = 1

        try await waitUntil {
            recorder.events.contains("loaded appeared")
                && recorder.events.contains("initial disappeared")
        }

        let loadedIndex = try XCTUnwrap(recorder.events.firstIndex(of: "loaded appeared"))
        let initialDisappearIndex = try XCTUnwrap(recorder.events.firstIndex(of: "initial disappeared"))
        XCTAssertLessThan(loadedIndex, initialDisappearIndex)
    }

    @MainActor
    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                XCTFail("Timed out waiting for shared playback detail state")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
private final class PlaybackDetailLoadedValueModel: ObservableObject {
    @Published var value: Int?
}

@MainActor
private final class PlaybackDetailLifecycleRecorder {
    private(set) var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

private struct PlaybackDetailLoadedStateHarness: View {
    @ObservedObject var model: PlaybackDetailLoadedValueModel
    let recorder: PlaybackDetailLifecycleRecorder

    var body: some View {
        PlaybackDetailLoadedStatePage(model.value) { _ in
            Color.green
                .onAppear { recorder.record("loaded appeared") }
        } initialContent: {
            Color.gray
                .onAppear { recorder.record("initial appeared") }
                .onDisappear { recorder.record("initial disappeared") }
        }
    }
}
