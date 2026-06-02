import Foundation
import Observation
import Security

struct StoredSession: Codable, Equatable {
    var convexAuthToken: String?
    var betterAuthCookie: String?
    var betterAuthSessionToken: String?
    var convexAuthTokenRefreshedAt: Date? = nil
    var currentUser: CurrentUser? = nil

    var hasRefreshCredential: Bool {
        if let betterAuthCookie, !betterAuthCookie.isEmpty {
            return true
        }
        if let betterAuthSessionToken, !betterAuthSessionToken.isEmpty {
            return true
        }
        return false
    }
}

protocol SessionPersisting {
    func loadSession() -> StoredSession?
    func saveSession(_ session: StoredSession?)
}

protocol RecentEmailPersisting {
    func loadRecentEmails() -> [String]
    func saveRecentEmails(_ emails: [String])
}

struct UserDefaultsRecentEmailPersistence: RecentEmailPersisting {
    private let key = "Patchwork.recentLoginEmails"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadRecentEmails() -> [String] {
        userDefaults.stringArray(forKey: key) ?? []
    }

    func saveRecentEmails(_ emails: [String]) {
        userDefaults.set(emails, forKey: key)
    }
}

struct KeychainSessionPersistence: SessionPersisting {
    private let service = "com.patchwork.ios.session"
    private let account = "default"

    func loadSession() -> StoredSession? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(StoredSession.self, from: data)
    }

    func saveSession(_ session: StoredSession?) {
        guard let session else {
            SecItemDelete(baseQuery() as CFDictionary)
            return
        }

        guard let data = try? JSONEncoder().encode(session) else {
            return
        }

        let query = baseQuery()
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var createQuery = query
            createQuery[kSecValueData as String] = data
            SecItemAdd(createQuery as CFDictionary, nil)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
    }
}

@MainActor
@Observable
final class SessionStore {
    static let appReviewEmail = "review@apple.com"
    static let appReviewSeekerEmail = "seeker@apple.com"
    static let appReviewEmails: Set<String> = [
        appReviewEmail,
        appReviewSeekerEmail,
    ]

    private let sessionPersistence: SessionPersisting
    private let recentEmailPersistence: RecentEmailPersisting
    private let clientBuilder: (
        _ authToken: String?,
        _ betterAuthCookie: String?,
        _ betterAuthSessionToken: String?,
        _ onAuthTokenRefresh: (@Sendable (String) async -> Void)?,
        _ onBetterAuthCookieRefresh: (@Sendable (String) async -> Void)?,
        _ onAuthSessionInvalidated: (@Sendable (String) async -> Void)?
    ) -> ConvexHTTPClient

    private(set) var token: String?
    private(set) var betterAuthCookie: String?
    private(set) var betterAuthSessionToken: String?
    private(set) var cachedCurrentUser: CurrentUser?
    private(set) var launchedWithPersistedSession = false
    private(set) var hasAttemptedSessionRestore = false
    private(set) var isLoading = false
    private(set) var isRestoringSession = false
    private(set) var errorMessage: String?
    private(set) var recentEmails: [String]
    var emailForOTP = ""
    private var authSessionGeneration = 0
    private var convexAuthTokenListeners: [UUID: @Sendable (String?) -> Void] = [:]

    private struct AuthSessionSnapshot: Equatable {
        let generation: Int
        let token: String?
        let betterAuthCookie: String?
        let betterAuthSessionToken: String?
    }

    init(
        sessionPersistence: SessionPersisting = KeychainSessionPersistence(),
        recentEmailPersistence: RecentEmailPersisting = UserDefaultsRecentEmailPersistence(),
        clientBuilder: @escaping (
            _ authToken: String?,
            _ betterAuthCookie: String?,
            _ betterAuthSessionToken: String?,
            _ onAuthTokenRefresh: (@Sendable (String) async -> Void)?,
            _ onBetterAuthCookieRefresh: (@Sendable (String) async -> Void)?,
            _ onAuthSessionInvalidated: (@Sendable (String) async -> Void)?
        ) -> ConvexHTTPClient = { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
            ConvexHTTPClient(
                authToken: authToken,
                betterAuthCookie: betterAuthCookie,
                betterAuthSessionToken: betterAuthSessionToken,
                onAuthTokenRefresh: onAuthTokenRefresh,
                onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                onAuthSessionInvalidated: onAuthSessionInvalidated
            )
        }
    ) {
        self.sessionPersistence = sessionPersistence
        self.recentEmailPersistence = recentEmailPersistence
        self.clientBuilder = clientBuilder
        recentEmails = Self.normalizedRecentEmails(recentEmailPersistence.loadRecentEmails())

        if let storedSession = sessionPersistence.loadSession() {
            token = storedSession.convexAuthToken
            betterAuthCookie = storedSession.betterAuthCookie
            betterAuthSessionToken = storedSession.betterAuthSessionToken
            cachedCurrentUser = storedSession.currentUser
            launchedWithPersistedSession = true
        }
    }

