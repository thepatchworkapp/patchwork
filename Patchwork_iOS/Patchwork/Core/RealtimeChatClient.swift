import Combine
import ConvexMobile
import Foundation
import Observation

struct PatchworkConvexAuthSession: Sendable {
    let token: String
}

private final class PatchworkConvexAuthProvider: AuthProvider {
    typealias T = PatchworkConvexAuthSession

    private weak var sessionStore: SessionStore?

    @MainActor
    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    func login(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> PatchworkConvexAuthSession {
        try await loginFromCache(onIdToken: onIdToken)
    }

    func loginFromCache(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> PatchworkConvexAuthSession {
        guard let sessionStore else {
            onIdToken(nil)
            throw PatchworkError.missingToken
        }

        let restored = await sessionStore.restorePersistedSessionIfNeeded(forceRefresh: false)
        let token = await MainActor.run { sessionStore.token }

        guard restored, let token, !token.isEmpty else {
            onIdToken(nil)
            throw PatchworkError.missingToken
        }

        onIdToken(token)
        return PatchworkConvexAuthSession(token: token)
    }

    func logout() async throws {
        // SessionStore owns sign-out and token invalidation for the app.
    }

    func extractIdToken(from authResult: PatchworkConvexAuthSession) -> String {
        authResult.token
    }
}

@MainActor
@Observable
final class RealtimeChatClient {
    private let client: ConvexClientWithAuth<PatchworkConvexAuthSession>
    private var subscriptionTask: Task<Void, Never>?

    init(sessionStore: SessionStore) {
        let authProvider = PatchworkConvexAuthProvider(sessionStore: sessionStore)
        client = ConvexClientWithAuth(
            deploymentUrl: AppConfig.convexCloudURL.absoluteString,
            authProvider: authProvider
        )
    }

    func subscribeToThread(
        conversationId: ConvexID,
        afterCreatedAt: Int,
        limit: Int = 100,
        onUpdate: @escaping @MainActor (ThreadDelta) -> Void,
        onError: @escaping @MainActor (String) -> Void = { _ in }
    ) {
        subscriptionTask?.cancel()
        subscriptionTask = Task { [client] in
            while !Task.isCancelled {
                let authResult = await client.loginFromCache()
                guard case .success = authResult else {
                    onError("Realtime chat authentication failed.")
                    try? await Task.sleep(for: .seconds(2))
                    continue
                }

                do {
                    let updates = client.subscribe(
                        to: "messages:watchThread",
                        with: [
                            "conversationId": conversationId,
                            "afterCreatedAt": Double(afterCreatedAt),
                            "limit": Double(limit),
                        ],
                        yielding: RealtimeThreadDelta.self
                    )
                    .values

                    for try await update in updates {
                        guard !Task.isCancelled else { return }
                        onUpdate(update.appModel)
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    onError(error.localizedDescription)
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
    }

    func stopThreadSubscription(conversationId: ConvexID? = nil) {
        subscriptionTask?.cancel()
        subscriptionTask = nil
    }
}

private struct RealtimeThreadDelta: Decodable {
    let conversation: ConversationDetail?
    let messages: [RealtimeChatMessage]
    let latestCursor: RealtimeInteger?
    let latestProposal: RealtimeProposalPayload?
    let latestMessageAt: RealtimeInteger?
    let latestProposalUpdatedAt: RealtimeInteger?
    let hasMore: Bool?

    var appModel: ThreadDelta {
        ThreadDelta(
            conversation: conversation,
            messages: messages.map(\.appModel),
            latestCursor: latestCursor?.value,
            latestProposal: latestProposal?.appModel,
            latestMessageAt: latestMessageAt?.value,
            latestProposalUpdatedAt: latestProposalUpdatedAt?.value,
            hasMore: hasMore
        )
    }
}

private struct RealtimeChatMessage: Decodable {
    let id: ConvexID
    let conversationId: ConvexID?
    let senderId: ConvexID
    let type: String
    let content: String
    let proposalId: ConvexID?
    let proposal: RealtimeProposalPayload?
    let createdAt: RealtimeInteger
    let updatedAt: RealtimeInteger?
    let clientMessageId: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case conversationId
        case senderId
        case type
        case content
        case proposalId
        case proposal
        case createdAt
        case updatedAt
        case clientMessageId
    }

    var appModel: ChatMessage {
        ChatMessage(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            type: type,
            content: content,
            proposalId: proposalId,
            proposal: proposal?.appModel,
            createdAt: createdAt.value,
            updatedAt: updatedAt?.value,
            clientMessageId: clientMessageId,
            localStatus: nil
        )
    }
}

private struct RealtimeProposalPayload: Decodable {
    let id: ConvexID
    let conversationId: ConvexID?
    let senderId: ConvexID
    let receiverId: ConvexID
    let rate: RealtimeInteger
    let rateType: String
    let startDateTime: String
    let notes: String?
    let status: String
    let previousProposalId: ConvexID?
    let counterProposalId: ConvexID?
    let clientProposalId: String?
    let createdAt: RealtimeInteger?
    let updatedAt: RealtimeInteger?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case conversationId
        case senderId
        case receiverId
        case rate
        case rateType
        case startDateTime
        case notes
        case status
        case previousProposalId
        case counterProposalId
        case clientProposalId
        case createdAt
        case updatedAt
    }

    var appModel: ProposalPayload {
        ProposalPayload(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            receiverId: receiverId,
            rate: rate.value,
            rateType: rateType,
            startDateTime: startDateTime,
            notes: notes,
            status: status,
            previousProposalId: previousProposalId,
            counterProposalId: counterProposalId,
            clientProposalId: clientProposalId,
            createdAt: createdAt?.value,
            updatedAt: updatedAt?.value
        )
    }
}

private struct RealtimeInteger: Decodable {
    let value: Int

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: ConvexTypeKey.self),
           let encodedInteger = try? container.decode(String.self, forKey: .integer),
           let data = Data(base64Encoded: encodedInteger) {
            value = data.withUnsafeBytes { rawBuffer in
                Int(rawBuffer.load(as: Int64.self))
            }
            return
        }

        let singleValue = try decoder.singleValueContainer()
        if let intValue = try? singleValue.decode(Int.self) {
            value = intValue
            return
        }
        if let doubleValue = try? singleValue.decode(Double.self) {
            value = Int(doubleValue)
            return
        }

        throw DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected a Convex integer or numeric value."
            )
        )
    }

    private enum ConvexTypeKey: String, CodingKey {
        case integer = "$integer"
    }
}
