import Foundation

enum PatchworkError: LocalizedError {
    case server(String)
    case authRefreshFailed(statusCode: Int, message: String)
    case invalidResponse
    case missingToken

    var errorDescription: String? {
        switch self {
        case .server(let message):
            return message
        case .authRefreshFailed(_, let message):
            return message
        case .invalidResponse:
            return "Unexpected response from server."
        case .missingToken:
            return "You are not authenticated."
        }
    }
}

struct ConvexHTTPClient {
    var authToken: String?
    private var betterAuthCookie: String?
    private let betterAuthSessionToken: String?
    private let onAuthTokenRefresh: (@Sendable (String) async -> Void)?
    private let onBetterAuthCookieRefresh: (@Sendable (String) async -> Void)?
    private let onAuthSessionInvalidated: (@Sendable (String) async -> Void)?

    private let cloudURL: URL
    private let siteURL: URL
    private let session: URLSession

    init(
        cloudURL: URL = AppConfig.convexCloudURL,
        siteURL: URL = AppConfig.convexSiteURL,
        session: URLSession = .shared,
        authToken: String? = nil,
        betterAuthCookie: String? = nil,
        betterAuthSessionToken: String? = nil,
        onAuthTokenRefresh: (@Sendable (String) async -> Void)? = nil,
        onBetterAuthCookieRefresh: (@Sendable (String) async -> Void)? = nil,
        onAuthSessionInvalidated: (@Sendable (String) async -> Void)? = nil
    ) {
        self.cloudURL = cloudURL
        self.siteURL = siteURL
        self.session = session
        self.authToken = authToken
        self.betterAuthCookie = betterAuthCookie
        self.betterAuthSessionToken = betterAuthSessionToken
        self.onAuthTokenRefresh = onAuthTokenRefresh
        self.onBetterAuthCookieRefresh = onBetterAuthCookieRefresh
        self.onAuthSessionInvalidated = onAuthSessionInvalidated
    }

    func query<T: Decodable>(_ path: String, args: [String: Any]) async throws -> T {
        try await call(functionType: "query", path: path, args: args)
    }

    func mutation<T: Decodable>(_ path: String, args: [String: Any], requiresAuth: Bool = true) async throws -> T {
        if requiresAuth && authToken == nil && !hasRefreshCredential {
            throw PatchworkError.missingToken
        }
        return try await call(functionType: "mutation", path: path, args: args)
    }

    func action<T: Decodable>(_ path: String, args: [String: Any], requiresAuth: Bool = true) async throws -> T {
        if requiresAuth && authToken == nil && !hasRefreshCredential {
            throw PatchworkError.missingToken
        }
        return try await call(functionType: "action", path: path, args: args)
    }

    func sendEmailOTP(email: String) async throws {
        let payload: [String: Any] = ["email": email, "type": "sign-in"]
        try await postBetterAuth(path: "/api/auth/email-otp/send-verification-otp", payload: payload)
    }

    func signInForAppReview(email: String) async throws -> String {
        var request = URLRequest(url: siteURL.appending(path: "/review/sign-in"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PatchworkError.invalidResponse
        }
        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw PatchworkError.server(Self.errorMessage(from: data) ?? "Authentication request failed.")
        }

        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let sessionToken = object?["sessionToken"] as? String, !sessionToken.isEmpty {
            return sessionToken
        }
        throw PatchworkError.invalidResponse
    }

    mutating func verifyEmailOTP(email: String, otp: String) async throws {
        let payload: [String: Any] = ["email": email, "otp": otp]
        var request = URLRequest(url: siteURL.appending(path: "/api/auth/sign-in/email-otp"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(betterAuthOrigin, forHTTPHeaderField: "Origin")
        request.httpShouldHandleCookies = false
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PatchworkError.invalidResponse
        }
        if let setBetterAuthCookie = httpResponse.value(forHTTPHeaderField: "Set-Better-Auth-Cookie") {
            let cookieHeader = Self.cookieHeaderFromSetCookieHeader(setBetterAuthCookie)
            if !cookieHeader.isEmpty {
                betterAuthCookie = cookieHeader
            }
        }
        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw PatchworkError.server(Self.errorMessage(from: data) ?? "Authentication request failed.")
        }
    }