    var isAuthenticated: Bool {
        token != nil || hasRefreshCredential
    }

    var needsSessionRestore: Bool {
        token == nil && hasRefreshCredential
    }

    var client: ConvexHTTPClient {
        let clientAuthSessionSnapshot = currentAuthSessionSnapshot
        return clientBuilder(
            token,
            betterAuthCookie,
            betterAuthSessionToken,
            { [weak self] refreshedToken in
                await self?.storeRefreshedConvexToken(refreshedToken, snapshot: clientAuthSessionSnapshot)
            },
            { [weak self] refreshedCookie in
                await self?.storeRefreshedBetterAuthCookie(refreshedCookie, snapshot: clientAuthSessionSnapshot)
            },
            nil
        )
    }

    var usesAppReviewShortcut: Bool {
        Self.appReviewEmails.contains(
            emailForOTP.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }

    @discardableResult
    func addConvexAuthTokenListener(_ listener: @escaping @Sendable (String?) -> Void) -> UUID {
        let id = UUID()
        convexAuthTokenListeners[id] = listener
        return id
    }

    func removeConvexAuthTokenListener(_ id: UUID) {
        convexAuthTokenListeners[id] = nil
    }

    func sendOTP() async {
        guard !emailForOTP.isEmpty else {
            errorMessage = "Enter your email first."
            return
        }
        await run {
            if usesAppReviewShortcut {
                let reviewClient = unauthenticatedClient()
                let sessionToken = try await reviewClient.signInForAppReview(email: emailForOTP)
                let refresh = try await reviewClient.fetchConvexAuthRefresh(sessionToken: sessionToken)
                persistSession(
                    StoredSession(
                        convexAuthToken: refresh.token,
                        betterAuthCookie: refresh.betterAuthCookie,
                        betterAuthSessionToken: sessionToken,
                        convexAuthTokenRefreshedAt: Date()
                    ),
                    startsNewAuthSession: true
                )
                recordRecentEmail(emailForOTP)
            } else {
                try await unauthenticatedClient().sendEmailOTP(email: emailForOTP)
            }
        }
    }

    func verifyOTP(code: String) async {
        guard !code.isEmpty else {
            errorMessage = "Enter the verification code."
            return
        }
        await run {
            var unauthenticatedClient = unauthenticatedClient()
            try await unauthenticatedClient.verifyEmailOTP(email: emailForOTP, otp: code)
            let refresh = try await unauthenticatedClient.fetchConvexAuthRefresh()
            persistSession(
                StoredSession(
                    convexAuthToken: refresh.token,
                    betterAuthCookie: refresh.betterAuthCookie ?? unauthenticatedClient.currentBetterAuthCookie,
                    betterAuthSessionToken: nil,
                    convexAuthTokenRefreshedAt: Date()
                ),
                startsNewAuthSession: true
            )
            recordRecentEmail(emailForOTP)
        }
    }

    func clearErrorMessage() {
        errorMessage = nil
    }

    @discardableResult
    func restorePersistedSessionIfNeeded(forceRefresh: Bool = false) async -> Bool {
        guard hasRefreshCredential else {
            hasAttemptedSessionRestore = false
            return token != nil
        }
        guard forceRefresh || token == nil || shouldRefreshStoredConvexToken() else {
            return true
        }

        hasAttemptedSessionRestore = true
        isRestoringSession = true
        defer { isRestoringSession = false }

        do {
            let refresh = try await clientBuilder(
                token,
                betterAuthCookie,
                betterAuthSessionToken,
                nil,
                nil,
                nil
            ).fetchConvexAuthRefresh()
            persistSession(
                StoredSession(
                    convexAuthToken: refresh.token,
                    betterAuthCookie: refresh.betterAuthCookie ?? betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    convexAuthTokenRefreshedAt: Date()
                )
            )
            return true
        } catch {
            if token != nil {
                return true
            }

            errorMessage = restoreFailureMessage(for: error)
            return false
        }
    }

    func signOut() async {
        let sessionToInvalidate = StoredSession(
            convexAuthToken: token,
            betterAuthCookie: betterAuthCookie,
            betterAuthSessionToken: betterAuthSessionToken,
            convexAuthTokenRefreshedAt: currentSessionRefreshDate,
            currentUser: cachedCurrentUser
        )

        clearSession(errorMessage: nil)

        guard sessionToInvalidate.hasRefreshCredential else {
            return
        }

        do {
            try await clientBuilder(
                sessionToInvalidate.convexAuthToken,
                sessionToInvalidate.betterAuthCookie,
                sessionToInvalidate.betterAuthSessionToken,
                nil,
                nil,
                nil
            ).signOut()
        } catch {
            // Local session has already been cleared; remote sign-out is best effort.
        }
    }

    func selectRecentEmail(_ email: String) {
        emailForOTP = Self.normalizedEmail(email)
        errorMessage = nil
    }

    func storeCurrentUserSnapshot(_ user: CurrentUser?) {
        cachedCurrentUser = user
        guard token != nil || hasRefreshCredential else {
            return
        }

        sessionPersistence.saveSession(
            StoredSession(
                convexAuthToken: token,
                betterAuthCookie: betterAuthCookie,
                betterAuthSessionToken: betterAuthSessionToken,
                convexAuthTokenRefreshedAt: currentSessionRefreshDate,
                currentUser: user
            )
        )
    }

    private func unauthenticatedClient() -> ConvexHTTPClient {
        clientBuilder(nil, nil, nil, nil, nil, nil)
    }

    private func run(_ task: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await task()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var hasRefreshCredential: Bool {
        if let betterAuthCookie, !betterAuthCookie.isEmpty {
            return true
        }
        if let betterAuthSessionToken, !betterAuthSessionToken.isEmpty {
            return true
        }
        return false
    }

    private func persistSession(_ session: StoredSession?, startsNewAuthSession: Bool = false) {
        let previousToken = token
        let nextCachedCurrentUser = session?.currentUser ?? (startsNewAuthSession ? nil : cachedCurrentUser)
        let sessionToPersist = session.map {
            StoredSession(
                convexAuthToken: $0.convexAuthToken,
                betterAuthCookie: $0.betterAuthCookie,
                betterAuthSessionToken: $0.betterAuthSessionToken,
                convexAuthTokenRefreshedAt: $0.convexAuthTokenRefreshedAt,
                currentUser: nextCachedCurrentUser
            )
        }
        if startsNewAuthSession {
            authSessionGeneration &+= 1
        }
        token = sessionToPersist?.convexAuthToken
        betterAuthCookie = sessionToPersist?.betterAuthCookie
        betterAuthSessionToken = sessionToPersist?.betterAuthSessionToken
        cachedCurrentUser = sessionToPersist?.currentUser
        if sessionToPersist != nil {
            errorMessage = nil
        }
        if sessionToPersist == nil {
            launchedWithPersistedSession = false
            hasAttemptedSessionRestore = false
        }
        sessionPersistence.saveSession(sessionToPersist)
        if previousToken != token || startsNewAuthSession || sessionToPersist == nil {
            notifyConvexAuthTokenListeners(token)
        }
    }

    private func storeRefreshedConvexToken(_ refreshedToken: String, snapshot: AuthSessionSnapshot) {
        guard snapshot.generation == authSessionGeneration,
              snapshot.token == token,
              snapshot.betterAuthCookie == betterAuthCookie,
              snapshot.betterAuthSessionToken == betterAuthSessionToken,
              hasRefreshCredential else {
            return
        }

        persistSession(
            StoredSession(
                convexAuthToken: refreshedToken,
                betterAuthCookie: betterAuthCookie,
                betterAuthSessionToken: betterAuthSessionToken,
                convexAuthTokenRefreshedAt: Date()
            )
        )
    }

    private func storeRefreshedBetterAuthCookie(_ refreshedCookie: String, snapshot: AuthSessionSnapshot) {
        guard currentAuthSessionSnapshot == snapshot,
              !refreshedCookie.isEmpty else {
            return
        }

        persistSession(
            StoredSession(
                convexAuthToken: token,
                betterAuthCookie: refreshedCookie,
                betterAuthSessionToken: betterAuthSessionToken,
                convexAuthTokenRefreshedAt: currentSessionRefreshDate
            )
        )
    }

    private func clearSession(errorMessage: String?) {
        self.errorMessage = errorMessage
        emailForOTP = ""
        persistSession(nil)
    }

    private func notifyConvexAuthTokenListeners(_ token: String?) {
        for listener in convexAuthTokenListeners.values {
            listener(token)
        }
    }

    private var currentSessionRefreshDate: Date? {
        sessionPersistence.loadSession()?.convexAuthTokenRefreshedAt
    }

    private var currentAuthSessionSnapshot: AuthSessionSnapshot {
        AuthSessionSnapshot(
            generation: authSessionGeneration,
            token: token,
            betterAuthCookie: betterAuthCookie,
            betterAuthSessionToken: betterAuthSessionToken
        )
    }

    private func shouldRefreshStoredConvexToken(now: Date = Date()) -> Bool {
        guard token != nil else {
            return true
        }

        if let expiryDate = Self.jwtExpiryDate(token),
           expiryDate.timeIntervalSince(now) <= Self.proactiveRefreshLeeway {
            return true
        }

        guard let refreshedAt = currentSessionRefreshDate else {
            return false
        }

        return now.timeIntervalSince(refreshedAt) >= Self.maximumTokenRefreshAge
    }

    private func recordRecentEmail(_ email: String) {
        let normalized = Self.normalizedEmail(email)
        guard !normalized.isEmpty else {
            return
        }

        recentEmails = Self.normalizedRecentEmails([normalized] + recentEmails)
        recentEmailPersistence.saveRecentEmails(recentEmails)
    }

    private static func normalizedRecentEmails(_ emails: [String]) -> [String] {
        var deduped: [String] = []
        for email in emails {
            let normalized = normalizedEmail(email)
            guard !normalized.isEmpty, !deduped.contains(normalized) else {
                continue
            }
            deduped.append(normalized)
            if deduped.count == maximumRecentEmailCount {
                break
            }
        }
        return deduped
    }

    private static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func jwtExpiryDate(_ token: String?) -> Date? {
        guard let token,
              let payload = token.split(separator: ".").dropFirst().first else {
            return nil
        }

        var base64 = String(payload)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64.append(String(repeating: "=", count: padding))

        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let expiresAt = object["exp"] as? TimeInterval else {
            return nil
        }

        return Date(timeIntervalSince1970: expiresAt)
    }

    private static let proactiveRefreshLeeway: TimeInterval = 60 * 5
    private static let maximumTokenRefreshAge: TimeInterval = 60 * 60 * 6
    private static let maximumRecentEmailCount = 3
    private static let sessionRefreshRetryMessage = "We couldn't refresh your session. We'll keep trying."

    private func restoreFailureMessage(for error: Error) -> String {
        if case PatchworkError.authRefreshFailed = error {
            return Self.sessionRefreshRetryMessage
        }

        if let patchworkError = error as? PatchworkError,
           let description = patchworkError.errorDescription,
           !description.isEmpty {
            if isAuthenticationFailure(description) {
                return Self.sessionRefreshRetryMessage
            }
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty {
            if isAuthenticationFailure(description) {
                return Self.sessionRefreshRetryMessage
            }
            return description
        }

        return Self.sessionRefreshRetryMessage
    }

    private func isAuthenticationFailure(_ description: String) -> Bool {
        let normalized = description
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let authFailurePhrases = [
            "unauthorized",
            "forbidden",
            "not authenticated",
            "authentication expired",
            "authentication required",
            "session expired",
            "expired session",
            "invalid session",
            "session is invalid",
            "token expired",
            "expired token",
            "invalid token",
            "token is invalid",
            "invalid jwt",
            "jwt expired",
        ]
        return authFailurePhrases.contains(where: normalized.contains)
    }

    private func isAuthenticationFailure(_ error: Error) -> Bool {
        if let patchworkError = error as? PatchworkError,
           let description = patchworkError.errorDescription,
           !description.isEmpty {
            return isAuthenticationFailure(description)
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return !description.isEmpty && isAuthenticationFailure(description)
    }
}
