import Foundation
import Combine

nonisolated enum LoginCredentialKind: String, Codable, Sendable {
    case unknown
    case web
    case appQRCodeTV
    case appSMS
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessdata: String?
    @Published private(set) var accessKey: String?
    @Published private(set) var loginCredentialKind: LoginCredentialKind
    @Published private(set) var user: NavUserInfo?
    @Published private(set) var playbackCredentialVersion = 0

    private let keychain: KeychainStore
    private let sessdataKey = "SESSDATA"
    private let accessKeyKey = "ACCESS_KEY"
    private let loginCookieHeaderKey = "LOGIN_COOKIE_HEADER"
    private let loginCredentialKindKey = "LOGIN_CREDENTIAL_KIND"
    private let buvidKey = "buvid3"
    private var loginCookieHeader: String?

    init(keychain: KeychainStore? = nil) {
        let keychain = keychain ?? KeychainStore()
        self.keychain = keychain
        let storedLoginCookieHeader = try? keychain.read(loginCookieHeaderKey)
        self.loginCookieHeader = storedLoginCookieHeader
        self.sessdata = (try? keychain.read(sessdataKey))
            ?? Self.cookieValue(named: "SESSDATA", in: storedLoginCookieHeader)
        self.accessKey = try? keychain.read(accessKeyKey)
        if let rawKind = try? keychain.read(loginCredentialKindKey),
           let kind = LoginCredentialKind(rawValue: rawKind) {
            self.loginCredentialKind = kind
        } else {
            self.loginCredentialKind = .unknown
        }
    }

    var isLoggedIn: Bool {
        sessdata?.isEmpty == false
    }

    func cookieHeader() -> String {
        var values = Self.cookieValues(in: loginCookieHeader)
        if let sessdata = sessdata?.trimmingCharacters(in: .whitespacesAndNewlines), !sessdata.isEmpty {
            values["SESSDATA"] = sessdata
        }
        if values["buvid3"]?.isEmpty != false {
            values["buvid3"] = buvid3()
        }
        return Self.cookieHeader(from: values)
    }

    func anonymousCookieHeader() -> String {
        "buvid3=\(buvid3())"
    }

    func appAccessKey() -> String? {
        guard let accessKey = accessKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !accessKey.isEmpty
        else { return nil }
        return accessKey
    }

    func recommendCacheIdentityKey(guestModeEnabled: Bool) -> String {
        if guestModeEnabled {
            return "guest-\(buvid3())"
        }
        let credentialSuffix = "login-\(loginCredentialKind.rawValue)"
        if let mid = Self.cookieValue(named: "DedeUserID", in: cookieHeader()) {
            return "mid-\(mid)|\(credentialSuffix)"
        }
        if isLoggedIn {
            return "auth-cookie|\(credentialSuffix)"
        }
        return "anon-\(buvid3())"
    }

    func saveBuvid3(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: buvidKey)
    }

    func csrfToken() -> String? {
        cookieHeader()
            .split(separator: ";")
            .compactMap { item -> String? in
                let pair = item.split(separator: "=", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard pair.count == 2, pair[0] == "bili_jct", !pair[1].isEmpty else { return nil }
                return pair[1]
            }
            .first
    }

    func saveSESSDATA(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousSESSDATA = sessdata?.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacesSession = previousSESSDATA != trimmed
        try keychain.save(trimmed, for: sessdataKey)
        sessdata = trimmed
        var values = Self.cookieValues(in: loginCookieHeader)
        if replacesSession {
            Self.accountBoundCookieNames.forEach { values[$0] = nil }
            try keychain.delete(accessKeyKey)
            accessKey = nil
        }
        if trimmed.isEmpty {
            values["SESSDATA"] = nil
        } else {
            values["SESSDATA"] = trimmed
        }
        try saveLoginCookieHeader(values)
        markPlaybackCredentialsChanged()
    }

    func saveLoginCookies(_ cookies: [HTTPCookie], credentialKind: LoginCredentialKind? = nil) throws {
        let values = cookies.reduce(into: [String: String]()) { result, cookie in
            result[cookie.name] = cookie.value
        }
        try saveLoginCookies(values, credentialKind: credentialKind)
    }

    func saveLoginCookies(_ cookies: [String: String], credentialKind: LoginCredentialKind? = nil) throws {
        let incomingSESSDATA = cookies["SESSDATA"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousSESSDATA = sessdata?.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacesSession = incomingSESSDATA.map { !$0.isEmpty && $0 != previousSESSDATA } ?? false
        var mergedCookies = Self.cookieValues(in: loginCookieHeader)
        if replacesSession {
            // A new session must not inherit account-bound cookies from the previous user.
            Self.accountBoundCookieNames.forEach { mergedCookies[$0] = nil }
            if cookies["access_key"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                try keychain.delete(accessKeyKey)
                accessKey = nil
            }
        }
        for name in Self.loginCookieNames {
            guard let value = cookies[name]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                continue
            }
            mergedCookies[name] = value
        }

        if let sessdata = incomingSESSDATA, !sessdata.isEmpty {
            try keychain.save(sessdata, for: sessdataKey)
            self.sessdata = sessdata
            mergedCookies["SESSDATA"] = sessdata
        } else if let sessdata = self.sessdata?.trimmingCharacters(in: .whitespacesAndNewlines), !sessdata.isEmpty {
            mergedCookies["SESSDATA"] = sessdata
        }
        if let accessKey = cookies["access_key"]?.trimmingCharacters(in: .whitespacesAndNewlines), !accessKey.isEmpty {
            try keychain.save(accessKey, for: accessKeyKey)
            self.accessKey = accessKey
        }
        try saveLoginCookieHeader(mergedCookies)
        if let credentialKind {
            try keychain.save(credentialKind.rawValue, for: loginCredentialKindKey)
            self.loginCredentialKind = credentialKind
        }
        markPlaybackCredentialsChanged()
    }

    func updateUser(_ user: NavUserInfo?) {
        self.user = user
    }

    func logout() throws {
        try keychain.delete(sessdataKey)
        try keychain.delete(accessKeyKey)
        try keychain.delete(loginCookieHeaderKey)
        try keychain.delete(loginCredentialKindKey)
        sessdata = nil
        accessKey = nil
        loginCookieHeader = nil
        loginCredentialKind = .unknown
        user = nil
        markPlaybackCredentialsChanged()
    }

    func buvid3() -> String {
        if let existing = UserDefaults.standard.string(forKey: buvidKey), !existing.isEmpty {
            return existing
        }
        let newValue = UUID().uuidString.lowercased() + "infoc"
        UserDefaults.standard.set(newValue, forKey: buvidKey)
        return newValue
    }

    nonisolated private static let loginCookieNames = [
        "buvid3",
        "buvid4",
        "b_nut",
        "buvid_fp",
        "buvid_fp_plain",
        "_uuid",
        "b_lsid",
        "bili_ticket",
        "bili_ticket_expires",
        "DedeUserID",
        "DedeUserID__ckMd5",
        "SESSDATA",
        "bili_jct",
        "sid",
        "CURRENT_FNVAL",
        "CURRENT_QUALITY"
    ]

    nonisolated private static let accountBoundCookieNames: Set<String> = [
        "SESSDATA",
        "DedeUserID",
        "DedeUserID__ckMd5",
        "bili_jct",
        "sid",
        "bili_ticket",
        "bili_ticket_expires"
    ]

    private func saveLoginCookieHeader(_ values: [String: String]) throws {
        let header = Self.cookieHeader(from: values)
        guard !header.isEmpty else {
            try keychain.delete(loginCookieHeaderKey)
            loginCookieHeader = nil
            return
        }
        try keychain.save(header, for: loginCookieHeaderKey)
        loginCookieHeader = header
    }

    private func markPlaybackCredentialsChanged() {
        playbackCredentialVersion &+= 1
    }

    private nonisolated static func cookieValue(named name: String, in header: String?) -> String? {
        cookieValues(in: header)[name]
    }

    private nonisolated static func cookieValues(in header: String?) -> [String: String] {
        guard let header else { return [:] }
        return header
            .split(separator: ";")
            .reduce(into: [String: String]()) { values, item in
                let pair = item.split(separator: "=", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard pair.count == 2, !pair[0].isEmpty, !pair[1].isEmpty else { return }
                values[pair[0]] = pair[1]
            }
    }

    private nonisolated static func cookieHeader(from values: [String: String]) -> String {
        loginCookieNames.compactMap { name in
            guard let value = values[name], !value.isEmpty else { return nil }
            return "\(name)=\(value)"
        }
        .joined(separator: "; ")
    }
}
