import Foundation

nonisolated enum RemoteImageCDNFailoverExperiment {
    static let storageKey = "cc.bili.display.remoteImageCDNFailoverExperimentEnabled.v1"
    static let defaultIsEnabled = false
    static let failureTTL: TimeInterval = 90

    static func isEnabled(in userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.object(forKey: storageKey) as? Bool ?? defaultIsEnabled
    }
}

nonisolated enum RemoteImageCDNFailoverPolicy {
    private static let interchangeableHosts = [
        "i0.hdslb.com",
        "i1.hdslb.com",
        "i2.hdslb.com"
    ]

    static func isEligible(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return interchangeableHosts.contains(host)
    }

    static func candidateURLs(for url: URL) -> [URL] {
        guard let sourceHost = url.host?.lowercased(), interchangeableHosts.contains(sourceHost) else {
            return [url]
        }

        return ([sourceHost] + interchangeableHosts.filter { $0 != sourceHost }).compactMap { host in
            guard host != sourceHost else { return url }
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.host = host
            return components?.url
        }
    }

    static func shouldDemote(statusCode: Int) -> Bool {
        BiliNetworkRetryPolicy.image.shouldRetry(statusCode: statusCode)
    }

    static func shouldDemote(error: Error) -> Bool {
        if error is CancellationError {
            return false
        }
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .networkConnectionLost,
             .notConnectedToInternet,
             .cannotLoadFromNetwork,
             .badServerResponse,
             .resourceUnavailable:
            return true
        default:
            return false
        }
    }
}

nonisolated final class RemoteImageCDNHealthMemory: @unchecked Sendable {
    static let shared = RemoteImageCDNHealthMemory()

    private let lock = NSLock()
    private let failureTTL: TimeInterval
    private var unhealthyUntilByHost: [String: Date] = [:]

    init(failureTTL: TimeInterval = RemoteImageCDNFailoverExperiment.failureTTL) {
        self.failureTTL = max(failureTTL, 1)
    }

    func orderedCandidates(
        for urls: [URL],
        experimentEnabled: Bool,
        now: Date = Date()
    ) -> [URL] {
        let uniqueURLs = Self.uniqueURLs(urls)
        guard experimentEnabled else { return uniqueURLs }

        let candidates = Self.uniqueURLs(uniqueURLs.flatMap(RemoteImageCDNFailoverPolicy.candidateURLs))
        let unhealthyHosts = lock.withLock { () -> Set<String> in
            unhealthyUntilByHost = unhealthyUntilByHost.filter { $0.value > now }
            return Set(unhealthyUntilByHost.keys)
        }
        guard !unhealthyHosts.isEmpty else { return candidates }

        let healthy = candidates.filter { url in
            guard let host = url.host?.lowercased() else { return true }
            return !unhealthyHosts.contains(host)
        }
        let unhealthy = candidates.filter { url in
            guard let host = url.host?.lowercased() else { return false }
            return unhealthyHosts.contains(host)
        }
        return healthy + unhealthy
    }

    func recordTransientFailure(
        for url: URL,
        experimentEnabled: Bool,
        now: Date = Date()
    ) {
        guard experimentEnabled,
              RemoteImageCDNFailoverPolicy.isEligible(url),
              let host = url.host?.lowercased()
        else { return }
        lock.withLock {
            unhealthyUntilByHost[host] = now.addingTimeInterval(failureTTL)
        }
    }

    func recordSuccess(for url: URL, experimentEnabled: Bool) {
        guard experimentEnabled,
              RemoteImageCDNFailoverPolicy.isEligible(url),
              let host = url.host?.lowercased()
        else { return }
        lock.withLock {
            unhealthyUntilByHost[host] = nil
        }
    }

    func reset() {
        lock.withLock {
            unhealthyUntilByHost.removeAll()
        }
    }

    private static func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }
}
