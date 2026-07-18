import XCTest
@testable import bili

final class PlaybackStartupRequestSchedulingTests: XCTestCase {
    func testSchedulerRacesUntilAStartSourceHasEnoughAcceptedSamples() async {
        let scheduler = StartupPlayURLRoutePerformanceStore(
            sampleLimit: 4,
            minimumAcceptedSamples: 3,
            minimumMedianAdvantageMilliseconds: 35
        )

        await scheduler.record(
            route: .webpage,
            networkClass: .wifi,
            elapsedMilliseconds: 260,
            accepted: true
        )
        await scheduler.record(
            route: .wbi,
            networkClass: .wifi,
            elapsedMilliseconds: 100,
            accepted: true
        )

        let decision = await scheduler.decision(networkClass: .wifi, wbiAvailable: true)

        XCTAssertFalse(decision.usesStaggeredFallback)
    }

    func testSchedulerStaggersTheSlowerSourceAfterLearning() async {
        let scheduler = StartupPlayURLRoutePerformanceStore(
            sampleLimit: 4,
            minimumAcceptedSamples: 3,
            minimumMedianAdvantageMilliseconds: 35
        )

        for elapsedMilliseconds in [280, 300, 290] {
            await scheduler.record(
                route: .webpage,
                networkClass: .wifi,
                elapsedMilliseconds: elapsedMilliseconds,
                accepted: true
            )
        }
        for elapsedMilliseconds in [110, 120, 105] {
            await scheduler.record(
                route: .wbi,
                networkClass: .wifi,
                elapsedMilliseconds: elapsedMilliseconds,
                accepted: true
            )
        }

        let decision = await scheduler.decision(networkClass: .wifi, wbiAvailable: true)

        XCTAssertTrue(decision.usesStaggeredFallback)
        XCTAssertEqual(decision.primaryRoute, .wbi)
        XCTAssertEqual(decision.fallbackRoute, .webpage)
    }

    func testSchedulerUsesAProvenWinnerBeforeTheFallbackHasSamples() async {
        let scheduler = StartupPlayURLRoutePerformanceStore(
            sampleLimit: 4,
            minimumAcceptedSamples: 3,
            minimumMedianAdvantageMilliseconds: 35
        )

        for elapsedMilliseconds in [110, 120, 105] {
            await scheduler.record(
                route: .wbi,
                networkClass: .wifi,
                elapsedMilliseconds: elapsedMilliseconds,
                accepted: true
            )
        }

        let decision = await scheduler.decision(networkClass: .wifi, wbiAvailable: true)

        XCTAssertTrue(decision.usesStaggeredFallback)
        XCTAssertEqual(decision.primaryRoute, .wbi)
        XCTAssertEqual(decision.fallbackRoute, .webpage)
    }

    func testSchedulerUsesFullRaceWhenWBIIsUnavailable() async {
        let scheduler = StartupPlayURLRoutePerformanceStore(
            minimumAcceptedSamples: 1,
            minimumMedianAdvantageMilliseconds: 0
        )
        await scheduler.record(
            route: .webpage,
            networkClass: .wifi,
            elapsedMilliseconds: 300,
            accepted: true
        )
        await scheduler.record(
            route: .wbi,
            networkClass: .wifi,
            elapsedMilliseconds: 100,
            accepted: true
        )

        let decision = await scheduler.decision(networkClass: .wifi, wbiAvailable: false)

        XCTAssertFalse(decision.usesStaggeredFallback)
    }
}
