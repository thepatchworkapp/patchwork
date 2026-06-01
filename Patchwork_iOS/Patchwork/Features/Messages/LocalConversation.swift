import Foundation
import SwiftData

@Model
final class LocalConversation {
    @Attribute(.unique) var id: ConvexID
    var seekerId: ConvexID
    var taskerId: ConvexID
    var jobId: ConvexID?
    var lastMessageAt: Int?
    var lastMessageId: ConvexID?
    var lastMessagePreview: String?
    var lastMessageSenderId: ConvexID?
    var seekerUnreadCount: Int?
    var taskerUnreadCount: Int?
    var seekerLastReadAt: Int?
    var taskerLastReadAt: Int?
    var participantName: String?
    var participantPhotoUrl: String?
    var newestCursor: String?
    var lastSyncedAt: Int?
    var updatedAt: Int

    init(
        id: ConvexID,
        seekerId: ConvexID,
        taskerId: ConvexID,
        jobId: ConvexID? = nil,
        lastMessageAt: Int? = nil,
        lastMessageId: ConvexID? = nil,
        lastMessagePreview: String? = nil,
        lastMessageSenderId: ConvexID? = nil,
        seekerUnreadCount: Int? = nil,
        taskerUnreadCount: Int? = nil,
        seekerLastReadAt: Int? = nil,
        taskerLastReadAt: Int? = nil,
        participantName: String? = nil,
        participantPhotoUrl: String? = nil,
        newestCursor: String? = nil,
        lastSyncedAt: Int? = nil,
        updatedAt: Int
    ) {
        self.id = id
        self.seekerId = seekerId
        self.taskerId = taskerId
        self.jobId = jobId
        self.lastMessageAt = lastMessageAt
        self.lastMessageId = lastMessageId
        self.lastMessagePreview = lastMessagePreview
        self.lastMessageSenderId = lastMessageSenderId
        self.seekerUnreadCount = seekerUnreadCount
        self.taskerUnreadCount = taskerUnreadCount
        self.seekerLastReadAt = seekerLastReadAt
        self.taskerLastReadAt = taskerLastReadAt
        self.participantName = participantName
        self.participantPhotoUrl = participantPhotoUrl
        self.newestCursor = newestCursor
        self.lastSyncedAt = lastSyncedAt
        self.updatedAt = updatedAt
    }
}

extension LocalConversation {
    struct Snapshot: Equatable {
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
        let newestCursor: String?
        let lastSyncedAt: Int?
        let updatedAt: Int
    }

    convenience init(snapshot: Snapshot) {
        self.init(
            id: snapshot.id,
            seekerId: snapshot.seekerId,
            taskerId: snapshot.taskerId,
            jobId: snapshot.jobId,
            lastMessageAt: snapshot.lastMessageAt,
            lastMessageId: snapshot.lastMessageId,
            lastMessagePreview: snapshot.lastMessagePreview,
            lastMessageSenderId: snapshot.lastMessageSenderId,
            seekerUnreadCount: snapshot.seekerUnreadCount,
            taskerUnreadCount: snapshot.taskerUnreadCount,
            seekerLastReadAt: snapshot.seekerLastReadAt,
            taskerLastReadAt: snapshot.taskerLastReadAt,
            participantName: snapshot.participantName,
            participantPhotoUrl: snapshot.participantPhotoUrl,
            newestCursor: snapshot.newestCursor,
            lastSyncedAt: snapshot.lastSyncedAt,
            updatedAt: snapshot.updatedAt
        )
    }

    var snapshot: Snapshot {
        Snapshot(
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
            newestCursor: newestCursor,
            lastSyncedAt: lastSyncedAt,
            updatedAt: updatedAt
        )
    }

    func merge(snapshot: Snapshot) {
        guard snapshot.updatedAt >= updatedAt else { return }

        seekerId = snapshot.seekerId
        taskerId = snapshot.taskerId
        jobId = snapshot.jobId
        lastMessageAt = snapshot.lastMessageAt
        lastMessageId = snapshot.lastMessageId
        lastMessagePreview = snapshot.lastMessagePreview
        lastMessageSenderId = snapshot.lastMessageSenderId
        seekerUnreadCount = snapshot.seekerUnreadCount
        taskerUnreadCount = snapshot.taskerUnreadCount
        seekerLastReadAt = snapshot.seekerLastReadAt
        taskerLastReadAt = snapshot.taskerLastReadAt
        participantName = snapshot.participantName
        participantPhotoUrl = snapshot.participantPhotoUrl
        newestCursor = Self.newestCursor(newestCursor, snapshot.newestCursor)
        lastSyncedAt = Self.latestTimestamp(lastSyncedAt, snapshot.lastSyncedAt)
        updatedAt = snapshot.updatedAt
    }

    private static func newestCursor(_ lhs: String?, _ rhs: String?) -> String? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            if let lhsNumber = Int(lhs), let rhsNumber = Int(rhs) {
                return lhsNumber < rhsNumber ? rhs : lhs
            }
            return lhs < rhs ? rhs : lhs
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }

    private static func latestTimestamp(_ lhs: Int?, _ rhs: Int?) -> Int? {
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
}
