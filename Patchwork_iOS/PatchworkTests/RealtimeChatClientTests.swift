import Foundation
import XCTest
@testable import Patchwork

final class RealtimeChatClientTests: XCTestCase {
    func testThreadDeltaDecodesRealtimeConversationIntegerFields() throws {
        let payload: [String: Any] = [
            "conversation": [
                "_id": "conversation-1",
                "seekerId": "seeker-1",
                "taskerId": "tasker-1",
                "lastMessageAt": encodedInteger(1_000),
                "lastMessageId": "message-1",
                "lastMessagePreview": "Hello",
                "lastMessageSenderId": "seeker-1",
                "seekerUnreadCount": encodedInteger(0),
                "taskerUnreadCount": encodedInteger(1),
                "participantName": "Dave",
                "participantPhotoUrl": NSNull(),
                "participantImage": NSNull(),
            ],
            "messages": [
                [
                    "_id": "message-1",
                    "conversationId": "conversation-1",
                    "senderId": "seeker-1",
                    "type": "text",
                    "content": "Hello",
                    "proposal": NSNull(),
                    "createdAt": encodedInteger(1_000),
                    "updatedAt": encodedInteger(1_000),
                    "clientMessageId": "client-message-1",
                ],
            ],
            "latestCursor": encodedInteger(1_000),
            "latestMessageId": "message-1",
            "latestMessageAt": encodedInteger(1_000),
            "latestProposalUpdatedAt": NSNull(),
            "latestProposal": NSNull(),
            "hasMore": false,
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        let delta = try RealtimeChatClientTesting.decodeThreadDelta(from: data)

        XCTAssertEqual(delta.conversation?.lastMessageAt, 1_000)
        XCTAssertEqual(delta.conversation?.taskerUnreadCount, 1)
        XCTAssertEqual(delta.messages.first?.createdAt, 1_000)
        XCTAssertEqual(delta.messages.first?.clientMessageId, "client-message-1")
        XCTAssertEqual(delta.latestCursor, 1_000)
        XCTAssertEqual(delta.latestMessageId, "message-1")
    }

    private func encodedInteger(_ value: Int64) -> [String: String] {
        var encodedValue = value
        let data = withUnsafeBytes(of: &encodedValue) { Data($0) }
        return ["$integer": data.base64EncodedString()]
    }
}
