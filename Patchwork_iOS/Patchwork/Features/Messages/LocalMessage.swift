import Foundation
import SwiftData

@Model
final class LocalMessage {
    var id: String
    var conversationId: ConvexID
    var serverMessageId: ConvexID?
    var clientMessageId: String?
    var senderId: ConvexID
    var type: String
    var content: String
    var proposalId: ConvexID?
    var clientProposalId: String?
    var createdAt: Int
    var updatedAt: Int
    var isOptimistic: Bool
    var localStatus: String

    init(
        id: String,
        conversationId: ConvexID,
        serverMessageId: ConvexID? = nil,
        clientMessageId: String? = nil,
        senderId: ConvexID,
        type: String,
        content: String,
        proposalId: ConvexID? = nil,
        clientProposalId: String? = nil,
        createdAt: Int,
        updatedAt: Int,
        isOptimistic: Bool = false,
        localStatus: String = "synced"
    ) {
        self.id = id
        self.conversationId = conversationId
        self.serverMessageId = serverMessageId
        self.clientMessageId = clientMessageId
        self.senderId = senderId
        self.type = type
        self.content = content
        self.proposalId = proposalId
        self.clientProposalId = clientProposalId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isOptimistic = isOptimistic
        self.localStatus = localStatus
    }
}

extension LocalMessage {
    struct Snapshot: Equatable {
        let id: String
        let conversationId: ConvexID
        let serverMessageId: ConvexID?
        let clientMessageId: String?
        let senderId: ConvexID
        let type: String
        let content: String
        let proposalId: ConvexID?
        let clientProposalId: String?
        let createdAt: Int
        let updatedAt: Int
        let isOptimistic: Bool
        let localStatus: String

        init(
            id: String? = nil,
            conversationId: ConvexID,
            serverMessageId: ConvexID? = nil,
            clientMessageId: String? = nil,
            senderId: ConvexID,
            type: String = "text",
            content: String,
            proposalId: ConvexID? = nil,
            clientProposalId: String? = nil,
            createdAt: Int,
            updatedAt: Int? = nil,
            isOptimistic: Bool = false,
            localStatus: String = "synced"
        ) {
            self.id = id ?? serverMessageId ?? clientMessageId ?? UUID().uuidString
            self.conversationId = conversationId
            self.serverMessageId = serverMessageId
            self.clientMessageId = clientMessageId
            self.senderId = senderId
            self.type = type
            self.content = content
            self.proposalId = proposalId
            self.clientProposalId = clientProposalId
            self.createdAt = createdAt
            self.updatedAt = updatedAt ?? createdAt
            self.isOptimistic = isOptimistic
            self.localStatus = localStatus
        }
    }

    convenience init(snapshot: Snapshot) {
        self.init(
            id: snapshot.id,
            conversationId: snapshot.conversationId,
            serverMessageId: snapshot.serverMessageId,
            clientMessageId: snapshot.clientMessageId,
            senderId: snapshot.senderId,
            type: snapshot.type,
            content: snapshot.content,
            proposalId: snapshot.proposalId,
            clientProposalId: snapshot.clientProposalId,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt,
            isOptimistic: snapshot.isOptimistic,
            localStatus: snapshot.localStatus
        )
    }

    var snapshot: Snapshot {
        Snapshot(
            id: id,
            conversationId: conversationId,
            serverMessageId: serverMessageId,
            clientMessageId: clientMessageId,
            senderId: senderId,
            type: type,
            content: content,
            proposalId: proposalId,
            clientProposalId: clientProposalId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isOptimistic: isOptimistic,
            localStatus: localStatus
        )
    }

    func merge(snapshot: Snapshot, force: Bool = false) {
        guard force || snapshot.updatedAt >= updatedAt else { return }

        id = snapshot.serverMessageId ?? snapshot.clientMessageId ?? id
        serverMessageId = snapshot.serverMessageId ?? serverMessageId
        clientMessageId = snapshot.clientMessageId ?? clientMessageId
        senderId = snapshot.senderId
        type = snapshot.type
        content = snapshot.content
        proposalId = snapshot.proposalId
        clientProposalId = snapshot.clientProposalId ?? clientProposalId
        createdAt = snapshot.createdAt
        updatedAt = snapshot.updatedAt
        isOptimistic = snapshot.isOptimistic && serverMessageId == nil
        localStatus = serverMessageId == nil ? snapshot.localStatus : "synced"
    }
}