    func signOut() async throws {
        guard hasRefreshCredential else {
            return
        }

        var request = URLRequest(url: siteURL.appending(path: "/api/auth/sign-out"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(betterAuthOrigin, forHTTPHeaderField: "Origin")
        request.httpShouldHandleCookies = false
        request.httpBody = Data("{}".utf8)

        if let betterAuthSessionToken, !betterAuthSessionToken.isEmpty {
            request.setValue("Bearer \(betterAuthSessionToken)", forHTTPHeaderField: "Authorization")
        } else if let betterAuthCookie, !betterAuthCookie.isEmpty {
            request.setValue(betterAuthCookie, forHTTPHeaderField: "Better-Auth-Cookie")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PatchworkError.invalidResponse
        }
        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw PatchworkError.server(Self.errorMessage(from: data) ?? "Sign out failed.")
        }
    }

    func fetchConvexJWT(sessionToken: String? = nil) async throws -> String {
        let refresh = try await fetchConvexAuthRefresh(sessionToken: sessionToken)
        if let refreshedCookie = refresh.betterAuthCookie {
            await onBetterAuthCookieRefresh?(refreshedCookie)
        }
        return refresh.token
    }

    func fetchConvexAuthRefresh(sessionToken: String? = nil) async throws -> ConvexAuthRefresh {
        var lastErrorMessage: String?
        let activeSessionToken = sessionToken ?? betterAuthSessionToken

        for origin in betterAuthOrigins {
            var request = URLRequest(url: siteURL.appending(path: "/api/auth/convex/token"))
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(origin, forHTTPHeaderField: "Origin")
            request.httpShouldHandleCookies = false
            if let activeSessionToken, !activeSessionToken.isEmpty {
                request.setValue("Bearer \(activeSessionToken)", forHTTPHeaderField: "Authorization")
            } else if let betterAuthCookie, !betterAuthCookie.isEmpty {
                request.setValue(betterAuthCookie, forHTTPHeaderField: "Better-Auth-Cookie")
            }

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PatchworkError.invalidResponse
            }

            if 200 ..< 300 ~= httpResponse.statusCode {
                let refreshedCookie = Self.betterAuthCookie(from: httpResponse)
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let token = object?["token"] as? String {
                    return ConvexAuthRefresh(token: token, betterAuthCookie: refreshedCookie)
                }
                if let nested = object?["data"] as? [String: Any],
                   let token = nested["token"] as? String {
                    return ConvexAuthRefresh(token: token, betterAuthCookie: refreshedCookie)
                }
                throw PatchworkError.invalidResponse
            }

            let message = Self.errorMessage(from: data) ?? "Authentication request failed."
            lastErrorMessage = message
            if httpResponse.statusCode == 401 {
                throw PatchworkError.authRefreshFailed(statusCode: httpResponse.statusCode, message: message)
            }
            if httpResponse.statusCode == 403,
               message.localizedCaseInsensitiveContains("invalid origin") {
                continue
            }

            throw PatchworkError.authRefreshFailed(statusCode: httpResponse.statusCode, message: message)
        }

        throw PatchworkError.authRefreshFailed(statusCode: 0, message: lastErrorMessage ?? "Authentication request failed.")
    }

    private func call<T: Decodable>(functionType: String, path: String, args: [String: Any]) async throws -> T {
        try await call(functionType: functionType, path: path, args: args, allowAuthRefresh: true)
    }

