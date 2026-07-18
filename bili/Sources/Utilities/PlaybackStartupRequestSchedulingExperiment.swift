import Foundation

nonisolated enum PlaybackStartupRequestSchedulingExperiment {
    static let storageKey = "cc.bili.playback.startupRequestSchedulingExperimentEnabled.v1"
    static let defaultIsEnabled = false
    static let staggeredFallbackDelayNanoseconds: UInt64 = 180_000_000
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
            return "startupScheduler=experiment mode=race learning"
        }
        let delayMilliseconds = PlaybackStartupRequestSchedulingExperiment.staggeredFallbackDelayNanoseconds / 1_000_000
        return "startupScheduler=experiment mode=staggered primary=\(primaryRoute.rawValue) fallback=\(fallbackRoute.rawValue) delay=\(delayMilliseconds)ms"
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

    func record(
        route: StartupPlayURLRoute,
        networkClass: PlaybackEnvironment.NetworkClass,
        elapsedMilliseconds: Int,
        accepted: Bool
    ) {
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
