import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    private(set) var token: String?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var emailForOTP = ""

    var isAuthenticated: Bool {
        token != nil
    }

    var client: ConvexHTTPClient {
        ConvexHTTPClient(authToken: token)
    }

    func sendOTP() async {
        guard !emailForOTP.isEmpty else {
            errorMessage = "Enter your email first."
            return
        }
        await run {
            try await ConvexHTTPClient().sendEmailOTP(email: emailForOTP)
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
            token = try await unauthenticatedClient.fetchConvexJWT()
        }
    }

    func signOut() {
        token = nil
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
}
