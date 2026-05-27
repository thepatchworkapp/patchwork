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
                latestMessageAt: 150,
                latestProposalUpdatedAt: nil
            ),
            conversationId: "conversation-1"
        )

        XCTAssertEqual(try store.chatMessages(conversationId: "conversation-1").map(\.content), ["Cached", "Fresh"])
    }

    private func conversation(newestCursor: String? = nil, updatedAt: Int) -> LocalConversation.Snapshot {
        LocalConversation.Snapshot(
            id: "conversation-1",
            seekerId: "seeker-1",
            taskerId: "tasker-1",
            jobId: nil,
            lastMessageAt: nil,
            lastMessagePreview: nil,
            seekerUnreadCount: nil,
            taskerUnreadCount: nil,
            participantName: "Taylor",
            participantPhotoUrl: nil,
            newestCursor: newestCursor,
            updatedAt: updatedAt
        )
    }

    private func message(
        serverMessageId: ConvexID? = "message-1",
        clientMessageId: String? = nil,
        content: String = "Hello",
        createdAt: Int,
        updatedAt: Int? = nil,
        isOptimistic: Bool = false
    ) -> LocalMessage.Snapshot {
        LocalMessage.Snapshot(
            conversationId: "conversation-1",
            serverMessageId: serverMessageId,
            clientMessageId: clientMessageId,
            senderId: "seeker-1",
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isOptimistic: isOptimistic
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
}
