import Foundation

nonisolated enum PlaybackStartupRequestSchedulingPolicy {
    static let staggeredFallbackDelayNanoseconds: UInt64 = 180_000_000
    static let wbiFailureThreshold = 2
    static let wbiFailureWindow: TimeInterval = 20
    static let wbiSuppressionDuration: TimeInterval = 30
}

nonisolated final class StartupPlayURLRequestLease: @unchecked Sendable {
    private let lock = NSLock()
    private var active = true

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return active
    }

    func invalidate() {
        lock.lock()
        active = false
        lock.unlock()
    }
}

nonisolated enum StartupPlayURLFeedbackEligibility {
    static func allows(_ lease: StartupPlayURLRequestLease?) -> Bool {
        lease?.isActive ?? true
    }
}

nonisolated enum StartupPlayURLRequestSource: String, Sendable {
    case foreground
    case preload

    var recordsSchedulerFeedback: Bool {
        self == .foreground
    }
}

nonisolated struct StartupWBISuppressionStatus: Equatable, Sendable {
    let reason: String
    let remainingMilliseconds: Int
}

nonisolated enum StartupWBIHealthUpdate: Equatable, Sendable {
    case observed(consecutiveFailures: Int)
    case suppressed(StartupWBISuppressionStatus)
}

actor StartupWBIHealthStore {
    private let failureThreshold: Int
    private let failureWindow: TimeInterval
    private let suppressionDuration: TimeInterval
    private var consecutiveFailures = 0
    private var lastFailureAt: TimeInterval?
    private var suppressionUntil: TimeInterval?
    private var suppressionReason: String?

    init(
        failureThreshold: Int = PlaybackStartupRequestSchedulingPolicy.wbiFailureThreshold,
        failureWindow: TimeInterval = PlaybackStartupRequestSchedulingPolicy.wbiFailureWindow,
        suppressionDuration: TimeInterval = PlaybackStartupRequestSchedulingPolicy.wbiSuppressionDuration
    ) {
        self.failureThreshold = max(failureThreshold, 1)
        self.failureWindow = max(failureWindow, 0)
        self.suppressionDuration = max(suppressionDuration, 1)
    }

    func suppressionStatus(now: TimeInterval = Date().timeIntervalSinceReferenceDate) -> StartupWBISuppressionStatus? {
        guard let suppressionUntil,
              now < suppressionUntil
        else {
            self.suppressionUntil = nil
            suppressionReason = nil
            return nil
        }
        return StartupWBISuppressionStatus(
            reason: suppressionReason ?? "unknown",
            remainingMilliseconds: max(Int(((suppressionUntil - now) * 1000).rounded()), 1)
        )
    }

    @discardableResult
    func recordSuccess() -> Bool {
        let didReset = consecutiveFailures > 0
        consecutiveFailures = 0
        lastFailureAt = nil
        return didReset
    }

    func recordFailure(
        reason: String,
        now: TimeInterval = Date().timeIntervalSinceReferenceDate
    ) -> StartupWBIHealthUpdate {
        if let status = suppressionStatus(now: now) {
            return .suppressed(status)
        }
        if let lastFailureAt,
           now - lastFailureAt > failureWindow {
            consecutiveFailures = 0
        }
        consecutiveFailures += 1
        lastFailureAt = now
        guard consecutiveFailures >= failureThreshold else {
            return .observed(consecutiveFailures: consecutiveFailures)
        }

        consecutiveFailures = 0
        lastFailureAt = nil
        suppressionUntil = now + suppressionDuration
        suppressionReason = reason
        return .suppressed(
            StartupWBISuppressionStatus(
                reason: reason,
                remainingMilliseconds: Int((suppressionDuration * 1000).rounded())
            )
        )
    }
}

nonisolated enum StartupPlayURLRoute: String, CaseIterable, Hashable, Sendable {
    case webpage
    case wbi
}

nonisolated struct StartupPlayURLSchedulingDecision: Equatable, Sendable {
    let primaryRoute: StartupPlayURLRoute?
    let fallbackRoute: StartupPlayURLRoute?

    static let race = StartupPlayURLSchedulingDecision(
        primaryRoute: nil,
        fallbackRoute: nil
    )

    var usesStaggeredFallback: Bool {
        primaryRoute != nil && fallbackRoute != nil
    }

    var diagnosticMessage: String {
        guard let primaryRoute, let fallbackRoute else {
            return "startupScheduler=adaptive mode=race learning"
        }
        let delayMilliseconds = PlaybackStartupRequestSchedulingPolicy.staggeredFallbackDelayNanoseconds / 1_000_000
        return "startupScheduler=adaptive mode=staggered primary=\(primaryRoute.rawValue) fallback=\(fallbackRoute.rawValue) delay=\(delayMilliseconds)ms"
    }
}

