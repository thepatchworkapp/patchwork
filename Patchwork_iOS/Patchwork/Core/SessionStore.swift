import Foundation
import Observation
import Security

struct StoredSession: Codable, Equatable {
    var convexAuthToken: String?
    var betterAuthCookie: String?
    var betterAuthSessionToken: String?

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
    private(set) var launchedWithPersistedSession = false
    private(set) var isLoading = false
    private(set) var isRestoringSession = false
    private(set) var errorMessage: String?
    var emailForOTP = ""

    init(
        sessionPersistence: SessionPersisting = KeychainSessionPersistence(),
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
        self.clientBuilder = clientBuilder

        if let storedSession = sessionPersistence.loadSession() {
            token = storedSession.convexAuthToken
            betterAuthCookie = storedSession.betterAuthCookie
            betterAuthSessionToken = storedSession.betterAuthSessionToken
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
        clientBuilder(
            token,
            betterAuthCookie,
            betterAuthSessionToken,
            { [weak self] refreshedToken in
                await self?.storeRefreshedConvexToken(refreshedToken)
            },
            { [weak self] refreshedCookie in
                await self?.storeRefreshedBetterAuthCookie(refreshedCookie)
            },
            { [weak self] message in
                await self?.invalidateSession(message: message)
            }
        )
    }

    var usesAppReviewShortcut: Bool {
        Self.appReviewEmails.contains(
            emailForOTP.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }

    func sendOTP() async {
        guard !emailForOTP.isEmpty else {
            errorMessage = "Enter your email first."
            return
        }
        await run {
            if usesAppReviewShortcut {
                let reviewClient = ConvexHTTPClient()
                let sessionToken = try await reviewClient.signInForAppReview(email: emailForOTP)
                let refresh = try await reviewClient.fetchConvexAuthRefresh(sessionToken: sessionToken)
                persistSession(
                    StoredSession(
                        convexAuthToken: refresh.token,
                        betterAuthCookie: refresh.betterAuthCookie,
                        betterAuthSessionToken: sessionToken
                    )
                )
            } else {
                try await ConvexHTTPClient().sendEmailOTP(email: emailForOTP)
            }
        }
    }

    func verifyOTP(code: String) async {
        guard !code.isEmpty else {
            errorMessage = "Enter the verification code."
            return
        }
        await run {
            var unauthenticatedClient = ConvexHTTPClient()
            try await unauthenticatedClient.verifyEmailOTP(email: emailForOTP, otp: code)
            let refresh = try await unauthenticatedClient.fetchConvexAuthRefresh()
            persistSession(
                StoredSession(
                    convexAuthToken: refresh.token,
                    betterAuthCookie: refresh.betterAuthCookie ?? unauthenticatedClient.currentBetterAuthCookie,
                    betterAuthSessionToken: nil
                )
            )
        }
    }

    @discardableResult
    func restorePersistedSessionIfNeeded(forceRefresh: Bool = false) async -> Bool {
        guard hasRefreshCredential else {
            return token != nil
        }
        guard forceRefresh || token == nil else {
            return true
        }

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
                    betterAuthSessionToken: betterAuthSessionToken
                )
            )
            return true
        } catch {
            if isAuthenticationFailure(error) {
                clearSession(errorMessage: restoreFailureMessage(for: error))
                return false
            }

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
            betterAuthSessionToken: betterAuthSessionToken
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

    private func invalidateSession(message: String) {
        guard isAuthenticated else {
            return
        }

        clearSession(errorMessage: message)
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

    private func persistSession(_ session: StoredSession?) {
        token = session?.convexAuthToken
        betterAuthCookie = session?.betterAuthCookie
        betterAuthSessionToken = session?.betterAuthSessionToken
        if session == nil {
            launchedWithPersistedSession = false
        }
        sessionPersistence.saveSession(session)
    }

    private func storeRefreshedConvexToken(_ refreshedToken: String) {
        guard hasRefreshCredential else {
            return
        }

        persistSession(
            StoredSession(
                convexAuthToken: refreshedToken,
                betterAuthCookie: betterAuthCookie,
                betterAuthSessionToken: betterAuthSessionToken
            )
        )
    }

    private func storeRefreshedBetterAuthCookie(_ refreshedCookie: String) {
        guard !refreshedCookie.isEmpty else {
            return
        }

        persistSession(
            StoredSession(
                convexAuthToken: token,
                betterAuthCookie: refreshedCookie,
                betterAuthSessionToken: betterAuthSessionToken
            )
        )
    }

    private func clearSession(errorMessage: String?) {
        self.errorMessage = errorMessage
        emailForOTP = ""
        persistSession(nil)
    }

    private func restoreFailureMessage(for error: Error) -> String {
        if let patchworkError = error as? PatchworkError,
           let description = patchworkError.errorDescription,
           !description.isEmpty {
            if isAuthenticationFailure(description) {
                return "Your session expired. Sign in again."
            }
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty {
            if isAuthenticationFailure(description) {
                return "Your session expired. Sign in again."
            }
            return description
        }

        return "We couldn't restore your session. Sign in again."
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
