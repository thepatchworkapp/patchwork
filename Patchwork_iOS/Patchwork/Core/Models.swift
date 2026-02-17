import Foundation

typealias ConvexID = String

struct Category: Identifiable, Codable, Hashable {
    let id: ConvexID
    let name: String
    let slug: String
    let emoji: String?
    let group: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case slug
        case emoji
        case group
    }
}

struct TaskerSummary: Identifiable, Codable, Hashable {
    let id: ConvexID
    let userId: ConvexID
    let displayName: String
    let averageRating: Double?
    let reviewCount: Int?
    let distanceLabel: String?
    let categoryName: String?
    let rateLabel: String?
    let verified: Bool?
    let bio: String?
    let completedJobs: Int?
    let avatarUrl: String?
    let categoryPhotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case displayName = "name"
        case averageRating = "rating"
        case reviewCount = "reviews"
        case distanceLabel = "distance"
        case categoryName = "category"
        case rateLabel = "price"
        case verified
        case bio
        case completedJobs
        case avatarUrl
        case categoryPhotoUrl
    }
}

struct TaskerDetail: Codable, Hashable {
    let id: ConvexID
    let userId: ConvexID
    let displayName: String
    let averageRating: Double?
    let reviewCount: Int?
    let bio: String?
    let verified: Bool?
    let completedJobs: Int?
    let userPhotoUrl: String?
    let reviews: [TaskerReview]
    let categoryProfiles: [TaskerCategoryProfile]

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case displayName
        case averageRating = "rating"
        case reviewCount
        case bio
        case verified
        case completedJobs
        case userPhotoUrl
        case reviews
        case categoryProfiles = "categories"
    }
}

struct TaskerReview: Identifiable, Codable, Hashable {
    let id: ConvexID
    let reviewerName: String
    let reviewerPhotoUrl: String?
    let rating: Int
    let text: String
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case reviewerName
        case reviewerPhotoUrl
        case rating
        case text
        case createdAt
    }
}

struct TaskerCategoryProfile: Identifiable, Codable, Hashable {
    let id: ConvexID
    let categoryId: ConvexID
    let categoryName: String
    let categorySlug: String?
    let categoryBio: String?
    let rateType: String?
    let hourlyRate: Int?
    let fixedRate: Int?
    let serviceRadius: Int?
    let completedJobs: Int?
    let firstPhotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case categoryId
        case categoryName
        case categorySlug
        case categoryBio = "bio"
        case rateType
        case hourlyRate
        case fixedRate
        case serviceRadius
        case completedJobs
        case firstPhotoUrl
    }
}

struct CurrentUser: Codable, Hashable {
    let id: ConvexID
    let email: String?
    let name: String?
    let roles: UserRoles?
    let location: UserLocation?
    let settings: UserSettings?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email
        case name
        case roles
        case location
        case settings
    }
}

struct UserRoles: Codable, Hashable {
    let isSeeker: Bool
    let isTasker: Bool
}

struct UserLocation: Codable, Hashable {
    let city: String?
    let province: String?
    let coordinates: Coordinates?
}

struct UserSettings: Codable, Hashable {
    let notificationsEnabled: Bool?
    let locationEnabled: Bool?
}

struct Coordinates: Codable, Hashable {
    let lat: Double
    let lng: Double
}

struct ConversationSummary: Identifiable, Codable, Hashable {
    let id: ConvexID
    let seekerId: ConvexID
    let taskerId: ConvexID
    let jobId: ConvexID?
    let lastMessagePreview: String?
    let seekerUnreadCount: Int?
    let taskerUnreadCount: Int?
    let participantName: String?
    let participantPhotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case seekerId
        case taskerId
        case jobId
        case lastMessagePreview
        case seekerUnreadCount
        case taskerUnreadCount
        case participantName
        case participantPhotoUrl
    }
}

struct ConversationDetail: Identifiable, Codable, Hashable {
    let id: ConvexID
    let seekerId: ConvexID
    let taskerId: ConvexID
    let jobId: ConvexID?
    let participantName: String?
    let participantPhotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case seekerId
        case taskerId
        case jobId
        case participantName
        case participantPhotoUrl
    }
}

struct ProposalPayload: Codable, Hashable {
    let id: ConvexID
    let senderId: ConvexID
    let receiverId: ConvexID
    let rate: Int
    let rateType: String
    let startDateTime: String
    let notes: String?
    let status: String
    let previousProposalId: ConvexID?
    let counterProposalId: ConvexID?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case senderId
        case receiverId
        case rate
        case rateType
        case startDateTime
        case notes
        case status
        case previousProposalId
        case counterProposalId
    }
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: ConvexID
    let senderId: ConvexID
    let type: String
    let content: String
    let proposalId: ConvexID?
    let proposal: ProposalPayload?
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case senderId
        case type
        case content
        case proposalId
        case proposal
        case createdAt
    }
}

struct MessagesPage: Decodable {
    let page: [ChatMessage]
    let isDone: Bool
    let continueCursor: String
}

struct JobSummary: Identifiable, Codable, Hashable {
    let id: ConvexID
    let status: String
    let categoryName: String?
    let createdAt: Int?
    let description: String?
    let rate: Int?
    let rateType: String?
    let startDate: String?
    let completedDate: String?
    let counterpartyName: String?
    let counterpartyPhotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case status
        case categoryName
        case createdAt
        case description
        case rate
        case rateType
        case startDate
        case completedDate
        case counterpartyName
        case counterpartyPhotoUrl
    }
}

struct JobDetail: Codable, Hashable {
    let id: ConvexID
    let seekerId: ConvexID
    let taskerId: ConvexID
    let status: String
    let categoryName: String
    let description: String
    let notes: String?
    let rate: Int
    let rateType: String
    let startDate: String
    let completedDate: String?
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case seekerId
        case taskerId
        case status
        case categoryName
        case description
        case notes
        case rate
        case rateType
        case startDate
        case completedDate
        case createdAt
    }
}

struct JobRequestSummary: Identifiable, Codable, Hashable {
    let id: ConvexID
    let categoryName: String
    let description: String
    let status: String
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case categoryName
        case description
        case status
        case createdAt
    }
}

struct TaskerProfileSelf: Identifiable, Codable, Hashable {
    let id: ConvexID
    let displayName: String
    let bio: String?
    let subscriptionPlan: String
    let ghostMode: Bool
    let premiumPin: String?
    let categories: [TaskerManagedCategory]

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case displayName
        case bio
        case subscriptionPlan
        case ghostMode
        case premiumPin
        case categories
    }
}

struct TaskerManagedCategory: Identifiable, Codable, Hashable {
    let id: ConvexID
    let categoryId: ConvexID
    let categoryName: String
    let categorySlug: String?
    let bio: String
    let rateType: String
    let hourlyRate: Int?
    let fixedRate: Int?
    let serviceRadius: Int
    let rating: Double?
    let reviewCount: Int?
    let completedJobs: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case categoryId
        case categoryName
        case categorySlug
        case bio
        case rateType
        case hourlyRate
        case fixedRate
        case serviceRadius
        case rating
        case reviewCount
        case completedJobs
    }
}

struct ConvexEnvelope<T: Decodable>: Decodable {
    let status: String
    let value: T?
    let errorMessage: String?
}
