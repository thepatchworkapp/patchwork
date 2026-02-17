import Foundation

enum PatchworkError: LocalizedError {
    case server(String)
    case invalidResponse
    case missingToken

    var errorDescription: String? {
        switch self {
        case .server(let message):
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

    private let cloudURL: URL
    private let siteURL: URL
    private let session: URLSession

    init(
        cloudURL: URL = AppConfig.convexCloudURL,
        siteURL: URL = AppConfig.convexSiteURL,
        session: URLSession = .shared,
        authToken: String? = nil,
        betterAuthCookie: String? = nil
    ) {
        self.cloudURL = cloudURL
        self.siteURL = siteURL
        self.session = session
        self.authToken = authToken
        self.betterAuthCookie = betterAuthCookie
    }

    func query<T: Decodable>(_ path: String, args: [String: Any]) async throws -> T {
        try await call(functionType: "query", path: path, args: args)
    }

    func mutation<T: Decodable>(_ path: String, args: [String: Any], requiresAuth: Bool = true) async throws -> T {
        if requiresAuth && authToken == nil {
            throw PatchworkError.missingToken
        }
        return try await call(functionType: "mutation", path: path, args: args)
    }

    func sendEmailOTP(email: String) async throws {
        let payload: [String: Any] = ["email": email, "type": "sign-in"]
        try await postBetterAuth(path: "/api/auth/email-otp/send-verification-otp", payload: payload)
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

    func fetchConvexJWT() async throws -> String {
        var lastErrorMessage: String?

        for origin in betterAuthOrigins {
            var request = URLRequest(url: siteURL.appending(path: "/api/auth/convex/token"))
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(origin, forHTTPHeaderField: "Origin")
            request.httpShouldHandleCookies = false
            if let betterAuthCookie, !betterAuthCookie.isEmpty {
                request.setValue(betterAuthCookie, forHTTPHeaderField: "Better-Auth-Cookie")
            }

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PatchworkError.invalidResponse
            }

            if 200 ..< 300 ~= httpResponse.statusCode {
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let token = object?["token"] as? String {
                    return token
                }
                if let nested = object?["data"] as? [String: Any],
                   let token = nested["token"] as? String {
                    return token
                }
                throw PatchworkError.invalidResponse
            }

            let message = Self.errorMessage(from: data) ?? "Authentication request failed."
            lastErrorMessage = message
            if httpResponse.statusCode == 403,
               message.localizedCaseInsensitiveContains("invalid origin") {
                continue
            }
            throw PatchworkError.server(message)
        }

        throw PatchworkError.server(lastErrorMessage ?? "Authentication request failed.")
    }

    private func call<T: Decodable>(functionType: String, path: String, args: [String: Any]) async throws -> T {
        var request = URLRequest(url: cloudURL.appending(path: "/api/\(functionType)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "path": path,
            "args": args,
            "format": "json",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode else {
            throw PatchworkError.invalidResponse
        }

        let decoder = JSONDecoder()
        let envelope = try decoder.decode(ConvexEnvelope<T>.self, from: data)
        if envelope.status == "success", let value = envelope.value {
            return value
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

    private var betterAuthOrigin: String {
        var components = URLComponents(url: siteURL, resolvingAgainstBaseURL: false)
        components?.path = ""
        components?.query = nil
        components?.fragment = nil
        return components?.string ?? "https://aware-meerkat-572.convex.site"
    }

    private var betterAuthOrigins: [String] {
        var origins: [String] = [betterAuthOrigin, "https://admin.ddga.ltd", "https://patchwork-client-staging.pages.dev", "http://localhost:5173"]
        origins = origins.filter { !$0.isEmpty }
        var deduped: [String] = []
        for origin in origins where !deduped.contains(origin) {
            deduped.append(origin)
        }
        return deduped
    }
}
