import XCTest
@testable import bili

final class RemoteImageCDNFailoverTests: XCTestCase {
    func testDisabledExperimentKeepsOriginalURLOnly() throws {
        let memory = RemoteImageCDNHealthMemory()
        let url = try XCTUnwrap(URL(string: "https://i0.hdslb.com/bfs/archive/example.jpg?imageView2/1/w/640"))

        let candidates = memory.orderedCandidates(for: [url], experimentEnabled: false)

        XCTAssertEqual(candidates, [url])
    }

    func testEligibleImageURLAddsInterchangeableCDNHosts() throws {
        let memory = RemoteImageCDNHealthMemory()
        let url = try XCTUnwrap(URL(string: "https://i0.hdslb.com/bfs/archive/example.jpg?imageView2/1/w/640"))

        let candidates = memory.orderedCandidates(for: [url], experimentEnabled: true)

        XCTAssertEqual(candidates.compactMap(\.host), ["i0.hdslb.com", "i1.hdslb.com", "i2.hdslb.com"])
        XCTAssertTrue(candidates.allSatisfy { $0.path == url.path && $0.query == url.query })
    }

    func testThirdPartyImageURLIsNeverRewritten() throws {
        let memory = RemoteImageCDNHealthMemory()
        let url = try XCTUnwrap(URL(string: "https://images.example.com/avatar.jpg"))

        let candidates = memory.orderedCandidates(for: [url], experimentEnabled: true)

        XCTAssertEqual(candidates, [url])
    }

    func testTransientFailureDemotesHostUntilTTLExpires() throws {
        let memory = RemoteImageCDNHealthMemory(failureTTL: 90)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let url = try XCTUnwrap(URL(string: "https://i0.hdslb.com/bfs/archive/example.jpg"))
        memory.recordTransientFailure(for: url, experimentEnabled: true, now: now)

        let duringTTL = memory.orderedCandidates(
            for: [url],
            experimentEnabled: true,
            now: now.addingTimeInterval(30)
        )
        let afterTTL = memory.orderedCandidates(
            for: [url],
            experimentEnabled: true,
            now: now.addingTimeInterval(91)
        )

        XCTAssertEqual(duringTTL.compactMap(\.host), ["i1.hdslb.com", "i2.hdslb.com", "i0.hdslb.com"])
        XCTAssertEqual(afterTTL.first?.host, "i0.hdslb.com")
    }

    func testSuccessRestoresOriginalHostImmediately() throws {
        let memory = RemoteImageCDNHealthMemory(failureTTL: 90)
        let url = try XCTUnwrap(URL(string: "https://i0.hdslb.com/bfs/archive/example.jpg"))
        memory.recordTransientFailure(for: url, experimentEnabled: true)
        memory.recordSuccess(for: url, experimentEnabled: true)

        let candidates = memory.orderedCandidates(for: [url], experimentEnabled: true)

        XCTAssertEqual(candidates.first?.host, "i0.hdslb.com")
    }

    func testOnlyTransientFailuresDemoteImageCDNHost() {
        XCTAssertTrue(RemoteImageCDNFailoverPolicy.shouldDemote(statusCode: 503))
        XCTAssertFalse(RemoteImageCDNFailoverPolicy.shouldDemote(statusCode: 404))
        XCTAssertTrue(RemoteImageCDNFailoverPolicy.shouldDemote(error: URLError(.timedOut)))
        XCTAssertFalse(RemoteImageCDNFailoverPolicy.shouldDemote(error: URLError(.cancelled)))
        XCTAssertEqual(BiliNetworkRetryPolicy.imageFailover.attempts, 1)
        XCTAssertEqual(BiliNetworkRetryPolicy.image.attempts, 2)
    }
}
