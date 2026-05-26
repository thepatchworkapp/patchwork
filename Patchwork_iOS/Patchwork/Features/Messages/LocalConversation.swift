import Foundation
import SwiftData

@Model
final class LocalConversation {
    @Attribute(.unique) var id: ConvexID
    var seekerId: ConvexID
    var taskerId: ConvexID
    var jobId: ConvexID?
    var lastMessageAt: Int?
    var lastMessagePreview: String?
    var seekerUnreadCount: Int?
    var taskerUnreadCount: Int?
    var participantName: String?
    var participantPhotoUrl: String?
    var newestCursor: String?
    var updatedAt: Int

    init(
        id: ConvexID,
        seekerId: ConvexID,
        taskerId: ConvexID,
        jobId: ConvexID? = nil,
        lastMessageAt: Int? = nil,
        lastMessagePreview: String? = nil,
        seekerUnreadCount: Int? = nil,
        taskerUnreadCount: Int? = nil,
        participantName: String? = nil,
        participantPhotoUrl: String? = nil,
        newestCursor: String? = nil,
        updatedAt: Int
    ) {
        self.id = id
        self.seekerId = seekerId
        self.taskerId = taskerId
        self.jobId = jobId
        self.lastMessageAt = lastMessageAt
        self.lastMessagePreview = lastMessagePreview
        self.seekerUnreadCount = seekerUnreadCount
        self.taskerUnreadCount = taskerUnreadCount
        self.participantName = participantName
        self.participantPhotoUrl = participantPhotoUrl
        self.newestCursor = newestCursor
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
        let lastMessagePreview: String?
        let seekerUnreadCount: Int?
        let taskerUnreadCount: Int?
        let participantName: String?
        let participantPhotoUrl: String?
        let newestCursor: String?
        let updatedAt: Int
    }

    convenience init(snapshot: Snapshot) {
        self.init(
            id: snapshot.id,
            seekerId: snapshot.seekerId,
            taskerId: snapshot.taskerId,
            jobId: snapshot.jobId,
            lastMessageAt: snapshot.lastMessageAt,
            lastMessagePreview: snapshot.lastMessagePreview,
            seekerUnreadCount: snapshot.seekerUnreadCount,
            taskerUnreadCount: snapshot.taskerUnreadCount,
            participantName: snapshot.participantName,
            participantPhotoUrl: snapshot.participantPhotoUrl,
            newestCursor: snapshot.newestCursor,
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
            lastMessagePreview: lastMessagePreview,
            seekerUnreadCount: seekerUnreadCount,
            taskerUnreadCount: taskerUnreadCount,
            participantName: participantName,
            participantPhotoUrl: participantPhotoUrl,
            newestCursor: newestCursor,
            updatedAt: updatedAt
        )
    }

    func merge(snapshot: Snapshot) {
        guard snapshot.updatedAt >= updatedAt else { return }

        seekerId = snapshot.seekerId
        taskerId = snapshot.taskerId
        jobId = snapshot.jobId
        lastMessageAt = snapshot.lastMessageAt
        lastMessagePreview = snapshot.lastMessagePreview
        seekerUnreadCount = snapshot.seekerUnreadCount
        taskerUnreadCount = snapshot.taskerUnreadCount
        participantName = snapshot.participantName
        participantPhotoUrl = snapshot.participantPhotoUrl
        newestCursor = Self.newestCursor(newestCursor, snapshot.newestCursor)
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
}