actor StartupPlayURLFallbackTracker {
    enum Status: String, Equatable, Sendable {
        case waiting
        case started
        case cancelledBeforeStart
    }

    private var status: Status = .waiting

    func markStarted() {
        guard status == .waiting else { return }
        status = .started
    }

    func markCancelledBeforeStart() {
        guard status == .waiting else { return }
        status = .cancelledBeforeStart
    }

    func currentStatus() -> Status {
        status
    }
}

actor StartupPlayURLRoutePerformanceStore {
    static let shared = StartupPlayURLRoutePerformanceStore()

    private struct RouteStatistics: Sendable {
        var acceptedSamples = [Int]()
        var rejectedCount = 0

        mutating func record(elapsedMilliseconds: Int, accepted: Bool, sampleLimit: Int) {
            if accepted {
                acceptedSamples.append(max(elapsedMilliseconds, 1))
                rejectedCount = max(rejectedCount - 1, 0)
                if acceptedSamples.count > sampleLimit {
                    acceptedSamples.removeFirst(acceptedSamples.count - sampleLimit)
                }
            } else {
                rejectedCount = min(rejectedCount + 1, sampleLimit)
            }
        }

        func medianElapsedMilliseconds() -> Int? {
            guard !acceptedSamples.isEmpty else { return nil }
            let sorted = acceptedSamples.sorted()
            return sorted[sorted.count / 2]
        }
    }

    private let sampleLimit: Int
    private let minimumAcceptedSamples: Int
    private let minimumMedianAdvantageMilliseconds: Int
    private var statisticsByNetwork = [String: [StartupPlayURLRoute: RouteStatistics]]()

    init(
        sampleLimit: Int = 8,
        minimumAcceptedSamples: Int = 3,
        minimumMedianAdvantageMilliseconds: Int = 35
    ) {
        self.sampleLimit = max(sampleLimit, 1)
        self.minimumAcceptedSamples = max(minimumAcceptedSamples, 1)
        self.minimumMedianAdvantageMilliseconds = max(minimumMedianAdvantageMilliseconds, 0)
    }

    func decision(
        networkClass: PlaybackEnvironment.NetworkClass,
        wbiAvailable: Bool
    ) -> StartupPlayURLSchedulingDecision {
        guard wbiAvailable,
              let statistics = statisticsByNetwork[networkKey(for: networkClass)]
        else {
            return .race
        }

        let webpage = statistics[.webpage]
        let wbi = statistics[.wbi]
        let hasVerifiedWebpage = (webpage?.acceptedSamples.count ?? 0) >= minimumAcceptedSamples
        let hasVerifiedWBI = (wbi?.acceptedSamples.count ?? 0) >= minimumAcceptedSamples

        switch (hasVerifiedWebpage, hasVerifiedWBI) {
        case (false, false):
            return .race
        case (true, false):
            return StartupPlayURLSchedulingDecision(primaryRoute: .webpage, fallbackRoute: .wbi)
        case (false, true):
            return StartupPlayURLSchedulingDecision(primaryRoute: .wbi, fallbackRoute: .webpage)
        case (true, true):
            break
        }

        guard let webpage,
              let wbi,
              let webpageMedian = webpage.medianElapsedMilliseconds(),
              let wbiMedian = wbi.medianElapsedMilliseconds()
        else {
            return .race
        }
        let webpageScore = webpageMedian + webpage.rejectedCount * minimumMedianAdvantageMilliseconds
        let wbiScore = wbiMedian + wbi.rejectedCount * minimumMedianAdvantageMilliseconds
        guard abs(webpageScore - wbiScore) >= minimumMedianAdvantageMilliseconds else {
            return .race
        }

        if wbiScore < webpageScore {
            return StartupPlayURLSchedulingDecision(primaryRoute: .wbi, fallbackRoute: .webpage)
        }
        return StartupPlayURLSchedulingDecision(primaryRoute: .webpage, fallbackRoute: .wbi)
    }

    @discardableResult
    func record(
        route: StartupPlayURLRoute,
        networkClass: PlaybackEnvironment.NetworkClass,
        elapsedMilliseconds: Int,
        accepted: Bool,
        requestLease: StartupPlayURLRequestLease? = nil
    ) -> Bool {
        guard StartupPlayURLFeedbackEligibility.allows(requestLease) else {
            return false
        }
        let key = networkKey(for: networkClass)
        var statistics = statisticsByNetwork[key, default: [:]]
        var routeStatistics = statistics[route, default: RouteStatistics()]
        routeStatistics.record(
            elapsedMilliseconds: elapsedMilliseconds,
            accepted: accepted,
            sampleLimit: sampleLimit
        )
        statistics[route] = routeStatistics
        statisticsByNetwork[key] = statistics
        return true
    }

    func reset() {
        statisticsByNetwork.removeAll()
    }

    private func networkKey(for networkClass: PlaybackEnvironment.NetworkClass) -> String {
        switch networkClass {
        case .wifi:
            return "wifi"
        case .cellular:
            return "cellular"
        case .constrained:
            return "constrained"
        case .unknown:
            return "unknown"
        }
    }
}
