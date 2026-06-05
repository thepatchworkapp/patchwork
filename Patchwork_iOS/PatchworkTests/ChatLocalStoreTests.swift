import SwiftData
import XCTest
@testable import Patchwork

@MainActor
final class ChatLocalStoreTests: XCTestCase {
    private var store: ChatLocalStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        store = ChatLocalStore(modelContainer: try ChatLocalStore.makeModelContainer(inMemory: true))
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    func testDuplicateMessagesAreNotDuplicated() throws {
        let message = message(serverMessageId: "message-1", createdAt: 10)

        try store.apply(delta: .init(messages: [message], cursor: "10"), conversationId: "conversation-1")
        try store.apply(delta: .init(messages: [message], cursor: "10"), conversationId: "conversation-1")

        let messages = try store.messages(conversationId: "conversation-1")
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.serverMessageId, "message-1")
    }

    func testProposalStatusUpdateOverwritesLocalValue() throws {
        try store.apply(
            delta: .init(proposals: [
                proposal(serverProposalId: "proposal-1", status: "pending", updatedAt: 100),
            ]),
            conversationId: "conversation-1"
        )

        try store.apply(
            delta: .init(proposals: [
                proposal(serverProposalId: "proposal-1", status: "accepted", updatedAt: 110),
            ]),
            conversationId: "conversation-1"
        )

        let proposals = try store.proposals(conversationId: "conversation-1")
        XCTAssertEqual(proposals.count, 1)
        XCTAssertEqual(proposals.first?.status, "accepted")
    }

    func testOptimisticOutgoingMessageReconcilesByClientMessageId() throws {
        let optimistic = message(
            serverMessageId: nil,
            clientMessageId: "client-message-1",
            content: "Pending",
            createdAt: 100,
            updatedAt: 100,
            isOptimistic: true
        )
        try store.upsertOptimisticMessage(optimistic)

        let confirmed = message(
            serverMessageId: "message-1",
            clientMessageId: "client-message-1",
            content: "Confirmed",
            createdAt: 105,
            updatedAt: 90,
            isOptimistic: false
        )
        try store.apply(delta: .init(messages: [confirmed]), conversationId: "conversation-1")

        let messages = try store.messages(conversationId: "conversation-1")
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.serverMessageId, "message-1")
        XCTAssertEqual(messages.first?.clientMessageId, "client-message-1")
        XCTAssertEqual(messages.first?.content, "Confirmed")
        XCTAssertEqual(messages.first?.isOptimistic, false)
    }

    func testOptimisticOutgoingProposalReconcilesByClientProposalId() throws {
        let optimistic = proposal(
            serverProposalId: nil,
            clientProposalId: "client-proposal-1",
            status: "pending",
            updatedAt: 100,
            isOptimistic: true
        )
        try store.upsertOptimisticProposal(optimistic)

        let confirmed = proposal(
            serverProposalId: "proposal-1",
            clientProposalId: "client-proposal-1",
            status: "pending",
            updatedAt: 90,
            isOptimistic: false
        )
        try store.apply(delta: .init(proposals: [confirmed]), conversationId: "conversation-1")

        let proposals = try store.proposals(conversationId: "conversation-1")
        XCTAssertEqual(proposals.count, 1)
        XCTAssertEqual(proposals.first?.serverProposalId, "proposal-1")
        XCTAssertEqual(proposals.first?.clientProposalId, "client-proposal-1")
        XCTAssertEqual(proposals.first?.isOptimistic, false)
    }

    func testOptimisticProposalMessageReconcilesByClientProposalId() throws {
        let optimistic = message(
            serverMessageId: nil,
            type: "proposal",
            content: "Proposal sent",
            clientProposalId: "client-proposal-1",
            createdAt: 100,
            updatedAt: 100,
            isOptimistic: true,
            localStatus: "sending"
        )
        try store.upsertOptimisticMessage(optimistic)

        let confirmed = message(
            serverMessageId: "message-1",
            type: "proposal",
            content: "Proposal sent",
            clientProposalId: "client-proposal-1",
            createdAt: 105,
            updatedAt: 90,
            isOptimistic: false
        )
        try store.apply(delta: .init(messages: [confirmed]), conversationId: "conversation-1")

        let messages = try store.messages(conversationId: "conversation-1")
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.serverMessageId, "message-1")
        XCTAssertEqual(messages.first?.clientProposalId, "client-proposal-1")
        XCTAssertEqual(messages.first?.localStatus, "synced")
        XCTAssertEqual(messages.first?.isOptimistic, false)
    }

    func testHydratedSystemProposalMessageDoesNotReplaceProposalCardMessage() throws {
        try store.upsertOptimisticProposal(
            proposal(
                serverProposalId: nil,
                clientProposalId: "client-proposal-1",
                status: "pending",
                updatedAt: 100,
                isOptimistic: true
            )
        )
        try store.upsertOptimisticMessage(
            message(
                serverMessageId: nil,
                type: "proposal",
                content: "Proposal sent",
                clientProposalId: "client-proposal-1",
                createdAt: 100,
                updatedAt: 100,
                isOptimistic: true,
                localStatus: "sending"
            )
        )

        let payload = proposalPayload(
            serverProposalId: "proposal-1",
            clientProposalId: "client-proposal-1",
            status: "pending",
            createdAt: 105,
            updatedAt: 105
        )
        try store.apply(
            messagesSince: MessagesSinceResponse(
                messages: [
                    ChatMessage(
                        id: "proposal-message-1",
                        conversationId: "conversation-1",
                        senderId: "seeker-1",
                        type: "proposal",
                        content: "Proposal sent",
                        proposalId: "proposal-1",
                        proposal: payload,
                        createdAt: 105,
                        updatedAt: 105,
                        clientMessageId: nil,
                        localStatus: nil
                    ),
                    ChatMessage(
                        id: "system-message-1",
                        conversationId: "conversation-1",
                        senderId: "seeker-1",
                        type: "system",
                        content: "A proposal was sent",
                        proposalId: "proposal-1",
                        proposal: payload,
                        createdAt: 106,
                        updatedAt: 106,
                        clientMessageId: nil,
                        localStatus: nil
                    ),
                ],
                hasMore: false,
                latestCursor: 106,
                latestMessageId: "system-message-1",
                latestMessageAt: 106,
                latestProposalUpdatedAt: 105,
                latestProposal: payload
            ),
            conversationId: "conversation-1"
        )

        let messages = try store.messages(conversationId: "conversation-1")
        XCTAssertEqual(messages.count, 2)
        XCTAssertTrue(messages.contains { $0.type == "proposal" && $0.serverMessageId == "proposal-message-1" })
        XCTAssertTrue(messages.contains { $0.type == "system" && $0.serverMessageId == "system-message-1" })

        let proposalMessage = try XCTUnwrap(try store.chatMessages(conversationId: "conversation-1").first { $0.type == "proposal" })
        XCTAssertEqual(proposalMessage.proposal?.id, "proposal-1")
        XCTAssertEqual(proposalMessage.proposal?.status, "pending")
        XCTAssertEqual(proposalMessage.localStatus, "synced")
    }

    func testProposalMessageFailureIsMarkedByClientProposalId() throws {
        try store.upsertOptimisticMessage(
            message(
                serverMessageId: nil,
                type: "proposal",
                content: "Proposal sent",
                clientProposalId: "client-proposal-1",
                createdAt: 100,
                isOptimistic: true,
                localStatus: "sending"
            )
        )

        try store.markProposalMessageFailed(clientProposalId: "client-proposal-1")

        var message = try XCTUnwrap(store.messages(conversationId: "conversation-1").first)
        XCTAssertEqual(message.localStatus, "failed")
        XCTAssertEqual(message.isOptimistic, true)

        try store.markProposalMessageSending(clientProposalId: "client-proposal-1")

        message = try XCTUnwrap(store.messages(conversationId: "conversation-1").first)
        XCTAssertEqual(message.localStatus, "sending")
        XCTAssertEqual(message.isOptimistic, true)
    }

    func testStaleMessageAndProposalDeltasAreIgnored() throws {
        try store.apply(
            delta: .init(
                messages: [message(serverMessageId: "message-1", content: "new", createdAt: 10, updatedAt: 200)],
                proposals: [proposal(serverProposalId: "proposal-1", status: "accepted", updatedAt: 200)]
            ),
            conversationId: "conversation-1"
        )

        try store.apply(
            delta: .init(
                messages: [message(serverMessageId: "message-1", content: "old", createdAt: 10, updatedAt: 100)],
                proposals: [proposal(serverProposalId: "proposal-1", status: "pending", updatedAt: 100)]
            ),
            conversationId: "conversation-1"
        )

        XCTAssertEqual(try store.messages(conversationId: "conversation-1").first?.content, "new")
        XCTAssertEqual(try store.proposals(conversationId: "conversation-1").first?.status, "accepted")
    }

    func testNewestCursorUsesMaxOfStoredCursorAndMessageCreatedAt() throws {
        try store.apply(
            delta: .init(
                conversation: conversation(newestCursor: "50", updatedAt: 10),
                messages: [
                    message(serverMessageId: "message-1", createdAt: 40),
                    message(serverMessageId: "message-2", createdAt: 80),
                ],
                cursor: "70"
            ),
            conversationId: "conversation-1"
        )

        XCTAssertEqual(try store.newestCursor(for: "conversation-1"), "80")
    }

    func testSyncCursorIncludesLatestServerMessageIdAtTimestampBoundary() throws {
        try store.apply(
            delta: .init(
                messages: [
                    message(serverMessageId: "message-1", createdAt: 100),
                    message(serverMessageId: "message-2", createdAt: 100),
                ],
                cursor: "100"
            ),
            conversationId: "conversation-1"
        )

        XCTAssertEqual(
            try store.syncCursor(for: "conversation-1"),
            ChatLocalStore.SyncCursor(createdAt: 100, afterMessageId: "message-2")
        )
    }

    func testNewestCursorStaysBeforeSendingOptimisticMessageUntilReconciled() throws {
        try store.apply(
            delta: .init(
                conversation: conversation(newestCursor: "200", updatedAt: 200),
                cursor: "200"
            ),
            conversationId: "conversation-1"
        )
        try store.upsertOptimisticMessage(
            message(
                serverMessageId: nil,
                clientMessageId: "client-message-1",
                content: "Pending",
                createdAt: 250,
                updatedAt: 250,
                isOptimistic: true,
                localStatus: "sending"
            )
        )

        XCTAssertEqual(try store.newestCursor(for: "conversation-1"), "199")
        XCTAssertEqual(
            try store.syncCursor(for: "conversation-1"),
            ChatLocalStore.SyncCursor(createdAt: 199, afterMessageId: nil)
        )
        XCTAssertTrue(try store.hasPendingOptimisticMessage(clientMessageId: "client-message-1"))

        try store.apply(
            messagesSince: MessagesSinceResponse(
                messages: [
                    ChatMessage(
                        id: "message-1",
                        conversationId: "conversation-1",
                        senderId: "seeker-1",
                        type: "text",
                        content: "Pending",
                        proposalId: nil,
                        proposal: nil,
                        createdAt: 201,
                        updatedAt: 201,
                        clientMessageId: "client-message-1",
                        localStatus: nil
                    ),
                ],
                hasMore: false,
                latestCursor: 201,
                latestMessageId: "message-1",
                latestMessageAt: 201,
                latestProposalUpdatedAt: nil,
                latestProposal: nil
            ),
            conversationId: "conversation-1"
        )

        let messages = try store.messages(conversationId: "conversation-1")
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.serverMessageId, "message-1")
        XCTAssertEqual(messages.first?.localStatus, "synced")
        XCTAssertEqual(messages.first?.isOptimistic, false)
        XCTAssertEqual(try store.newestCursor(for: "conversation-1"), "201")
        XCTAssertFalse(try store.hasPendingOptimisticMessage(clientMessageId: "client-message-1"))
    }

    func testRenderableChatMessagesMergeCachedMessagesAndSinceDeltas() throws {
        try store.apply(
            delta: .init(messages: [
                message(serverMessageId: "message-1", content: "Cached", createdAt: 100),
            ], cursor: "100"),
            conversationId: "conversation-1"
        )

        XCTAssertEqual(try store.chatMessages(conversationId: "conversation-1").map(\.content), ["Cached"])

        try store.apply(
            messagesSince: MessagesSinceResponse(
                messages: [
                    ChatMessage(
                        id: "message-2",
                        conversationId: "conversation-1",
                        senderId: "tasker-1",
                        type: "text",
                        content: "Fresh",
                        proposalId: nil,
                        proposal: nil,
                        createdAt: 150,
                        updatedAt: 150,
                        clientMessageId: nil,
                        localStatus: nil
                    ),
                ],
                hasMore: false,
                latestCursor: 150,
                latestMessageId: "message-2",
                latestMessageAt: 150,
                latestProposalUpdatedAt: nil,
                latestProposal: nil
            ),
            conversationId: "conversation-1"
        )

        XCTAssertEqual(try store.chatMessages(conversationId: "conversation-1").map(\.content), ["Cached", "Fresh"])
    }

    func testMessagesSinceLatestProposalSynthesizesRenderableProposalMessage() throws {
        try store.apply(
            delta: .init(messages: [
                message(serverMessageId: "message-1", content: "Cached", createdAt: 100),
            ], cursor: "100"),
            conversationId: "conversation-1"
        )

        try store.apply(
            messagesSince: MessagesSinceResponse(
                messages: [
                    ChatMessage(
                        id: "message-2",
                        conversationId: "conversation-1",
                        senderId: "seeker-1",
                        type: "system",
                        content: "A proposal was sent",
                        proposalId: "proposal-1",
                        proposal: nil,
                        createdAt: 160,
                        updatedAt: 160,
                        clientMessageId: nil,
                        localStatus: nil
                    ),
                ],
                hasMore: false,
                latestCursor: 175,
                latestMessageId: "message-2",
                latestMessageAt: 160,
                latestProposalUpdatedAt: 175,
                latestProposal: proposalPayload(
                    serverProposalId: "proposal-1",
                    clientProposalId: "client-proposal-1",
                    status: "pending",
                    createdAt: 150,
                    updatedAt: 175
                )
            ),
            conversationId: "conversation-1"
        )

        let chatMessages = try store.chatMessages(conversationId: "conversation-1")
        let proposalMessage = try XCTUnwrap(chatMessages.first { $0.type == "proposal" })
        XCTAssertEqual(proposalMessage.proposal?.id, "proposal-1")
        XCTAssertEqual(proposalMessage.proposal?.status, "pending")
        XCTAssertEqual(proposalMessage.localStatus, "synced")
        XCTAssertTrue(chatMessages.contains { $0.type == "system" && $0.content == "A proposal was sent" })
    }

    func testConversationCacheKeepsMessageReadAndSyncFields() throws {
        try store.apply(
            delta: .init(
                conversation: conversation(
                    lastMessageAt: 100,
                    lastMessageId: "message-1",
                    lastMessagePreview: "Cached",
                    lastMessageSenderId: "seeker-1",
                    seekerUnreadCount: 2,
                    taskerUnreadCount: 3,
                    seekerLastReadAt: 80,
                    taskerLastReadAt: 90,
                    newestCursor: "100",
                    lastSyncedAt: 100,
                    updatedAt: 100
                ),
                cursor: "120",
                latestMessageId: "message-2",
                lastSyncedAt: 120
            ),
            conversationId: "conversation-1"
        )

        let cached = try XCTUnwrap(store.conversations().first)
        XCTAssertEqual(cached.lastMessageAt, 100)
        XCTAssertEqual(cached.lastMessageId, "message-2")
        XCTAssertEqual(cached.lastMessagePreview, "Cached")
        XCTAssertEqual(cached.lastMessageSenderId, "seeker-1")
        XCTAssertEqual(cached.seekerUnreadCount, 2)
        XCTAssertEqual(cached.taskerUnreadCount, 3)
        XCTAssertEqual(cached.seekerLastReadAt, 80)
        XCTAssertEqual(cached.taskerLastReadAt, 90)
        XCTAssertEqual(cached.newestCursor, "120")
        XCTAssertEqual(cached.lastSyncedAt, 120)
    }

    private func conversation(
        lastMessageAt: Int? = nil,
        lastMessageId: ConvexID? = nil,
        lastMessagePreview: String? = nil,
        lastMessageSenderId: ConvexID? = nil,
        seekerUnreadCount: Int? = nil,
        taskerUnreadCount: Int? = nil,
        seekerLastReadAt: Int? = nil,
        taskerLastReadAt: Int? = nil,
        newestCursor: String? = nil,
        lastSyncedAt: Int? = nil,
        updatedAt: Int
    ) -> LocalConversation.Snapshot {
        LocalConversation.Snapshot(
            id: "conversation-1",
            seekerId: "seeker-1",
            taskerId: "tasker-1",
            jobId: nil,
            lastMessageAt: lastMessageAt,
            lastMessageId: lastMessageId,
            lastMessagePreview: lastMessagePreview,
            lastMessageSenderId: lastMessageSenderId,
            seekerUnreadCount: seekerUnreadCount,
            taskerUnreadCount: taskerUnreadCount,
            seekerLastReadAt: seekerLastReadAt,
            taskerLastReadAt: taskerLastReadAt,
            participantName: "Taylor",
            participantPhotoUrl: nil,
            newestCursor: newestCursor,
            lastSyncedAt: lastSyncedAt,
            updatedAt: updatedAt
        )
    }

    private func message(
        serverMessageId: ConvexID? = "message-1",
        clientMessageId: String? = nil,
        type: String = "text",
        content: String = "Hello",
        clientProposalId: String? = nil,
        createdAt: Int,
        updatedAt: Int? = nil,
        isOptimistic: Bool = false,
        localStatus: String = "synced"
    ) -> LocalMessage.Snapshot {
        LocalMessage.Snapshot(
            conversationId: "conversation-1",
            serverMessageId: serverMessageId,
            clientMessageId: clientMessageId,
            senderId: "seeker-1",
            type: type,
            content: content,
            clientProposalId: clientProposalId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isOptimistic: isOptimistic,
            localStatus: localStatus
        )
    }

    private func proposal(
        serverProposalId: ConvexID? = "proposal-1",
        clientProposalId: String? = nil,
        status: String,
        updatedAt: Int,
        isOptimistic: Bool = false
    ) -> LocalProposal.Snapshot {
        LocalProposal.Snapshot(
            conversationId: "conversation-1",
            serverProposalId: serverProposalId,
            clientProposalId: clientProposalId,
            senderId: "seeker-1",
            receiverId: "tasker-1",
            rate: 2_500,
            rateType: "hourly",
            startDateTime: "2026-06-01T12:00:00Z",
            notes: nil,
            status: status,
            createdAt: 90,
            updatedAt: updatedAt,
            isOptimistic: isOptimistic
        )
    }

    private func proposalPayload(
        serverProposalId: ConvexID = "proposal-1",
        clientProposalId: String? = nil,
        status: String,
        createdAt: Int = 90,
        updatedAt: Int
    ) -> ProposalPayload {
        ProposalPayload(
            id: serverProposalId,
            conversationId: "conversation-1",
            senderId: "seeker-1",
            receiverId: "tasker-1",
            rate: 2_500,
            rateType: "hourly",
            startDateTime: "2026-06-01T12:00:00Z",
            notes: nil,
            status: status,
            previousProposalId: nil,
            counterProposalId: nil,
            clientProposalId: clientProposalId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
