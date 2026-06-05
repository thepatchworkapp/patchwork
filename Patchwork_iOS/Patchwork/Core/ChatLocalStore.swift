import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ChatLocalStore {
    struct SyncCursor: Equatable {
        let createdAt: Int
        let afterMessageId: ConvexID?

        static let start = SyncCursor(createdAt: 0, afterMessageId: nil)
    }

    struct Delta {
        let conversation: LocalConversation.Snapshot?
        let messages: [LocalMessage.Snapshot]
        let proposals: [LocalProposal.Snapshot]
        let cursor: String?
        let latestMessageId: ConvexID?
        let lastSyncedAt: Int?

        init(
            conversation: LocalConversation.Snapshot? = nil,
            messages: [LocalMessage.Snapshot] = [],
            proposals: [LocalProposal.Snapshot] = [],
            cursor: String? = nil,
            latestMessageId: ConvexID? = nil,
            lastSyncedAt: Int? = nil
        ) {
            self.conversation = conversation
            self.messages = messages
            self.proposals = proposals
            self.cursor = cursor
            self.latestMessageId = latestMessageId
            self.lastSyncedAt = lastSyncedAt
        }
    }

    private let context: ModelContext

    init(modelContainer: ModelContainer) {
        context = ModelContext(modelContainer)
    }

    static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            LocalConversation.self,
            LocalMessage.self,
            LocalProposal.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @discardableResult
    func apply(delta: Delta, conversationId: ConvexID) throws -> String? {
        if let conversation = delta.conversation {
            upsert(conversation: conversation)
        }

        for proposal in delta.proposals {
            upsert(proposal: proposal)
        }

        for message in delta.messages {
            upsert(message: message)
        }

        if let cursor = delta.cursor {
            updateCursor(
                cursor,
                conversationId: conversationId,
                latestMessageId: delta.latestMessageId,
                lastSyncedAt: delta.lastSyncedAt ?? nowMillis()
            )
        }

        try context.save()
        return try newestCursor(for: conversationId)
    }

    @discardableResult
    func apply(threadDelta: ThreadDelta, conversationId: ConvexID) throws -> String? {
        let latestUpdate = latestCursor(
            explicitCursor: threadDelta.latestCursor,
            latestMessageAt: threadDelta.latestMessageAt,
            latestProposalUpdatedAt: threadDelta.latestProposalUpdatedAt
        ) ?? 0
        let messages = threadDelta.messages.map { LocalMessage.Snapshot(message: $0, conversationId: conversationId) }
        let proposals = threadDelta.messages.compactMap { message in
            message.proposal.map {
                LocalProposal.Snapshot(proposal: $0, conversationId: message.conversationId ?? conversationId)
            }
        } + [threadDelta.latestProposal].compactMap { proposal in
            proposal.map { LocalProposal.Snapshot(proposal: $0, conversationId: $0.conversationId ?? conversationId) }
        }
        return try apply(
            delta: Delta(
                conversation: threadDelta.conversation.map {
                    LocalConversation.Snapshot(conversation: $0, updatedAt: latestUpdate)
                },
                messages: messages + fallbackProposalMessages(for: proposals, incomingMessages: messages),
                proposals: proposals,
                cursor: cursor(
                    explicitCursor: threadDelta.latestCursor,
                    latestMessageAt: threadDelta.latestMessageAt,
                    latestProposalUpdatedAt: threadDelta.latestProposalUpdatedAt
                ),
                latestMessageId: threadDelta.latestMessageId
            ),
            conversationId: conversationId
        )
    }

    @discardableResult
    func apply(messagesSince response: MessagesSinceResponse, conversationId: ConvexID) throws -> String? {
        let messages = response.messages.map { LocalMessage.Snapshot(message: $0, conversationId: conversationId) }
        let proposals = response.messages.compactMap { message in
            message.proposal.map {
                LocalProposal.Snapshot(proposal: $0, conversationId: message.conversationId ?? conversationId)
            }
        } + [response.latestProposal].compactMap { proposal in
            proposal.map { LocalProposal.Snapshot(proposal: $0, conversationId: $0.conversationId ?? conversationId) }
        }
        return try apply(
            delta: Delta(
                messages: messages + fallbackProposalMessages(for: proposals, incomingMessages: messages),
                proposals: proposals,
                cursor: cursor(
                    explicitCursor: response.latestCursor,
                    latestMessageAt: response.latestMessageAt,
                    latestProposalUpdatedAt: response.latestProposalUpdatedAt
                ),
                latestMessageId: response.latestMessageId
            ),
            conversationId: conversationId
        )
    }

    @discardableResult
    func upsertOptimisticMessage(_ snapshot: LocalMessage.Snapshot) throws -> LocalMessage.Snapshot {
        upsert(message: snapshot)
        try context.save()
        return try requireMessage(matching: snapshot).snapshot
    }

    func markMessageFailed(clientMessageId: String) throws {
        guard let message = try context.fetch(FetchDescriptor<LocalMessage>())
            .first(where: { $0.clientMessageId == clientMessageId }) else {
            return
        }
        message.isOptimistic = true
        message.localStatus = "failed"
        message.updatedAt = max(message.updatedAt, Int(Date().timeIntervalSince1970 * 1000))
        try context.save()
    }

    func markProposalMessageFailed(clientProposalId: String) throws {
        guard let message = try context.fetch(FetchDescriptor<LocalMessage>())
            .first(where: { $0.clientProposalId == clientProposalId }) else {
            return
        }
        message.isOptimistic = true
        message.localStatus = "failed"
        message.updatedAt = max(message.updatedAt, Int(Date().timeIntervalSince1970 * 1000))
        try context.save()
    }

    func markProposalMessageSending(clientProposalId: String) throws {
        guard let message = try context.fetch(FetchDescriptor<LocalMessage>())
            .first(where: { $0.clientProposalId == clientProposalId }) else {
            return
        }
        message.isOptimistic = true
        message.localStatus = "sending"
        message.updatedAt = max(message.updatedAt, Int(Date().timeIntervalSince1970 * 1000))
        try context.save()
    }

    @discardableResult
    func upsertOptimisticProposal(_ snapshot: LocalProposal.Snapshot) throws -> LocalProposal.Snapshot {
        upsert(proposal: snapshot)
        try context.save()
        return try requireProposal(matching: snapshot).snapshot
    }

    func conversations() throws -> [LocalConversation.Snapshot] {
        try context.fetch(FetchDescriptor<LocalConversation>())
            .map(\.snapshot)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func messages(conversationId: ConvexID) throws -> [LocalMessage.Snapshot] {
        try context.fetch(FetchDescriptor<LocalMessage>())
            .filter { $0.conversationId == conversationId }
            .map(\.snapshot)
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id < rhs.id
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    func chatMessages(conversationId: ConvexID) throws -> [ChatMessage] {
        let proposals = try proposals(conversationId: conversationId)
        return try messages(conversationId: conversationId).map { message in
            let proposal = proposals.first {
                if let proposalId = message.proposalId, $0.serverProposalId == proposalId {
                    return true
                }
                if let clientProposalId = message.clientProposalId, $0.clientProposalId == clientProposalId {
                    return true
                }
                return false
            }
            return ChatMessage(message: message, proposal: proposal)
        }
    }

    func proposals(conversationId: ConvexID) throws -> [LocalProposal.Snapshot] {
        try context.fetch(FetchDescriptor<LocalProposal>())
            .filter { $0.conversationId == conversationId }
            .map(\.snapshot)
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id < rhs.id
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    func newestCursor(for conversationId: ConvexID) throws -> String? {
        let cursor = try syncCursor(for: conversationId)
        return cursor.createdAt > 0 ? String(cursor.createdAt) : nil
    }

    func syncCursor(for conversationId: ConvexID) throws -> SyncCursor {
        let storedCursor = try context.fetch(FetchDescriptor<LocalConversation>())
            .first { $0.id == conversationId }?
            .newestCursor
        let cachedMessages = try messages(conversationId: conversationId)
        let newestMessage = cachedMessages
            .filter { !$0.isOptimistic }
            .max(by: Self.messagePrecedes)
        let resolvedCursor = resolvedSyncCursor(
            storedCursor: storedCursor,
            newestMessage: newestMessage
        )

        guard let oldestPendingOptimisticCreatedAt = cachedMessages
            .filter({ $0.isOptimistic && $0.serverMessageId == nil && $0.localStatus != "failed" })
            .map(\.createdAt)
            .min() else {
            return resolvedCursor
        }

        let retryFromCreatedAt = min(resolvedCursor.createdAt, oldestPendingOptimisticCreatedAt)
        return SyncCursor(createdAt: max(0, retryFromCreatedAt - 1), afterMessageId: nil)
    }

    static func newestCursor(_ lhs: String?, _ rhs: String?) -> String? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return cursorPrecedes(lhs, rhs) ? rhs : lhs
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }

    private static func cursorPrecedes(_ lhs: String, _ rhs: String) -> Bool {
        if let lhsNumber = Int(lhs), let rhsNumber = Int(rhs) {
            return lhsNumber < rhsNumber
        }
        return lhs < rhs
    }

    static func syncCursorPrecedes(_ lhs: SyncCursor, _ rhs: SyncCursor) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        switch (lhs.afterMessageId, rhs.afterMessageId) {
        case let (lhs?, rhs?):
            return lhs < rhs
        case (nil, nil):
            return false
        case (nil, _?):
            return true
        case (_?, nil):
            return false
        }
    }

    func hasPendingOptimisticMessage(clientMessageId: String) throws -> Bool {
        try context.fetch(FetchDescriptor<LocalMessage>())
            .contains {
                $0.clientMessageId == clientMessageId
                    && $0.isOptimistic
                    && $0.serverMessageId == nil
                    && $0.localStatus != "failed"
            }
    }

    private func cursor(explicitCursor: Int?, latestMessageAt: Int?, latestProposalUpdatedAt: Int?) -> String? {
        guard let latest = latestCursor(
            explicitCursor: explicitCursor,
            latestMessageAt: latestMessageAt,
            latestProposalUpdatedAt: latestProposalUpdatedAt
        ) else {
            return nil
        }
        return latest > 0 ? String(latest) : nil
    }

    private func latestCursor(explicitCursor: Int?, latestMessageAt: Int?, latestProposalUpdatedAt: Int?) -> Int? {
        let latest = max(explicitCursor ?? 0, max(latestMessageAt ?? 0, latestProposalUpdatedAt ?? 0))
        return latest > 0 ? latest : nil
    }

    private func resolvedSyncCursor(storedCursor: String?, newestMessage: LocalMessage.Snapshot?) -> SyncCursor {
        let storedCreatedAt = storedCursor.flatMap(Int.init) ?? 0
        guard let newestMessage else {
            return SyncCursor(createdAt: storedCreatedAt, afterMessageId: nil)
        }

        if newestMessage.createdAt > storedCreatedAt {
            return SyncCursor(createdAt: newestMessage.createdAt, afterMessageId: newestMessage.serverMessageId)
        }

        if newestMessage.createdAt == storedCreatedAt {
            return SyncCursor(createdAt: storedCreatedAt, afterMessageId: newestMessage.serverMessageId)
        }

        return SyncCursor(createdAt: storedCreatedAt, afterMessageId: nil)
    }

    private static func messagePrecedes(_ lhs: LocalMessage.Snapshot, _ rhs: LocalMessage.Snapshot) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return (lhs.serverMessageId ?? lhs.id) < (rhs.serverMessageId ?? rhs.id)
    }

    private func upsert(conversation snapshot: LocalConversation.Snapshot) {
        if let existing = try? context.fetch(FetchDescriptor<LocalConversation>()).first(where: { $0.id == snapshot.id }) {
            existing.merge(snapshot: snapshot)
        } else {
            context.insert(LocalConversation(snapshot: snapshot))
        }
    }

    private func upsert(message snapshot: LocalMessage.Snapshot) {
        if let existing = findMessage(matching: snapshot) {
            let reconcilesOptimisticMessage = existing.isOptimistic && snapshot.serverMessageId != nil
            existing.merge(snapshot: snapshot, force: reconcilesOptimisticMessage)
        } else {
            context.insert(LocalMessage(snapshot: snapshot))
        }
    }

    private func upsert(proposal snapshot: LocalProposal.Snapshot) {
        if let existing = findProposal(matching: snapshot) {
            let reconcilesOptimisticProposal = existing.isOptimistic && snapshot.serverProposalId != nil
            existing.merge(snapshot: snapshot, force: reconcilesOptimisticProposal)
        } else {
            context.insert(LocalProposal(snapshot: snapshot))
        }
    }

    private func updateCursor(
        _ cursor: String,
        conversationId: ConvexID,
        latestMessageId: ConvexID?,
        lastSyncedAt: Int
    ) {
        if let conversation = try? context.fetch(FetchDescriptor<LocalConversation>()).first(where: { $0.id == conversationId }) {
            conversation.newestCursor = Self.newestCursor(conversation.newestCursor, cursor)
            conversation.lastMessageId = latestMessageId ?? conversation.lastMessageId
            conversation.lastSyncedAt = max(conversation.lastSyncedAt, lastSyncedAt)
        }
    }

    private func requireMessage(matching snapshot: LocalMessage.Snapshot) throws -> LocalMessage {
        if let message = findMessage(matching: snapshot) {
            return message
        }
        throw PatchworkError.invalidResponse
    }

    private func requireProposal(matching snapshot: LocalProposal.Snapshot) throws -> LocalProposal {
        if let proposal = findProposal(matching: snapshot) {
            return proposal
        }
        throw PatchworkError.invalidResponse
    }

    private func findMessage(matching snapshot: LocalMessage.Snapshot) -> LocalMessage? {
        let messages = (try? context.fetch(FetchDescriptor<LocalMessage>())) ?? []
        if let serverMessageId = snapshot.serverMessageId,
           let message = messages.first(where: { $0.serverMessageId == serverMessageId }) {
            return message
        }
        if let clientMessageId = snapshot.clientMessageId,
           let message = messages.first(where: { $0.clientMessageId == clientMessageId }) {
            return message
        }
        if snapshot.type == "proposal",
           let clientProposalId = snapshot.clientProposalId,
           let message = messages.first(where: { $0.type == "proposal" && $0.clientProposalId == clientProposalId }) {
            return message
        }
        if snapshot.type == "proposal",
           let proposalId = snapshot.proposalId,
           let message = messages.first(where: { $0.type == "proposal" && $0.proposalId == proposalId }) {
            return message
        }
        return messages.first { $0.id == snapshot.id }
    }

    private func fallbackProposalMessages(
        for proposals: [LocalProposal.Snapshot],
        incomingMessages: [LocalMessage.Snapshot]
    ) -> [LocalMessage.Snapshot] {
        proposals.compactMap { proposal in
            guard !incomingMessages.contains(where: { messageLinks($0, to: proposal) }),
                  !cachedMessageExists(for: proposal) else {
                return nil
            }

            return LocalMessage.Snapshot(
                id: fallbackMessageId(for: proposal),
                conversationId: proposal.conversationId,
                senderId: proposal.senderId,
                type: "proposal",
                content: proposal.previousProposalId == nil ? "Proposal sent" : "Counter proposal sent",
                proposalId: proposal.serverProposalId,
                clientProposalId: proposal.clientProposalId,
                createdAt: proposal.createdAt,
                updatedAt: proposal.updatedAt,
                isOptimistic: proposal.isOptimistic,
                localStatus: proposal.isOptimistic ? "sending" : "synced"
            )
        }
    }

    private func cachedMessageExists(for proposal: LocalProposal.Snapshot) -> Bool {
        let messages = (try? context.fetch(FetchDescriptor<LocalMessage>())) ?? []
        return messages.contains { message in
            messageLinks(message.snapshot, to: proposal)
        }
    }

    private func messageLinks(_ message: LocalMessage.Snapshot, to proposal: LocalProposal.Snapshot) -> Bool {
        guard message.type == "proposal" else {
            return false
        }
        if let proposalId = message.proposalId,
           let serverProposalId = proposal.serverProposalId,
           proposalId == serverProposalId {
            return true
        }
        if let clientProposalId = message.clientProposalId,
           let proposalClientId = proposal.clientProposalId,
           clientProposalId == proposalClientId {
            return true
        }
        return false
    }

    private func fallbackMessageId(for proposal: LocalProposal.Snapshot) -> String {
        if let serverProposalId = proposal.serverProposalId {
            return "proposal-message-\(serverProposalId)"
        }
        if let clientProposalId = proposal.clientProposalId {
            return "proposal-message-\(clientProposalId)"
        }
        return "proposal-message-\(proposal.id)"
    }

    private func findProposal(matching snapshot: LocalProposal.Snapshot) -> LocalProposal? {
        let proposals = (try? context.fetch(FetchDescriptor<LocalProposal>())) ?? []
        if let serverProposalId = snapshot.serverProposalId,
           let proposal = proposals.first(where: { $0.serverProposalId == serverProposalId }) {
            return proposal
        }
        if let clientProposalId = snapshot.clientProposalId,
           let proposal = proposals.first(where: { $0.clientProposalId == clientProposalId }) {
            return proposal
        }
        return proposals.first { $0.id == snapshot.id }
    }
}

