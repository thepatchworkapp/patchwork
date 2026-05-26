import Foundation
import SwiftData

@Model
final class LocalProposal {
    var id: String
    var conversationId: ConvexID
    var serverProposalId: ConvexID?
    var clientProposalId: String?
    var senderId: ConvexID
    var receiverId: ConvexID
    var rate: Int
    var rateType: String
    var startDateTime: String
    var notes: String?
    var status: String
    var previousProposalId: ConvexID?
    var counterProposalId: ConvexID?
    var createdAt: Int
    var updatedAt: Int
    var isOptimistic: Bool

    init(
        id: String,
        conversationId: ConvexID,
        serverProposalId: ConvexID? = nil,
        clientProposalId: String? = nil,
        senderId: ConvexID,
        receiverId: ConvexID,
        rate: Int,
        rateType: String,
        startDateTime: String,
        notes: String? = nil,
        status: String,
        previousProposalId: ConvexID? = nil,
        counterProposalId: ConvexID? = nil,
        createdAt: Int,
        updatedAt: Int,
        isOptimistic: Bool = false
    ) {
        self.id = id
        self.conversationId = conversationId
        self.serverProposalId = serverProposalId
        self.clientProposalId = clientProposalId
        self.senderId = senderId
        self.receiverId = receiverId
        self.rate = rate
        self.rateType = rateType
        self.startDateTime = startDateTime
        self.notes = notes
        self.status = status
        self.previousProposalId = previousProposalId
        self.counterProposalId = counterProposalId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isOptimistic = isOptimistic
    }
}

extension LocalProposal {
    struct Snapshot: Equatable {
        let id: String
        let conversationId: ConvexID
        let serverProposalId: ConvexID?
        let clientProposalId: String?
        let senderId: ConvexID
        let receiverId: ConvexID
        let rate: Int
        let rateType: String
        let startDateTime: String
        let notes: String?
        let status: String
        let previousProposalId: ConvexID?
        let counterProposalId: ConvexID?
        let createdAt: Int
        let updatedAt: Int
        let isOptimistic: Bool

        init(
            id: String? = nil,
            conversationId: ConvexID,
            serverProposalId: ConvexID? = nil,
            clientProposalId: String? = nil,
            senderId: ConvexID,
            receiverId: ConvexID,
            rate: Int,
            rateType: String,
            startDateTime: String,
            notes: String? = nil,
            status: String,
            previousProposalId: ConvexID? = nil,
            counterProposalId: ConvexID? = nil,
            createdAt: Int,
            updatedAt: Int? = nil,
            isOptimistic: Bool = false
        ) {
            self.id = id ?? serverProposalId ?? clientProposalId ?? UUID().uuidString
            self.conversationId = conversationId
            self.serverProposalId = serverProposalId
            self.clientProposalId = clientProposalId
            self.senderId = senderId
            self.receiverId = receiverId
            self.rate = rate
            self.rateType = rateType
            self.startDateTime = startDateTime
            self.notes = notes
            self.status = status
            self.previousProposalId = previousProposalId
            self.counterProposalId = counterProposalId
            self.createdAt = createdAt
            self.updatedAt = updatedAt ?? createdAt
            self.isOptimistic = isOptimistic
        }
    }

    convenience init(snapshot: Snapshot) {
        self.init(
            id: snapshot.id,
            conversationId: snapshot.conversationId,
            serverProposalId: snapshot.serverProposalId,
            clientProposalId: snapshot.clientProposalId,
            senderId: snapshot.senderId,
            receiverId: snapshot.receiverId,
            rate: snapshot.rate,
            rateType: snapshot.rateType,
            startDateTime: snapshot.startDateTime,
            notes: snapshot.notes,
            status: snapshot.status,
            previousProposalId: snapshot.previousProposalId,
            counterProposalId: snapshot.counterProposalId,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt,
            isOptimistic: snapshot.isOptimistic
        )
    }

    var snapshot: Snapshot {
        Snapshot(
            id: id,
            conversationId: conversationId,
            serverProposalId: serverProposalId,
            clientProposalId: clientProposalId,
            senderId: senderId,
            receiverId: receiverId,
            rate: rate,
            rateType: rateType,
            startDateTime: startDateTime,
            notes: notes,
            status: status,
            previousProposalId: previousProposalId,
            counterProposalId: counterProposalId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isOptimistic: isOptimistic
        )
    }

    func merge(snapshot: Snapshot, force: Bool = false) {
        guard force || snapshot.updatedAt >= updatedAt else { return }

        id = snapshot.serverProposalId ?? snapshot.clientProposalId ?? id
        serverProposalId = snapshot.serverProposalId ?? serverProposalId
        clientProposalId = snapshot.clientProposalId ?? clientProposalId
        senderId = snapshot.senderId
        receiverId = snapshot.receiverId
        rate = snapshot.rate
        rateType = snapshot.rateType
        startDateTime = snapshot.startDateTime
        notes = snapshot.notes
        status = snapshot.status
        previousProposalId = snapshot.previousProposalId
        counterProposalId = snapshot.counterProposalId
        createdAt = snapshot.createdAt
        updatedAt = snapshot.updatedAt
        isOptimistic = snapshot.isOptimistic && serverProposalId == nil
    }
}
