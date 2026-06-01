import Combine
import ConvexMobile
import Foundation
import Observation

struct PatchworkConvexAuthSession: Sendable {
    let token: String
}

final class ConvexRealtimeSessionBridge: AuthProvider {
    typealias T = PatchworkConvexAuthSession

    private weak var sessionStore: SessionStore?
    private let lock = NSLock()
    private var idTokenHandler: (@Sendable (String?) -> Void)?
    private var tokenChangeHandler: (@Sendable (String?) -> Void)?
    private var tokenListenerID: UUID?

    @MainActor
    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    func setTokenChangeHandler(_ handler: @escaping @Sendable (String?) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        tokenChangeHandler = handler
    }

    func login(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> PatchworkConvexAuthSession {
        try await loginFromCache(onIdToken: onIdToken)
    }

    func loginFromCache(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> PatchworkConvexAuthSession {
        storeIdTokenHandler(onIdToken)
        guard let sessionStore else {
            onIdToken(nil)
            throw PatchworkError.missingToken
        }
        await registerTokenListenerIfNeeded(sessionStore: sessionStore)

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

    private func storeIdTokenHandler(_ handler: @Sendable @escaping (String?) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        idTokenHandler = handler
    }

    @MainActor
    private func registerTokenListenerIfNeeded(sessionStore: SessionStore) {
        guard tokenListenerID == nil else {
            return
        }
        tokenListenerID = sessionStore.addConvexAuthTokenListener { [weak self] token in
            self?.pushUpdatedToken(token)
        }
    }

    private func pushUpdatedToken(_ token: String?) {
        let handler: (@Sendable (String?) -> Void)?
        let changeHandler: (@Sendable (String?) -> Void)?
        lock.lock()
        handler = idTokenHandler
        changeHandler = tokenChangeHandler
        lock.unlock()

        handler?(token)
        changeHandler?(token)
    }
}

@MainActor
@Observable
final class RealtimeChatClient {
    private struct ActiveThreadSubscription {
        let conversationId: ConvexID
        let limit: Int
        let currentCursor: @MainActor () -> ChatLocalStore.SyncCursor
        let onUpdate: @MainActor (ThreadDelta) -> Void
        let onReconnect: @MainActor () -> Void
        let onError: @MainActor (String) -> Void
    }

    private let authBridge: ConvexRealtimeSessionBridge
    private let client: ConvexClientWithAuth<PatchworkConvexAuthSession>
    private var activeThreadSubscription: ActiveThreadSubscription?
    private var subscriptionTask: Task<Void, Never>?

    init(sessionStore: SessionStore) {
        let authProvider = ConvexRealtimeSessionBridge(sessionStore: sessionStore)
        authBridge = authProvider
        client = ConvexClientWithAuth(
            deploymentUrl: AppConfig.convexCloudURL.absoluteString,
            authProvider: authProvider
        )
        authProvider.setTokenChangeHandler { [weak self] token in
            Task { @MainActor in
                self?.handleSessionTokenChange(token)
            }
        }
    }

    func subscribeToThread(
        conversationId: ConvexID,
        limit: Int = 100,
        currentCursor: @escaping @MainActor () -> ChatLocalStore.SyncCursor,
        onUpdate: @escaping @MainActor (ThreadDelta) -> Void,
        onReconnect: @escaping @MainActor () -> Void = {},
        onError: @escaping @MainActor (String) -> Void = { _ in }
    ) {
        let subscription = ActiveThreadSubscription(
            conversationId: conversationId,
            limit: limit,
            currentCursor: currentCursor,
            onUpdate: onUpdate,
            onReconnect: onReconnect,
            onError: onError
        )
        activeThreadSubscription = subscription
        startSubscription(subscription)
    }

    func stopThreadSubscription(conversationId: ConvexID? = nil) {
        guard conversationId == nil || activeThreadSubscription?.conversationId == conversationId else {
            return
        }
        subscriptionTask?.cancel()
        subscriptionTask = nil
        activeThreadSubscription = nil
    }

    private func handleSessionTokenChange(_ token: String?) {
        guard activeThreadSubscription != nil else {
            return
        }
        guard let token, !token.isEmpty else {
            stopThreadSubscription()
            return
        }
        restartActiveSubscription()
        activeThreadSubscription?.onReconnect()
    }

    private func restartActiveSubscription() {
        guard let activeThreadSubscription else {
            return
        }
        startSubscription(activeThreadSubscription)
    }

    private func startSubscription(_ subscription: ActiveThreadSubscription) {
        subscriptionTask?.cancel()
        subscriptionTask = Task { [client, subscription] in
            var shouldCatchUpOnReconnect = false
            while !Task.isCancelled {
                let authResult = await client.loginFromCache()
                guard !Task.isCancelled else {
                    return
                }
                guard case .success = authResult else {
                    subscription.onError("Realtime chat authentication failed.")
                    shouldCatchUpOnReconnect = true
                    try? await Task.sleep(for: .seconds(2))
                    continue
                }
                if shouldCatchUpOnReconnect {
                    subscription.onReconnect()
                    shouldCatchUpOnReconnect = false
                }
                let cursor = subscription.currentCursor()
                var args: [String: (any ConvexEncodable)?] = [
                    "conversationId": subscription.conversationId,
                    "afterCreatedAt": Double(cursor.createdAt),
                    "limit": Double(subscription.limit),
                ]
                if let afterMessageId = cursor.afterMessageId {
                    args["afterMessageId"] = afterMessageId
                }

                do {
                    let updates = client.subscribe(
                        to: "messages:watchThread",
                        with: args,
                        yielding: RealtimeThreadDelta.self
                    )
                    .values

                    for try await update in updates {
                        guard !Task.isCancelled else { return }
                        subscription.onUpdate(update.appModel)
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    subscription.onError(error.localizedDescription)
                    shouldCatchUpOnReconnect = true
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
    }
}

private struct RealtimeThreadDelta: Decodable {
    let conversation: RealtimeConversationDetail?
    let messages: [RealtimeChatMessage]
    let latestCursor: RealtimeInteger?
    let latestMessageId: ConvexID?
    let latestProposal: RealtimeProposalPayload?
    let latestMessageAt: RealtimeInteger?
    let latestProposalUpdatedAt: RealtimeInteger?
    let hasMore: Bool?

    var appModel: ThreadDelta {
        ThreadDelta(
            conversation: conversation?.appModel,
            messages: messages.map(\.appModel),
            latestCursor: latestCursor?.value,
            latestMessageId: latestMessageId,
            latestProposal: latestProposal?.appModel,
            latestMessageAt: latestMessageAt?.value,
            latestProposalUpdatedAt: latestProposalUpdatedAt?.value,
            hasMore: hasMore
        )
    }
}

private struct RealtimeConversationDetail: Decodable {
    let id: ConvexID
    let seekerId: ConvexID
    let taskerId: ConvexID
    let jobId: ConvexID?
    let lastMessageAt: Int?
    let lastMessageId: ConvexID?
    let lastMessagePreview: String?
    let lastMessageSenderId: ConvexID?
    let seekerUnreadCount: Int?
    let taskerUnreadCount: Int?
    let seekerLastReadAt: Int?
    let taskerLastReadAt: Int?
    let participantName: String?
    let participantPhotoUrl: String?
    let participantImage: RemoteImageAsset?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case seekerId
        case taskerId
        case jobId
        case lastMessageAt
        case lastMessageId
        case lastMessagePreview
        case lastMessageSenderId
        case seekerUnreadCount
        case taskerUnreadCount
        case seekerLastReadAt
        case taskerLastReadAt
        case participantName
        case participantPhotoUrl
        case participantImage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(ConvexID.self, forKey: .id)
        seekerId = try container.decode(ConvexID.self, forKey: .seekerId)
        taskerId = try container.decode(ConvexID.self, forKey: .taskerId)
        jobId = try container.decodeIfPresent(ConvexID.self, forKey: .jobId)
        lastMessageAt = try container.decodeRealtimeIntegerIfPresent(forKey: .lastMessageAt)
        lastMessageId = try container.decodeIfPresent(ConvexID.self, forKey: .lastMessageId)
        lastMessagePreview = try container.decodeIfPresent(String.self, forKey: .lastMessagePreview)
        lastMessageSenderId = try container.decodeIfPresent(ConvexID.self, forKey: .lastMessageSenderId)
        seekerUnreadCount = try container.decodeRealtimeIntegerIfPresent(forKey: .seekerUnreadCount)
        taskerUnreadCount = try container.decodeRealtimeIntegerIfPresent(forKey: .taskerUnreadCount)
        seekerLastReadAt = try container.decodeRealtimeIntegerIfPresent(forKey: .seekerLastReadAt)
        taskerLastReadAt = try container.decodeRealtimeIntegerIfPresent(forKey: .taskerLastReadAt)
        participantName = try container.decodeIfPresent(String.self, forKey: .participantName)
        participantPhotoUrl = try container.decodeIfPresent(String.self, forKey: .participantPhotoUrl)
        participantImage = try? container.decodeIfPresent(RemoteImageAsset.self, forKey: .participantImage)
    }

    var appModel: ConversationDetail {
        ConversationDetail(
            id: id,
            seekerId: seekerId,
            taskerId: taskerId,
            jobId: jobId,
            lastMessageAt: lastMessageAt,
            lastMessageId: lastMessageId,
            lastMessagePreview: lastMessagePreview,
            lastMessageSenderId: lastMessageSenderId,
            seekerUnreadCount: seekerUnreadCount,
            taskerUnreadCount: taskerUnreadCount,
            seekerLastReadAt: seekerLastReadAt,
            taskerLastReadAt: taskerLastReadAt,
            participantName: participantName,
            participantPhotoUrl: participantPhotoUrl,
            participantImage: participantImage
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

private extension KeyedDecodingContainer {
    func decodeRealtimeIntegerIfPresent(forKey key: Key) throws -> Int? {
        try decodeIfPresent(RealtimeInteger.self, forKey: key)?.value
    }
}

#if DEBUG
enum RealtimeChatClientTesting {
    static func decodeThreadDelta(from data: Data) throws -> ThreadDelta {
        try JSONDecoder().decode(RealtimeThreadDelta.self, from: data).appModel
    }
}
#endif
