import SwiftUI
import XCTest
@testable import bili

final class RemoteImageScrollLoadSuppressionTests: XCTestCase {
    func testExperimentOnlySuppressesInteractiveAndDeceleratingScroll() {
        XCTAssertTrue(FastScrollImageLoadSuppressionPolicy.suppressesNetworkLoads(
            experimentEnabled: true,
            phase: .interacting
        ))
        XCTAssertTrue(FastScrollImageLoadSuppressionPolicy.suppressesNetworkLoads(
            experimentEnabled: true,
            phase: .decelerating
        ))
        XCTAssertFalse(FastScrollImageLoadSuppressionPolicy.suppressesNetworkLoads(
            experimentEnabled: true,
            phase: .idle
        ))
        XCTAssertFalse(FastScrollImageLoadSuppressionPolicy.suppressesNetworkLoads(
            experimentEnabled: false,
            phase: .interacting
        ))
    }

    func testCachedImageNeverWaitsForScrollToBecomeIdle() async {
        let gate = RemoteImageLoadSuppressionGate()
        let scopeID = UUID()
        await gate.setSuppressed(true, for: scopeID)

        await gate.waitUntilAllowed(hasCachedImage: true)

        let waiterCount = await gate.waiterCountForTesting()
        XCTAssertEqual(waiterCount, 0)
        await gate.setSuppressed(false, for: scopeID)
    }

    func testNetworkLoadResumesAfterSuppressionEnds() async {
        let gate = RemoteImageLoadSuppressionGate()
        let scopeID = UUID()
        await gate.setSuppressed(true, for: scopeID)

        let waiter = Task {
            await gate.waitUntilAllowed()
        }

        var waiterCount = 0
        for _ in 0..<20 {
            waiterCount = await gate.waiterCountForTesting()
            guard waiterCount == 0 else { break }
            await Task.yield()
        }
        XCTAssertEqual(waiterCount, 1)

        await gate.setSuppressed(false, for: scopeID)
        await waiter.value

        let resumedWaiterCount = await gate.waiterCountForTesting()
        XCTAssertEqual(resumedWaiterCount, 0)
    }
}
