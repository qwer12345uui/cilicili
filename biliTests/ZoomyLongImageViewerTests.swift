import XCTest
@testable import bili

final class ZoomyLongImageViewerTests: XCTestCase {
    func testLongImageStartsAtReadableScreenWidth() {
        let layout = ZoomyViewerImageSizing.initialLayout(
            imageSize: CGSize(width: 500, height: 5_000),
            boundsSize: CGSize(width: 390, height: 844)
        )

        XCTAssertTrue(layout.usesLongImageScrolling)
        XCTAssertEqual(layout.contentSize.width, 390, accuracy: 0.001)
        XCTAssertEqual(layout.contentSize.height, 3_900, accuracy: 0.001)
    }

    func testRegularImageKeepsAspectFitLayout() {
        let layout = ZoomyViewerImageSizing.initialLayout(
            imageSize: CGSize(width: 1_200, height: 800),
            boundsSize: CGSize(width: 390, height: 844)
        )

        XCTAssertFalse(layout.usesLongImageScrolling)
        XCTAssertEqual(layout.contentSize.width, 390, accuracy: 0.001)
        XCTAssertEqual(layout.contentSize.height, 260, accuracy: 0.001)
    }

    func testLongImageUsesLargerButBoundedDecodeTarget() {
        let target = ZoomyViewerImageSizing.targetPixelSize(
            baseTargetPixelSize: 2_400,
            widthToHeightAspectRatio: 0.1
        )

        XCTAssertGreaterThan(target, 2_400)
        XCTAssertLessThanOrEqual(target, 16_000)
        XCTAssertEqual(
            ZoomyViewerImageSizing.targetPixelSize(
                baseTargetPixelSize: 2_400,
                widthToHeightAspectRatio: 1.5
            ),
            2_400
        )
    }

    func testHighQualityViewerDecodeBypassesThumbnailLongestSideCap() {
        let environment = PlaybackEnvironment(
            networkClass: .wifi,
            isLowPowerModeEnabled: false,
            isThermallyConstrained: false,
            thermalPressure: .nominal
        )
        let requestedTarget = ZoomyViewerImageSizing.targetPixelSize(
            baseTargetPixelSize: 2_400,
            widthToHeightAspectRatio: 0.1
        )

        XCTAssertEqual(
            RemoteImageDecodeSizing.effectiveTargetPixelSize(
                requestedTarget,
                scale: 1,
                policy: .standard,
                environment: environment
            ),
            2_600
        )
        XCTAssertEqual(
            RemoteImageDecodeSizing.effectiveTargetPixelSize(
                requestedTarget,
                scale: 1,
                policy: .highQualityViewer,
                environment: environment
            ),
            requestedTarget
        )
        XCTAssertEqual(
            RemoteImageDecodeSizing.effectiveTargetPixelSize(
                20_000,
                scale: 1,
                policy: .highQualityViewer,
                environment: environment
            ),
            RemoteImageDecodeSizing.highQualityViewerMaximumPixelSize
        )
    }
}