extension LocalConversation.Snapshot {
    init(conversation: ConversationDetail, updatedAt: Int) {
        self.init(
            id: conversation.id,
            seekerId: conversation.seekerId,
            taskerId: conversation.taskerId,
            jobId: conversation.jobId,
            lastMessageAt: conversation.lastMessageAt,
            lastMessageId: conversation.lastMessageId,
            lastMessagePreview: conversation.lastMessagePreview,
            lastMessageSenderId: conversation.lastMessageSenderId,
            seekerUnreadCount: conversation.seekerUnreadCount,
            taskerUnreadCount: conversation.taskerUnreadCount,
            seekerLastReadAt: conversation.seekerLastReadAt,
            taskerLastReadAt: conversation.taskerLastReadAt,
            participantName: conversation.participantName,
            participantPhotoUrl: conversation.participantPhotoUrl,
            newestCursor: updatedAt > 0 ? String(updatedAt) : nil,
            lastSyncedAt: updatedAt > 0 ? updatedAt : nil,
            updatedAt: updatedAt
        )
    }
}

private func max(_ lhs: Int?, _ rhs: Int?) -> Int? {
    switch (lhs, rhs) {
    case let (lhs?, rhs?):
        return Swift.max(lhs, rhs)
    case let (lhs?, nil):
        return lhs
    case let (nil, rhs?):
        return rhs
    case (nil, nil):
        return nil
    }
}

