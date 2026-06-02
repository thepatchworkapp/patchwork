import Foundation
import XCTest
@testable import Patchwork

final class PatchworkTests: XCTestCase {
    override func tearDown() {
        TestURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testRootLoadingPolicyPreservesBootstrappedCurrentUserDuringSessionRestore() {
        let policy = RootLoadingPolicy(
            isAuthenticated: true,
            isRestoringSession: true,
            needsSessionRestore: false,
            hasAttemptedSessionRestore: true,
            isForegroundRefreshPending: false,
            isBootstrapped: true,
            hasCurrentUser: true,
            launchedWithPersistedSession: true,
            hasConfirmedMissingCurrentUser: false,
            hasFailedCurrentUserRefreshWithoutPrevious: false
        )

        XCTAssertFalse(policy.shouldShowSessionRestoreLoading)
        XCTAssertFalse(policy.shouldShowForegroundRefreshLoading)
    }

    func testRootLoadingPolicyPreservesBootstrappedCurrentUserDuringNeededSessionRestore() {
        let policy = RootLoadingPolicy(
            isAuthenticated: true,
            isRestoringSession: false,
            needsSessionRestore: true,
            hasAttemptedSessionRestore: true,
            isForegroundRefreshPending: false,
            isBootstrapped: true,
            hasCurrentUser: true,
            launchedWithPersistedSession: true,
            hasConfirmedMissingCurrentUser: false,
            hasFailedCurrentUserRefreshWithoutPrevious: false
        )

        XCTAssertFalse(policy.shouldShowSessionRestoreLoading)
    }

    func testRootLoadingPolicyWaitsForPersistedSessionWithoutCurrentUser() {
        let policy = RootLoadingPolicy(
            isAuthenticated: true,
            isRestoringSession: true,
            needsSessionRestore: false,
            hasAttemptedSessionRestore: true,
            isForegroundRefreshPending: false,
            isBootstrapped: true,
            hasCurrentUser: false,
            launchedWithPersistedSession: true,
            hasConfirmedMissingCurrentUser: false,
            hasFailedCurrentUserRefreshWithoutPrevious: false
        )

        XCTAssertTrue(policy.shouldShowSessionRestoreLoading)
    }

    func testRootLoadingPolicyPreservesForegroundRefreshForFreshAuthenticatedRoute() {
        let policy = RootLoadingPolicy(
            isAuthenticated: true,
            isRestoringSession: true,
            needsSessionRestore: false,
            hasAttemptedSessionRestore: true,
            isForegroundRefreshPending: true,
            isBootstrapped: true,
            hasCurrentUser: false,
            launchedWithPersistedSession: false,
            hasConfirmedMissingCurrentUser: false,
            hasFailedCurrentUserRefreshWithoutPrevious: false
        )

        XCTAssertFalse(policy.shouldShowForegroundRefreshLoading)
        XCTAssertFalse(policy.shouldShowSessionRestoreLoading)
    }

    func testRootLoadingPolicyBlocksBeforeInitialRestoreAttemptWithoutToken() {
        let policy = RootLoadingPolicy(
            isAuthenticated: true,
            isRestoringSession: false,
            needsSessionRestore: true,
            hasAttemptedSessionRestore: false,
            isForegroundRefreshPending: false,
            isBootstrapped: false,
            hasCurrentUser: false,
            launchedWithPersistedSession: true,
            hasConfirmedMissingCurrentUser: false,
            hasFailedCurrentUserRefreshWithoutPrevious: false
        )

        XCTAssertTrue(policy.shouldShowSessionRestoreLoading)
    }

    func testRootLoadingPolicyStopsBlockingAfterRestoreAttemptFailsWithoutToken() {
        let policy = RootLoadingPolicy(
            isAuthenticated: true,
            isRestoringSession: false,
            needsSessionRestore: true,
            hasAttemptedSessionRestore: true,
            isForegroundRefreshPending: false,
            isBootstrapped: false,
            hasCurrentUser: false,
            launchedWithPersistedSession: true,
            hasConfirmedMissingCurrentUser: false,
            hasFailedCurrentUserRefreshWithoutPrevious: false
        )

        XCTAssertFalse(policy.shouldShowSessionRestoreLoading)
    }

    func testRootLoadingPolicyStopsWaitingWhenPersistedCurrentUserFetchFails() {
        let policy = RootLoadingPolicy(
            isAuthenticated: true,
            isRestoringSession: false,
            needsSessionRestore: false,
            hasAttemptedSessionRestore: true,
            isForegroundRefreshPending: false,
            isBootstrapped: true,
            hasCurrentUser: false,
            launchedWithPersistedSession: true,
            hasConfirmedMissingCurrentUser: false,
            hasFailedCurrentUserRefreshWithoutPrevious: true
        )

        XCTAssertFalse(policy.shouldShowPersistedCurrentUserResolutionLoading)
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

    func testSignOutUsesBetterAuthCookieForServerInvalidation() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/sign-out")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://aware-meerkat-572.convex.site")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "session=abc")
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            XCTAssertEqual(Self.requestBody(from: request), Data("{}".utf8))

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("{}".utf8))
        }

        let client = ConvexHTTPClient(
            cloudURL: cloudURL,
            siteURL: siteURL,
            session: session,
            authToken: "jwt-token",
            betterAuthCookie: "session=abc"
        )

        try await client.signOut()
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

    func testFetchConvexJWTPublishesRefreshedBetterAuthCookie() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))
        let refreshedCookie = LockedBox<String?>(nil)

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "session=old")

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: [
                        "Content-Type": "application/json",
                        "Set-Better-Auth-Cookie": "session=new; Path=/; HttpOnly",
                    ]
                )
            )
            return (response, Data("{\"token\":\"fresh-jwt\"}".utf8))
        }

        let client = ConvexHTTPClient(
            cloudURL: cloudURL,
            siteURL: siteURL,
            session: session,
            betterAuthCookie: "session=old",
            onBetterAuthCookieRefresh: { cookie in
                refreshedCookie.set(cookie)
            }
        )

        let token = try await client.fetchConvexJWT()

        XCTAssertEqual(token, "fresh-jwt")
        XCTAssertEqual(refreshedCookie.get(), "session=new")
    }

    func testSignInForAppReviewPostsToReviewEndpoint() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/review/sign-in")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try XCTUnwrap(Self.requestBody(from: request))
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(payload["email"] as? String, "review@apple.com")

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("{\"sessionToken\":\"review-session-token\"}".utf8))
        }

        let client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session)
        let sessionToken = try await client.signInForAppReview(email: "review@apple.com")

        XCTAssertEqual(sessionToken, "review-session-token")
    }

    func testPatchworkAPISearchTaskersBuildsTypedQuery() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/query")
            let body = try XCTUnwrap(Self.requestBody(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["path"] as? String, "search:searchTaskers")
            let args = try XCTUnwrap(object["args"] as? [String: Any])
            XCTAssertEqual(args["lat"] as? Double, 43.6532)
            XCTAssertEqual(args["lng"] as? Double, -79.3832)
            XCTAssertEqual(args["radiusKm"] as? Int, 15)
            XCTAssertEqual(args["limit"] as? Int, 25)
            XCTAssertEqual(args["categorySlug"] as? String, "plumbing")
            XCTAssertEqual(args["excludeUserId"] as? String, "user_123")

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("{\"status\":\"success\",\"value\":[]}".utf8))
        }

        let client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session, authToken: "test-token")
        let api = PatchworkAPI(client: client)

        let taskers = try await api.search.taskers(
            lat: 43.6532,
            lng: -79.3832,
            radiusKm: 15,
            limit: 25,
            categorySlug: "plumbing",
            excludeUserId: "user_123"
        )

        XCTAssertEqual(taskers, [])
    }

    func testPatchworkAPISearchTaskersOmitsNilOptionalArguments() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/query")
            let body = try XCTUnwrap(Self.requestBody(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["path"] as? String, "search:searchTaskers")
            let args = try XCTUnwrap(object["args"] as? [String: Any])
            XCTAssertNil(args["categorySlug"])
            XCTAssertNil(args["excludeUserId"])

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("{\"status\":\"success\",\"value\":[]}".utf8))
        }

        let client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session, authToken: "test-token")
        let api = PatchworkAPI(client: client)

        let taskers = try await api.search.taskers(
            lat: 43.6532,
            lng: -79.3832,
            radiusKm: 15,
            categorySlug: nil,
            excludeUserId: nil
        )

        XCTAssertEqual(taskers, [])
    }

    func testPatchworkAPIUpdateLocationUsesConvexMutation() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/mutation")
            let body = try XCTUnwrap(Self.requestBody(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["path"] as? String, "users:updateLocation")
            let args = try XCTUnwrap(object["args"] as? [String: Any])
            XCTAssertEqual(args["lat"] as? Double, 43.6532)
            XCTAssertEqual(args["lng"] as? Double, -79.3832)
            XCTAssertEqual(args["source"] as? String, "manual")

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("{\"status\":\"success\",\"value\":\"location_123\"}".utf8))
        }

        let client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session, authToken: "test-token")
        let api = PatchworkAPI(client: client)

        let locationId = try await api.users.updateLocation(
            lat: 43.6532,
            lng: -79.3832,
            source: "manual"
        )

        XCTAssertEqual(locationId, "location_123")
    }

    @MainActor
    func testAppReviewShortcutRecognizesSeekerEmail() {
        let store = SessionStore()

        store.emailForOTP = "seeker@apple.com"
        XCTAssertTrue(store.usesAppReviewShortcut)

        store.emailForOTP = "someone@example.com"
        XCTAssertFalse(store.usesAppReviewShortcut)
    }

    func testFetchConvexJWTUsesBearerTokenForAppReviewSession() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer review-session-token")
            XCTAssertNil(request.value(forHTTPHeaderField: "Better-Auth-Cookie"))

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("{\"token\":\"review-convex-jwt\"}".utf8))
        }

        let client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session)
        let token = try await client.fetchConvexJWT(sessionToken: "review-session-token")

        XCTAssertEqual(token, "review-convex-jwt")
    }

    func testQueryRefreshesExpiredConvexTokenAndRetriesOnce() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        var observedAuthorizations: [String] = []
        let refreshedToken = LockedBox<String?>(nil)

        TestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""
            switch path {
            case "/api/query":
                let authorization = request.value(forHTTPHeaderField: "Authorization") ?? ""
                observedAuthorizations.append(authorization)

                if authorization == "Bearer expired-token" {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 401,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (response, Data("{\"error\":\"Unauthorized\"}".utf8))
                }

                XCTAssertEqual(authorization, "Bearer fresh-token")
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, Data("{\"status\":\"success\",\"value\":[]}".utf8))
            case "/api/auth/convex/token":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "session=abc")
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, Data("{\"token\":\"fresh-token\"}".utf8))
            default:
                throw PatchworkError.invalidResponse
            }
        }

        let client = ConvexHTTPClient(
            cloudURL: cloudURL,
            siteURL: siteURL,
            session: session,
            authToken: "expired-token",
            betterAuthCookie: "session=abc",
            onAuthTokenRefresh: { token in
                refreshedToken.set(token)
            }
        )

        let jobs: [String] = try await client.query("jobs:listJobs", args: [:])

        XCTAssertEqual(jobs, [])
        XCTAssertEqual(observedAuthorizations, ["Bearer expired-token", "Bearer fresh-token"])
        XCTAssertEqual(refreshedToken.get(), "fresh-token")
    }

    func testQueryDoesNotInvalidateAuthSessionOnUnrecoverableAuthRefreshFailure() async {
        let session = makeMockSession()
        let cloudURL = try! XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try! XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        let invalidationMessage = LockedBox<String?>(nil)

        TestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""
            switch path {
            case "/api/query":
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, Data("{\"error\":\"Unauthorized\"}".utf8))
            case "/api/auth/convex/token":
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, Data("{\"error\":\"Unauthorized\"}".utf8))
            default:
                throw PatchworkError.invalidResponse
            }
        }

        let client = ConvexHTTPClient(
            cloudURL: cloudURL,
            siteURL: siteURL,
            session: session,
            authToken: "expired-token",
            betterAuthCookie: "session=abc",
            onAuthSessionInvalidated: { message in
                invalidationMessage.set(message)
            }
        )

        do {
            let _: [String] = try await client.query("jobs:listJobs", args: [:])
            XCTFail("Expected query to fail")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Unauthorized")
            XCTAssertNil(invalidationMessage.get())
        }
    }

    func testQueryDoesNotInvalidateSessionOnBackendEnvelopeUnauthorizedAfterRefresh() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        let invalidationMessage = LockedBox<String?>(nil)
        let requestAuthorizations = LockedArrayBox<String>()

        TestURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/api/query":
                requestAuthorizations.append(request.value(forHTTPHeaderField: "Authorization") ?? "")
                let response = try XCTUnwrap(
                    HTTPURLResponse(
                        url: try XCTUnwrap(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )
                )
                return (response, Data("{\"status\":\"error\",\"errorMessage\":\"Unauthorized\"}".utf8))
            case "/api/auth/convex/token":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "session=abc")
                let response = try XCTUnwrap(
                    HTTPURLResponse(
                        url: try XCTUnwrap(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )
                )
                return (response, Data("{\"token\":\"fresh-token\"}".utf8))
            default:
                throw PatchworkError.invalidResponse
            }
        }

        let client = ConvexHTTPClient(
            cloudURL: cloudURL,
            siteURL: siteURL,
            session: session,
            authToken: "expired-token",
            betterAuthCookie: "session=abc",
            onAuthSessionInvalidated: { message in
                invalidationMessage.set(message)
            }
        )

        do {
            let _: [String] = try await client.query("jobs:listJobs", args: [:])
            XCTFail("Expected query to fail")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Unauthorized")
            XCTAssertNil(invalidationMessage.get())
            XCTAssertEqual(requestAuthorizations.get(), ["Bearer expired-token", "Bearer fresh-token"])
        }
    }

    func testQueryDoesNotInvalidateSessionOnGenericBackendFailure() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        let invalidationMessage = LockedBox<String?>(nil)

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/query")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"Authentication request failed.\"}".utf8))
        }

        let client = ConvexHTTPClient(
            cloudURL: cloudURL,
            siteURL: siteURL,
            session: session,
            authToken: "expired-token",
            betterAuthCookie: "session=abc",
            onAuthSessionInvalidated: { message in
                invalidationMessage.set(message)
            }
        )

        do {
            let _: [String] = try await client.query("jobs:listJobs", args: [:])
            XCTFail("Expected query to fail")
        } catch {
            XCTAssertNil(invalidationMessage.get())
        }
    }

    func testFetchConvexAuthRefreshDoesNotInvalidateSessionOnGenericAuthRequestFailure() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        let invalidationMessage = LockedBox<String?>(nil)

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "session=abc")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"Authentication request failed.\"}".utf8))
        }

        let client = ConvexHTTPClient(
            cloudURL: cloudURL,
            siteURL: siteURL,
            session: session,
            authToken: "existing-token",
            betterAuthCookie: "session=abc",
            onAuthSessionInvalidated: { message in
                invalidationMessage.set(message)
            }
        )

        do {
            _ = try await client.fetchConvexJWT()
            XCTFail("Expected refresh to fail")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Authentication request failed.")
            XCTAssertNil(invalidationMessage.get())
        }
    }

    func testFetchConvexAuthRefreshDoesNotInvalidateSessionOnGenericUnauthorizedAuthRequestFailureWithExistingToken() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        let invalidationMessage = LockedBox<String?>(nil)

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "session=abc")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"Authentication request failed.\"}".utf8))
        }

        let client = ConvexHTTPClient(
            cloudURL: cloudURL,
            siteURL: siteURL,
            session: session,
            authToken: "existing-token",
            betterAuthCookie: "session=abc",
            onAuthSessionInvalidated: { message in
                invalidationMessage.set(message)
            }
        )

        do {
            _ = try await client.fetchConvexJWT()
            XCTFail("Expected refresh to fail")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Authentication request failed.")
            XCTAssertNil(invalidationMessage.get())
        }
    }

    func testQueryDoesNotInvalidateSessionOnBusinessErrorThatMentionsToken() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        let invalidationMessage = LockedBox<String?>(nil)
        let requestPaths = LockedArrayBox<String>()

        TestURLProtocol.requestHandler = { request in
            requestPaths.append(request.url?.path ?? "")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"Token rewards are temporarily unavailable.\"}".utf8))
        }

        let client = ConvexHTTPClient(
            cloudURL: cloudURL,
            siteURL: siteURL,
            session: session,
            authToken: "expired-token",
            betterAuthCookie: "session=abc",
            onAuthSessionInvalidated: { message in
                invalidationMessage.set(message)
            }
        )

        do {
            let _: [String] = try await client.query("jobs:listJobs", args: [:])
            XCTFail("Expected query to fail")
        } catch {
            XCTAssertNil(invalidationMessage.get())
            XCTAssertEqual(requestPaths.get(), ["/api/query"])
        }
    }

    @MainActor
    func testSessionStoreRestoresPersistedSessionUsingBetterAuthCredential() async throws {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: nil,
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil
            )
        )
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "session=abc")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [
                    "Content-Type": "application/json",
                    "Set-Better-Auth-Cookie": "session=renewed; Path=/; HttpOnly",
                ]
            )!
            return (response, Data("{\"token\":\"restored-jwt\"}".utf8))
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertTrue(store.needsSessionRestore)

        let restored = await store.restorePersistedSessionIfNeeded(forceRefresh: false)

        XCTAssertTrue(restored)
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertFalse(store.needsSessionRestore)
        XCTAssertEqual(store.token, "restored-jwt")
        XCTAssertEqual(persistence.session?.convexAuthToken, "restored-jwt")
        XCTAssertEqual(persistence.session?.betterAuthCookie, "session=renewed")
    }

    @MainActor
    func testSessionStoreKeepsAgedUnexpiredPersistedConvexTokenWithoutRefresh() async throws {
        let existingToken = Self.makeJWT(expiration: Date().addingTimeInterval(60 * 60 * 24))
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: existingToken,
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil,
                convexAuthTokenRefreshedAt: Date().addingTimeInterval(-7 * 60 * 60)
            )
        )
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTFail("Unexpired token should not refresh because of stored age, but requested \(request.url?.path ?? "")")
            throw PatchworkError.invalidResponse
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        let restored = await store.restorePersistedSessionIfNeeded(forceRefresh: false)

        XCTAssertTrue(restored)
        XCTAssertEqual(store.token, existingToken)
        XCTAssertEqual(persistence.session?.convexAuthToken, existingToken)
        XCTAssertEqual(persistence.session?.betterAuthCookie, "session=abc")
    }

    @MainActor
    func testSessionStoreRefreshesPersistedConvexTokenNearExpiry() async throws {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: Self.makeJWT(expiration: Date().addingTimeInterval(60)),
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil,
                convexAuthTokenRefreshedAt: Date()
            )
        )
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))
        let refreshedAtBeforeRestore = Date()

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "session=abc")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [
                    "Content-Type": "application/json",
                    "Set-Better-Auth-Cookie": "session=renewed; Path=/; HttpOnly",
                ]
            )!
            return (response, Data("{\"token\":\"fresh-jwt\"}".utf8))
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        let restored = await store.restorePersistedSessionIfNeeded(forceRefresh: false)

        XCTAssertTrue(restored)
        XCTAssertEqual(store.token, "fresh-jwt")
        XCTAssertEqual(persistence.session?.betterAuthCookie, "session=renewed")
        XCTAssertGreaterThanOrEqual(
            persistence.session?.convexAuthTokenRefreshedAt ?? .distantPast,
            refreshedAtBeforeRestore
        )
    }

    @MainActor
    func testSessionStoreKeepsFreshOneHourTokenWithoutRefresh() async throws {
        let existingToken = Self.makeJWT(expiration: Date().addingTimeInterval(60 * 60))
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: existingToken,
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil,
                convexAuthTokenRefreshedAt: Date()
            )
        )
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTFail("Fresh token should not refresh, but requested \(request.url?.path ?? "")")
            throw PatchworkError.invalidResponse
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        let restored = await store.restorePersistedSessionIfNeeded(forceRefresh: false)

        XCTAssertTrue(restored)
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.token, existingToken)
        XCTAssertEqual(persistence.session?.convexAuthToken, existingToken)
        XCTAssertNil(store.errorMessage)
    }

    @MainActor
    func testSessionStoreKeepsMostRecentThreeLoginEmails() async throws {
        let persistence = InMemorySessionPersistence()
        let emailPersistence = InMemoryRecentEmailPersistence(
            emails: ["old@example.com", "existing@example.com", "extra@example.com"]
        )
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            switch request.url?.path ?? "" {
            case "/api/auth/sign-in/email-otp":
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Set-Better-Auth-Cookie": "session=abc; Path=/; HttpOnly"]
                )!
                return (response, Data("{}".utf8))
            case "/api/auth/convex/token":
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, Data("{\"token\":\"jwt-token\"}".utf8))
            default:
                XCTFail("Unexpected request path: \(request.url?.path ?? "")")
                throw PatchworkError.invalidResponse
            }
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            recentEmailPersistence: emailPersistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        store.emailForOTP = " Existing@Example.com "
        await store.verifyOTP(code: "123456")

        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.recentEmails, ["existing@example.com", "old@example.com", "extra@example.com"])
        XCTAssertEqual(emailPersistence.emails, store.recentEmails)
    }

    @MainActor
    func testSessionStoreLoadsCachedCurrentUserFromPersistedSession() {
        let cachedUser = Self.makeCurrentUser(id: "user_cached")
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: "existing-token",
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil,
                currentUser: cachedUser
            )
        )

        let store = SessionStore(sessionPersistence: persistence)

        XCTAssertEqual(store.cachedCurrentUser, cachedUser)
        XCTAssertTrue(store.launchedWithPersistedSession)
    }

    @MainActor
    func testSessionStorePreservesCachedCurrentUserAcrossTokenRefresh() async throws {
        let cachedUser = Self.makeCurrentUser(id: "user_preserved")
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: nil,
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil,
                currentUser: cachedUser
            )
        )
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"token\":\"fresh-token\"}".utf8))
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        let restored = await store.restorePersistedSessionIfNeeded(forceRefresh: true)

        XCTAssertTrue(restored)
        XCTAssertEqual(store.token, "fresh-token")
        XCTAssertEqual(store.cachedCurrentUser, cachedUser)
        XCTAssertEqual(persistence.session?.currentUser, cachedUser)
    }

    @MainActor
    func testRestoreKeepsSessionOnNonAuthRefreshFailure() async throws {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: "expired-token",
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil
            )
        )
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"Service temporarily unavailable.\"}".utf8))
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        let restored = await store.restorePersistedSessionIfNeeded(forceRefresh: true)

        XCTAssertTrue(restored)
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(persistence.session?.convexAuthToken, "expired-token")
    }

    @MainActor
    func testRestoreKeepsSessionOnGenericAuthRequestFailure() async throws {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: "existing-token",
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil
            )
        )
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "session=abc")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"Authentication request failed.\"}".utf8))
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        let restored = await store.restorePersistedSessionIfNeeded(forceRefresh: true)

        XCTAssertTrue(restored)
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(persistence.session?.convexAuthToken, "existing-token")
    }

    @MainActor
    func testRestoreKeepsSessionWhenTransientRefreshFailsWithoutActiveToken() async throws {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: nil,
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil
            )
        )
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"Service temporarily unavailable.\"}".utf8))
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        let restored = await store.restorePersistedSessionIfNeeded(forceRefresh: true)

        XCTAssertFalse(restored)
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.errorMessage, "We couldn't refresh your session. We'll keep trying.")
        XCTAssertNil(store.token)
        XCTAssertTrue(store.hasAttemptedSessionRestore)
        XCTAssertFalse(store.hasTerminalSessionRestoreFailure)
        XCTAssertEqual(persistence.session?.betterAuthCookie, "session=abc")
    }

    @MainActor
    func testRestoreClearsSessionWhenUnauthorizedRefreshFailsWithoutActiveToken() async throws {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: nil,
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil
            )
        )
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "session=abc")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"Unauthorized\"}".utf8))
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        let restored = await store.restorePersistedSessionIfNeeded(forceRefresh: true)

        XCTAssertFalse(restored)
        XCTAssertFalse(store.isAuthenticated)
        XCTAssertFalse(store.needsSessionRestore)
        XCTAssertNil(store.errorMessage)
        XCTAssertNil(store.token)
        XCTAssertFalse(store.hasTerminalSessionRestoreFailure)
        XCTAssertNil(persistence.session)
    }

    @MainActor
    func testRestoreKeepsSessionWhenRefreshIsUnauthorized() async {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: "expired-token",
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil
            )
        )
        let session = makeMockSession()
        let cloudURL = try! XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try! XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"Unauthorized\"}".utf8))
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        let restored = await store.restorePersistedSessionIfNeeded(forceRefresh: true)

        XCTAssertTrue(restored)
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.token, "expired-token")
        XCTAssertEqual(persistence.session?.convexAuthToken, "expired-token")
        XCTAssertEqual(persistence.session?.betterAuthCookie, "session=abc")
    }

    @MainActor
    func testRestorePreservesUsableJWTWhenRefreshIsUnauthorized() async throws {
        let existingToken = Self.makeJWT(expiration: Date().addingTimeInterval(60 * 60))
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: existingToken,
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil,
                convexAuthTokenRefreshedAt: Date()
            )
        )
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "session=abc")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"Unauthorized\"}".utf8))
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        let restored = await store.restorePersistedSessionIfNeeded(forceRefresh: true)

        XCTAssertTrue(restored)
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.token, existingToken)
        XCTAssertEqual(persistence.session?.convexAuthToken, existingToken)
        XCTAssertEqual(persistence.session?.betterAuthCookie, "session=abc")
        XCTAssertNil(store.errorMessage)
        XCTAssertTrue(store.hasTerminalSessionRestoreFailure)
    }

    @MainActor
    func testRestoreKeepsSessionWhenRefreshReturnsGenericUnauthorized() async {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: "expired-token",
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil
            )
        )
        let session = makeMockSession()
        let cloudURL = try! XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try! XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"Authentication request failed.\"}".utf8))
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        let restored = await store.restorePersistedSessionIfNeeded(forceRefresh: true)

        XCTAssertTrue(restored)
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.token, "expired-token")
        XCTAssertEqual(persistence.session?.convexAuthToken, "expired-token")
        XCTAssertEqual(persistence.session?.betterAuthCookie, "session=abc")
        XCTAssertTrue(store.hasTerminalSessionRestoreFailure)
    }

    @MainActor
    func testForegroundRefreshKeepsValidSessionWhenGenericAuthRefreshReturnsUnauthorized() async throws {
        let existingToken = Self.makeJWT(expiration: Date().addingTimeInterval(60 * 60))
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: existingToken,
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil,
                convexAuthTokenRefreshedAt: Date()
            )
        )
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/convex/token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "session=abc")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"Authentication request failed.\"}".utf8))
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        let restored = await store.restorePersistedSessionIfNeeded(forceRefresh: true)

        XCTAssertTrue(restored)
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.token, existingToken)
        XCTAssertEqual(persistence.session?.convexAuthToken, existingToken)
        XCTAssertEqual(persistence.session?.betterAuthCookie, "session=abc")
        XCTAssertNil(store.errorMessage)
    }

    @MainActor
    func testSignOutIgnoresLateTokenRefreshCallback() async {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: "expired-token",
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil
            )
        )
        var refreshCallback: (@Sendable (String) async -> Void)?

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                refreshCallback = onAuthTokenRefresh
                return ConvexHTTPClient(
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        _ = store.client
        await store.signOut()
        await refreshCallback?("fresh-token")

        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNil(store.token)
        XCTAssertNil(persistence.session)
    }

    @MainActor
    func testSessionStoreNotifiesRealtimeAuthListenersWhenHTTPTokenRefreshes() async {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: "expired-token",
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil
            )
        )
        let observedTokens = LockedArrayBox<String?>()
        var refreshCallback: (@Sendable (String) async -> Void)?

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                refreshCallback = onAuthTokenRefresh
                return ConvexHTTPClient(
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )
        store.addConvexAuthTokenListener { token in
            observedTokens.append(token)
        }

        _ = store.client
        await refreshCallback?("fresh-token")

        XCTAssertEqual(observedTokens.get(), ["fresh-token"])
        XCTAssertEqual(store.token, "fresh-token")
        XCTAssertEqual(persistence.session?.convexAuthToken, "fresh-token")
    }

    @MainActor
    func testSessionStoreIgnoresStaleInvalidationAfterHTTPTokenRefreshes() async {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: "expired-token",
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil
            )
        )
        let observedTokens = LockedArrayBox<String?>()
        var refreshCallback: (@Sendable (String) async -> Void)?
        var invalidationCallback: (@Sendable (String) async -> Void)?

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                if refreshCallback == nil {
                    refreshCallback = onAuthTokenRefresh
                }
                if invalidationCallback == nil {
                    invalidationCallback = onAuthSessionInvalidated
                }
                return ConvexHTTPClient(
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )
        store.addConvexAuthTokenListener { token in
            observedTokens.append(token)
        }

        _ = store.client
        await refreshCallback?("fresh-token")

        XCTAssertNil(invalidationCallback)
        XCTAssertEqual(observedTokens.get(), ["fresh-token"])
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.token, "fresh-token")
        XCTAssertEqual(persistence.session?.convexAuthToken, "fresh-token")
        XCTAssertNil(store.errorMessage)
    }

    @MainActor
    func testSessionStoreDoesNotExposeHTTPSessionInvalidationCallback() async {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: "expired-token",
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil
            )
        )
        let observedTokens = LockedArrayBox<String?>()
        var invalidationCallback: (@Sendable (String) async -> Void)?

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                invalidationCallback = onAuthSessionInvalidated
                return ConvexHTTPClient(
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )
        store.addConvexAuthTokenListener { token in
            observedTokens.append(token)
        }

        _ = store.client

        XCTAssertNil(invalidationCallback)
        XCTAssertEqual(observedTokens.get(), [])
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.token, "expired-token")
        XCTAssertEqual(persistence.session?.convexAuthToken, "expired-token")
        XCTAssertEqual(persistence.session?.betterAuthCookie, "session=abc")
    }

    @MainActor
    func testConvexRealtimeSessionBridgePushesStoreTokenRefreshToConvexCallback() async throws {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: "initial-token",
                betterAuthCookie: "session=abc",
                betterAuthSessionToken: nil,
                convexAuthTokenRefreshedAt: Date()
            )
        )
        let observedTokens = LockedArrayBox<String?>()
        var refreshCallback: (@Sendable (String) async -> Void)?
        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                refreshCallback = onAuthTokenRefresh
                return ConvexHTTPClient(
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )
        let bridge = ConvexRealtimeSessionBridge(sessionStore: store)

        let authSession = try await bridge.loginFromCache { token in
            observedTokens.append(token)
        }
        _ = store.client
        await refreshCallback?("fresh-token")

        XCTAssertEqual(authSession.token, "initial-token")
        XCTAssertEqual(observedTokens.get(), ["initial-token", "fresh-token"])
    }

    @MainActor
    func testSuccessfulOTPLoginIgnoresStaleInvalidationCallback() async throws {
        let persistence = InMemorySessionPersistence(
            session: StoredSession(
                convexAuthToken: "old-token",
                betterAuthCookie: "old-session=abc",
                betterAuthSessionToken: nil
            )
        )
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))
        var staleRefreshCallback: (@Sendable (String) async -> Void)?
        var staleInvalidationCallback: (@Sendable (String) async -> Void)?

        TestURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/api/auth/sign-in/email-otp":
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Set-Better-Auth-Cookie": "new-session=xyz; Path=/; HttpOnly"]
                )!
                return (response, Data("{}".utf8))
            case "/api/auth/convex/token":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Better-Auth-Cookie"), "new-session=xyz")
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, Data("{\"token\":\"new-token\"}".utf8))
            default:
                XCTFail("Unexpected request path: \(request.url?.path ?? "")")
                throw PatchworkError.invalidResponse
            }
        }

        let store = SessionStore(
            sessionPersistence: persistence,
            clientBuilder: { authToken, betterAuthCookie, betterAuthSessionToken, onAuthTokenRefresh, onBetterAuthCookieRefresh, onAuthSessionInvalidated in
                if staleRefreshCallback == nil, let onAuthTokenRefresh {
                    staleRefreshCallback = onAuthTokenRefresh
                }
                if staleInvalidationCallback == nil, let onAuthSessionInvalidated {
                    staleInvalidationCallback = onAuthSessionInvalidated
                }
                return ConvexHTTPClient(
                    cloudURL: cloudURL,
                    siteURL: siteURL,
                    session: session,
                    authToken: authToken,
                    betterAuthCookie: betterAuthCookie,
                    betterAuthSessionToken: betterAuthSessionToken,
                    onAuthTokenRefresh: onAuthTokenRefresh,
                    onBetterAuthCookieRefresh: onBetterAuthCookieRefresh,
                    onAuthSessionInvalidated: onAuthSessionInvalidated
                )
            }
        )

        _ = store.client
        store.emailForOTP = "new@example.com"
        await store.verifyOTP(code: "123456")
        await staleRefreshCallback?("stale-token")

        XCTAssertNil(staleInvalidationCallback)
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.token, "new-token")
        XCTAssertEqual(persistence.session?.convexAuthToken, "new-token")
        XCTAssertNil(store.errorMessage)
    }

    @MainActor
    func testRefreshAuthedDataPreservesOptimisticUserWhenCurrentUserQueryReturnsNil() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        let expectedUser = CurrentUser(
            id: "user_123",
            email: "optimistic@example.com",
            name: "Optimistic User",
            roles: UserRoles(isSeeker: true, isTasker: false),
            location: UserLocation(
                city: "Toronto",
                province: "ON",
                coordinates: nil
            ),
            settings: UserSettings(
                notificationsEnabled: false,
                locationEnabled: false
            ),
            createdAt: nil,
            photoImage: nil
        )

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/query")

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            let data = Data("{\"status\":\"success\",\"value\":null}".utf8)
            return (response, data)
        }

        let client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session, authToken: "test-token")
        let appState = AppState()
        appState.currentUser = expectedUser

        await appState.refreshAuthedData(
            client: client,
            surfaceErrors: false,
            shouldRefreshCategories: false
        )

        XCTAssertEqual(appState.currentUser, expectedUser)
        XCTAssertNil(appState.lastError)
        XCTAssertFalse(appState.hasConfirmedMissingCurrentUser)
        XCTAssertFalse(appState.hasFailedCurrentUserRefreshWithoutPrevious)
        XCTAssertNil(appState.currentUserRefreshFailure)
    }

    @MainActor
    func testRefreshAuthedDataTracksConfirmedMissingCurrentUser() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/query")

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("{\"status\":\"success\",\"value\":null}".utf8))
        }

        let client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session, authToken: "test-token")
        let appState = AppState()

        await appState.refreshAuthedData(
            client: client,
            surfaceErrors: false,
            shouldRefreshCategories: false
        )

        XCTAssertNil(appState.currentUser)
        XCTAssertTrue(appState.hasConfirmedMissingCurrentUser)
        XCTAssertFalse(appState.hasFailedCurrentUserRefreshWithoutPrevious)
        XCTAssertNil(appState.currentUserRefreshFailure)
    }

    @MainActor
    func testRefreshAuthedDataDoesNotMarkMissingCurrentUserWhenQueryFails() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/query")

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("{\"error\":\"Service temporarily unavailable.\"}".utf8))
        }

        let client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session, authToken: "test-token")
        let appState = AppState()

        await appState.refreshAuthedData(
            client: client,
            surfaceErrors: false,
            shouldRefreshCategories: false
        )

        XCTAssertNil(appState.currentUser)
        XCTAssertFalse(appState.hasConfirmedMissingCurrentUser)
        XCTAssertTrue(appState.hasFailedCurrentUserRefreshWithoutPrevious)
        XCTAssertNotNil(appState.currentUserRefreshFailure)
    }

    @MainActor
    func testRefreshAuthedDataPreservesFetchedUserWhenFollowUpQueryFails() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        let fetchedUserJSON = """
        {
          "_id": "user_456",
          "email": "fresh@example.com",
          "name": "Fresh User",
          "roles": { "isSeeker": true, "isTasker": false },
          "location": {
            "city": "Toronto",
            "province": "ON",
            "coordinates": { "lat": 43.6532, "lng": -79.3832 }
          },
          "settings": { "notificationsEnabled": true, "locationEnabled": true },
          "createdAt": 123
        }
        """

        var queryCallIndex = 0
        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/query")

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )

            defer { queryCallIndex += 1 }

            switch queryCallIndex {
            case 0:
                return (response, Data("{\"status\":\"success\",\"value\":\(fetchedUserJSON)}".utf8))
            case 1:
                throw PatchworkError.invalidResponse
            case 2:
                return (response, Data("{\"status\":\"success\",\"value\":[]}".utf8))
            case 3:
                return (response, Data("{\"status\":\"success\",\"value\":null}".utf8))
            default:
                XCTFail("Unexpected query order: \(queryCallIndex)")
                throw PatchworkError.invalidResponse
            }
        }

        let client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session, authToken: "test-token")
        let appState = AppState()

        await appState.refreshAuthedData(
            client: client,
            surfaceErrors: false,
            shouldRefreshCategories: false
        )

        XCTAssertEqual(appState.currentUser?.id, "user_456")
        XCTAssertEqual(appState.currentUser?.location?.coordinates?.lat, 43.6532)
        XCTAssertEqual(appState.currentUser?.location?.coordinates?.lng, -79.3832)
        XCTAssertEqual(appState.conversations, [])
        XCTAssertEqual(appState.jobs, [])
        XCTAssertNil(appState.lastError)
    }

    @MainActor
    func testRefreshCurrentUserOnlyFetchesCurrentUser() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))

        let fetchedUserJSON = """
        {
          "_id": "user_narrow",
          "email": "narrow@example.com",
          "name": "Narrow User",
          "roles": { "isSeeker": true, "isTasker": false },
          "settings": { "notificationsEnabled": true, "locationEnabled": true }
        }
        """
        var queryPaths: [String] = []

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/query")
            let body = try XCTUnwrap(Self.requestBody(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let queryPath = try XCTUnwrap(object["path"] as? String)
            queryPaths.append(queryPath)

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )

            XCTAssertEqual(queryPath, "users:getCurrentUser")
            return (response, Data("{\"status\":\"success\",\"value\":\(fetchedUserJSON)}".utf8))
        }

        let client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session, authToken: "test-token")
        let appState = AppState()

        await appState.refreshCurrentUser(client: client)

        XCTAssertEqual(queryPaths, ["users:getCurrentUser"])
        XCTAssertEqual(appState.currentUser?.id, "user_narrow")
        XCTAssertEqual(appState.conversations, [])
        XCTAssertEqual(appState.jobs, [])
        XCTAssertNil(appState.taskerProfile)
    }

    @MainActor
    func testRefreshTaskerProfilePreservesPreviousProfileOnFailure() async throws {
        let session = makeMockSession()
        let cloudURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.cloud"))
        let siteURL = try XCTUnwrap(URL(string: "https://aware-meerkat-572.convex.site"))
        let previousProfile = TaskerProfileSelf(
            id: "tasker_previous",
            displayName: "Previous Tasker",
            bio: "Existing profile",
            websiteLinks: [],
            socialLinks: [],
            subscriptionPlan: "free",
            subscriptionAccessType: nil,
            subscriptionActiveAccessTypes: nil,
            subscriptionStatus: nil,
            subscriptionEndsAt: nil,
            hasActiveSubscription: false,
            ghostMode: false,
            rating: nil,
            reviewCount: nil,
            completedJobs: 3,
            verified: false,
            responseTime: nil,
            createdAt: nil,
            photoSource: nil,
            photoImage: nil,
            categories: []
        )
        var queryPaths: [String] = []

        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/query")
            let body = try XCTUnwrap(Self.requestBody(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let queryPath = try XCTUnwrap(object["path"] as? String)
            queryPaths.append(queryPath)
            XCTAssertEqual(queryPath, "taskers:getTaskerProfile")
            throw PatchworkError.invalidResponse
        }

        let client = ConvexHTTPClient(cloudURL: cloudURL, siteURL: siteURL, session: session, authToken: "test-token")
        let appState = AppState()
        appState.taskerProfile = previousProfile

        await appState.refreshTaskerProfile(client: client, surfaceErrors: false)

        XCTAssertEqual(queryPaths, ["taskers:getTaskerProfile"])
        XCTAssertEqual(appState.taskerProfile, previousProfile)
        XCTAssertNil(appState.lastError)
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

    private static func requestBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return data
    }

    private static func makeCurrentUser(id: ConvexID) -> CurrentUser {
        CurrentUser(
            id: id,
            email: "\(id)@example.com",
            name: "Cached User",
            roles: UserRoles(isSeeker: true, isTasker: false),
            location: UserLocation(
                city: "Toronto",
                province: "ON",
                coordinates: Coordinates(lat: 43.6532, lng: -79.3832)
            ),
            settings: UserSettings(notificationsEnabled: true, locationEnabled: true),
            createdAt: 1_704_067_200_000,
            photoImage: nil
        )
    }

    private static func makeJWT(expiration: Date) -> String {
        let header = Data("{\"alg\":\"none\",\"typ\":\"JWT\"}".utf8).base64URLEncodedString()
        let payload = Data("{\"exp\":\(Int(expiration.timeIntervalSince1970))}".utf8).base64URLEncodedString()
        return "\(header).\(payload)."
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

private final class InMemorySessionPersistence: SessionPersisting {
    var session: StoredSession?

    init(session: StoredSession? = nil) {
        self.session = session
    }

    func loadSession() -> StoredSession? {
        session
    }

    func saveSession(_ session: StoredSession?) {
        self.session = session
    }
}

private final class InMemoryRecentEmailPersistence: RecentEmailPersisting {
    var emails: [String]

    init(emails: [String] = []) {
        self.emails = emails
    }

    func loadRecentEmails() -> [String] {
        emails
    }

    func saveRecentEmails(_ emails: [String]) {
        self.emails = emails
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func set(_ value: Value) {
        lock.lock()
        defer { lock.unlock() }
        self.value = value
    }

    func get() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private final class LockedArrayBox<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Element] = []

    func append(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        values.append(element)
    }

    func get() -> [Element] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}
