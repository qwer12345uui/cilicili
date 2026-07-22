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

    func testSchedulerDiagnosticDescribesTheStaggeredRouteOrder() {
        let decision = StartupPlayURLSchedulingDecision(
            primaryRoute: .wbi,
            fallbackRoute: .webpage
        )

        XCTAssertEqual(
            decision.diagnosticMessage,
            "startupScheduler=adaptive mode=staggered primary=wbi fallback=webpage delay=180ms"
        )
    }

    func testPerformanceCopyKeepsStartupSchedulerMessage() {
        var session = PlayerPerformanceSession(id: "BVstartupScheduler")
        session.startupSchedulerMessage = "startupScheduler=adaptive mode=race learning"

        let copy = PlayerPerformanceCopyTextFormatter.performanceCopyText(
            metricsID: session.metricsID,
            session: session
        )

        XCTAssertTrue(copy.contains("startupScheduler:\n  startupScheduler=adaptive mode=race learning"))
    }

    func testFallbackTrackerKeepsTheTerminalStatus() async {
        let cancelledBeforeStart = StartupPlayURLFallbackTracker()
        await cancelledBeforeStart.markCancelledBeforeStart()
        await cancelledBeforeStart.markStarted()
        let cancelledStatus = await cancelledBeforeStart.currentStatus()

        XCTAssertEqual(cancelledStatus, .cancelledBeforeStart)

        let started = StartupPlayURLFallbackTracker()
        await started.markStarted()
        await started.markCancelledBeforeStart()
        let startedStatus = await started.currentStatus()

        XCTAssertEqual(startedStatus, .started)
    }

    func testExpiredRequestLeaseRejectsLateSchedulerFeedback() async {
        let scheduler = StartupPlayURLRoutePerformanceStore(
            minimumAcceptedSamples: 1,
            minimumMedianAdvantageMilliseconds: 0
        )
        let requestLease = StartupPlayURLRequestLease()
        requestLease.invalidate()

        let recorded = await scheduler.record(
            route: .wbi,
            networkClass: .wifi,
            elapsedMilliseconds: 18_437,
            accepted: true,
            requestLease: requestLease
        )
        let decision = await scheduler.decision(networkClass: .wifi, wbiAvailable: true)

        XCTAssertFalse(recorded)
        XCTAssertFalse(StartupPlayURLFeedbackEligibility.allows(requestLease))
        XCTAssertFalse(decision.usesStaggeredFallback)
    }

    func testPreloadRequestsDoNotRecordSchedulerFeedback() {
        XCTAssertTrue(StartupPlayURLRequestSource.foreground.recordsSchedulerFeedback)
        XCTAssertFalse(StartupPlayURLRequestSource.preload.recordsSchedulerFeedback)
    }

    func testWBIHealthRequiresTwoFailuresBeforeSuppression() async {
        let health = StartupWBIHealthStore(
            failureThreshold: 2,
            failureWindow: 20,
            suppressionDuration: 30
        )

        let first = await health.recordFailure(reason: "network.-1001", now: 100)
        let statusAfterFirst = await health.suppressionStatus(now: 101)
        let second = await health.recordFailure(reason: "network.-1001", now: 102)
        let statusAfterSecond = await health.suppressionStatus(now: 103)

        XCTAssertEqual(first, .observed(consecutiveFailures: 1))
        XCTAssertNil(statusAfterFirst)
        XCTAssertEqual(
            second,
            .suppressed(
                StartupWBISuppressionStatus(
                    reason: "network.-1001",
                    remainingMilliseconds: 30_000
                )
            )
        )
        XCTAssertEqual(statusAfterSecond?.reason, "network.-1001")
        XCTAssertEqual(statusAfterSecond?.remainingMilliseconds, 29_000)
    }

    func testWBIHealthSuccessResetsPendingFailureStreak() async {
        let health = StartupWBIHealthStore(
            failureThreshold: 2,
            failureWindow: 20,
            suppressionDuration: 30
        )

        _ = await health.recordFailure(reason: "api.-403", now: 100)
        let didReset = await health.recordSuccess()
        let nextFailure = await health.recordFailure(reason: "api.-403", now: 101)

        XCTAssertTrue(didReset)
        XCTAssertEqual(nextFailure, .observed(consecutiveFailures: 1))
    }
}