private func nowMillis() -> Int {
    Int(Date().timeIntervalSince1970 * 1000)
}

extension LocalMessage.Snapshot {
    init(message: ChatMessage, conversationId: ConvexID) {
        self.init(
            conversationId: message.conversationId ?? conversationId,
            serverMessageId: message.id,
            clientMessageId: message.clientMessageId,
            senderId: message.senderId,
            type: message.type,
            content: message.content,
            proposalId: message.proposalId,
            clientProposalId: message.type == "proposal" ? message.proposal?.clientProposalId : nil,
            createdAt: message.createdAt,
            updatedAt: message.updatedAt ?? message.createdAt,
            isOptimistic: false
        )
    }
}

extension LocalProposal.Snapshot {
    init(proposal: ProposalPayload, conversationId: ConvexID) {
        self.init(
            conversationId: proposal.conversationId ?? conversationId,
            serverProposalId: proposal.id,
            clientProposalId: proposal.clientProposalId,
            senderId: proposal.senderId,
            receiverId: proposal.receiverId,
            rate: proposal.rate,
            rateType: proposal.rateType,
            startDateTime: proposal.startDateTime,
            notes: proposal.notes,
            status: proposal.status,
            previousProposalId: proposal.previousProposalId,
            counterProposalId: proposal.counterProposalId,
            createdAt: proposal.createdAt ?? proposal.updatedAt ?? 0,
            updatedAt: proposal.updatedAt ?? 0,
            isOptimistic: false
        )
    }
}

extension ChatMessage {
    init(message: LocalMessage.Snapshot, proposal: LocalProposal.Snapshot?) {
        self.init(
            id: message.serverMessageId ?? message.id,
            conversationId: message.conversationId,
            senderId: message.senderId,
            type: message.type,
            content: message.content,
            proposalId: message.proposalId,
            proposal: proposal.map(ProposalPayload.init(proposal:)),
            createdAt: message.createdAt,
            updatedAt: message.updatedAt,
            clientMessageId: message.clientMessageId,
            localStatus: message.localStatus
        )
    }
}

extension ProposalPayload {
    init(proposal: LocalProposal.Snapshot) {
        self.init(
            id: proposal.serverProposalId ?? proposal.id,
            conversationId: proposal.conversationId,
            senderId: proposal.senderId,
            receiverId: proposal.receiverId,
            rate: proposal.rate,
            rateType: proposal.rateType,
            startDateTime: proposal.startDateTime,
            notes: proposal.notes,
            status: proposal.status,
            previousProposalId: proposal.previousProposalId,
            counterProposalId: proposal.counterProposalId,
            clientProposalId: proposal.clientProposalId,
            createdAt: proposal.createdAt,
            updatedAt: proposal.updatedAt
        )
    }
}
