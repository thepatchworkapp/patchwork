import Foundation
import XCTest
@testable import Patchwork

final class PatchworkTests: XCTestCase {
    override func tearDown() {
        TestURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testVerifyOTPPropagatesBetterAuthCookieToConvexTokenRequest() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""
            switch path {
            case "/api/auth/sign-in/email-otp":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://aware-meerkat-572.convex.site")
                XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
                let data = Data("{}".utf8)
                let response = try XCTUnwrap(
                    HTTPURLResponse(
                        url: try XCTUnwrap(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Set-Better-Auth-Cookie": "foo=bar; Path=/; HttpOnly, baz=qux; Path=/"]
                    )
                )
                return (response, data)
            case "/api/auth/convex/token":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://aware-meerkat-572.convex.site")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "foo=bar; baz=qux")
                let data = Data("{\"token\":\"jwt-token\"}".utf8)
                let response = try XCTUnwrap(
                    HTTPURLResponse(
                        url: try XCTUnwrap(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )
                )
                return (response, data)
            default:
                XCTFail("Unexpected request path: \(path)")
                throw PatchworkError.invalidResponse
            }
        }

        var client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session)
        try await client.verifyEmailOTP(email: "user@example.com", otp: "123456")
        let token = try await client.fetchConvexJWT()

        XCTAssertEqual(token, "jwt-token")
    }

    func testVerifyOTPIgnoresStoredCookieJarBetweenAttempts() async throws {
        let session = makeMockSession(withStoredCookie: true)
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        var verifyCallCount = 0
        TestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""
            if path == "/api/auth/sign-in/email-otp" {
                verifyCallCount += 1
                XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
                let data = Data("{}".utf8)
                let response = try XCTUnwrap(
                    HTTPURLResponse(
                        url: try XCTUnwrap(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: [
                            "Set-Better-Auth-Cookie": "session=abc; Path=/; HttpOnly",
                            "Set-Cookie": "better-auth.convex_jwt=jwt-cookie; Path=/",
                        ]
                    )
                )
                return (response, data)
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{}".utf8))
        }

        var client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session)
        try await client.verifyEmailOTP(email: "user@example.com", otp: "111111")
        try await client.verifyEmailOTP(email: "user@example.com", otp: "222222")

        XCTAssertEqual(verifyCallCount, 2)
    }

    func testVerifyOTPShowsServerErrorMessage() async {
        let session = makeMockSession()
        let cloudURL = URL(string: "https://aware-meerkat-572.convex.cloud")!
        let siteURL = URL(string: "https://aware-meerkat-572.convex.site")!

        TestURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data("{\"error\":\"Invalid OTP\"}".utf8)
            return (response, data)
        }

        var client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session)

        do {
            try await client.verifyEmailOTP(email: "user@example.com", otp: "000000")
            XCTFail("Expected verifyEmailOTP to throw")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Invalid OTP")
        }
    }

    func testFetchConvexJWTFallsBackToTrustedOriginWhenFirstOriginRejected() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        var tokenRequestOrigins: [String] = []
        TestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""
            if path == "/api/auth/sign-in/email-otp" {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Set-Better-Auth-Cookie": "session=abc; Path=/; HttpOnly"]
                )!
                return (response, Data("{}".utf8))
            }

            if path == "/api/auth/convex/token" {
                let origin = request.value(forHTTPHeaderField: "Origin") ?? ""
                tokenRequestOrigins.append(origin)
                if origin == "https://aware-meerkat-572.convex.site" {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 403,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (response, Data("{\"error\":\"Invalid origin\"}".utf8))
                }

                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, Data("{\"token\":\"fallback-jwt\"}".utf8))
            }

            throw PatchworkError.invalidResponse
        }

        var client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session)
        try await client.verifyEmailOTP(email: "user@example.com", otp: "123456")
        let token = try await client.fetchConvexJWT()

        XCTAssertEqual(token, "fallback-jwt")
        XCTAssertEqual(tokenRequestOrigins.prefix(2), ["https://aware-meerkat-572.convex.site", "https://admin.ddga.ltd"])
    }

    private func makeMockSession(withStoredCookie: Bool = false) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        if withStoredCookie {
            let storage = HTTPCookieStorage()
            if let cookie = HTTPCookie(properties: [
                .domain: "aware-meerkat-572.convex.site",
                .path: "/",
                .name: "better-auth.session_token",
                .value: "stale-cookie",
                .secure: true,
            ]) {
                storage.setCookie(cookie)
            }
            configuration.httpCookieStorage = storage
        }
        return URLSession(configuration: configuration)
    }
}

private final class TestURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme?.hasPrefix("http") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: PatchworkError.invalidResponse)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