    private func call<T: Decodable>(
        functionType: String,
        path: String,
        args: [String: Any],
        allowAuthRefresh: Bool,
        authTokenOverride: String? = nil
    ) async throws -> T {
        var request = URLRequest(url: cloudURL.appending(path: "/api/\(functionType)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let authToken = try await bestAvailableAuthTokenForRequest(authTokenOverride: authTokenOverride) {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "path": path,
            "args": args,
            "format": "json",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PatchworkError.invalidResponse
        }

        let usedAuthHeader = request.value(forHTTPHeaderField: "Authorization") != nil

        if !(200 ..< 300 ~= httpResponse.statusCode) {
            let errorMessage = Self.errorMessage(from: data)
            if allowAuthRefresh,
               usedAuthHeader && shouldRetryAfterAuthFailure(statusCode: httpResponse.statusCode, errorMessage: errorMessage) {
                return try await retryAfterRefreshingAuth(
                    functionType: functionType,
                    path: path,
                    args: args
                )
            }
            throw PatchworkError.server(errorMessage ?? PatchworkError.invalidResponse.localizedDescription)
        }

        let decoder = JSONDecoder()
        let envelope: ConvexEnvelope<T>
        do {
            envelope = try decoder.decode(ConvexEnvelope<T>.self, from: data)
        } catch {
            if allowAuthRefresh,
               usedAuthHeader && shouldRetryAfterAuthFailure(statusCode: httpResponse.statusCode, errorMessage: nil) {
                return try await retryAfterRefreshingAuth(
                    functionType: functionType,
                    path: path,
                    args: args
                )
            }
            throw PatchworkError.invalidResponse
        }

        if envelope.status == "success" {
            if let value = envelope.value {
                return value
            }
            if let optionalType = T.self as? OptionalValue.Type {
                return optionalType.nilValue as! T
            }
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            throw PatchworkError.server("Expected response payload from \(path)")
        }
        if allowAuthRefresh,
           usedAuthHeader && shouldRetryAfterAuthFailure(statusCode: httpResponse.statusCode, errorMessage: envelope.errorMessage) {
            return try await retryAfterRefreshingAuth(
                functionType: functionType,
                path: path,
                args: args
            )
        }
        throw PatchworkError.server(envelope.errorMessage ?? "Unknown backend error")
    }

    private func postBetterAuth(path: String, payload: [String: Any]) async throws {
        var request = URLRequest(url: siteURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(betterAuthOrigin, forHTTPHeaderField: "Origin")
        request.httpShouldHandleCookies = false
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode else {
            throw PatchworkError.server(Self.errorMessage(from: data) ?? "Authentication request failed.")
        }
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let error = object["error"] as? String, !error.isEmpty {
            return error
        }
        if let message = object["message"] as? String, !message.isEmpty {
            return message
        }
        if let dataObject = object["data"] as? [String: Any],
           let message = dataObject["message"] as? String,
           !message.isEmpty {
            return message
        }
        return nil
    }

    private static func cookieHeaderFromSetCookieHeader(_ header: String) -> String {
        let cookieFields = ["Set-Cookie": header]
        let parsedCookies = HTTPCookie.cookies(withResponseHeaderFields: cookieFields, for: AppConfig.convexSiteURL)
        if !parsedCookies.isEmpty {
            return parsedCookies
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")
        }

        let fragments = header.split(separator: ",")
        let cookiePairs = fragments.compactMap { fragment -> String? in
            let firstSection = fragment.split(separator: ";", maxSplits: 1).first.map(String.init) ?? ""
            return firstSection.contains("=") ? firstSection.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        }
        return cookiePairs.joined(separator: "; ")
    }

    private static func betterAuthCookie(from response: HTTPURLResponse) -> String? {
        guard let setBetterAuthCookie = response.value(forHTTPHeaderField: "Set-Better-Auth-Cookie") else {
            return nil
        }

        let cookieHeader = cookieHeaderFromSetCookieHeader(setBetterAuthCookie)
        return cookieHeader.isEmpty ? nil : cookieHeader
    }

    private var betterAuthOrigin: String {
        var components = URLComponents(url: siteURL, resolvingAgainstBaseURL: false)
        components?.path = ""
        components?.query = nil
        components?.fragment = nil
        return components?.string ?? "https://vibrant-caribou-150.convex.site"
    }

    private var betterAuthOrigins: [String] {
        var origins: [String] = [betterAuthOrigin, "https://admin.ddga.ltd", "http://localhost:4321"]
        origins = origins.filter { !$0.isEmpty }
        var deduped: [String] = []
        for origin in origins where !deduped.contains(origin) {
            deduped.append(origin)
        }
        return deduped
    }

    var currentBetterAuthCookie: String? {
        betterAuthCookie
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

    private func bestAvailableAuthTokenForRequest(authTokenOverride: String?) async throws -> String? {
        if let authTokenOverride, !authTokenOverride.isEmpty {
            return authTokenOverride
        }

        if let authToken, !authToken.isEmpty {
            return authToken
        }

        guard hasRefreshCredential else {
            return nil
        }

        return try await refreshAuthToken()
    }

    private func retryAfterRefreshingAuth<T: Decodable>(
        functionType: String,
        path: String,
        args: [String: Any]
    ) async throws -> T {
        guard hasRefreshCredential else {
            throw PatchworkError.invalidResponse
        }

        let refreshedToken = try await refreshAuthToken()
        return try await call(
            functionType: functionType,
            path: path,
            args: args,
            allowAuthRefresh: false,
            authTokenOverride: refreshedToken
        )
    }

    private func refreshAuthToken() async throws -> String {
        let refreshedToken = try await fetchConvexJWT()
        await onAuthTokenRefresh?(refreshedToken)
        return refreshedToken
    }

    private func shouldRetryAfterAuthFailure(statusCode: Int, errorMessage: String?) -> Bool {
        guard hasRefreshCredential else {
            return false
        }

        if statusCode == 401 || statusCode == 403 {
            return true
        }

        if 200 ..< 300 ~= statusCode,
           Self.isGenericAuthenticationRequestFailure(errorMessage) {
            return true
        }

        return authFailurePhrase(in: errorMessage) != nil
    }

    private static func isGenericAuthenticationRequestFailure(_ errorMessage: String?) -> Bool {
        guard let errorMessage else {
            return false
        }

        let normalized = errorMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized == "authentication request failed." || normalized == "authentication request failed"
    }

    private func authFailurePhrase(in errorMessage: String?) -> String? {
        guard let errorMessage else {
            return nil
        }

        let normalized = errorMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if Self.isGenericAuthenticationRequestFailure(errorMessage) {
            return nil
        }

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
        return authFailurePhrases.first(where: { normalized.contains($0) })
    }
}

struct ConvexAuthRefresh {
    let token: String
    let betterAuthCookie: String?
}

private protocol OptionalValue {
    static var nilValue: Any { get }
}

extension Optional: OptionalValue {
    static var nilValue: Any { Self.none as Any }
}

struct EmptyResponse: Decodable {}
