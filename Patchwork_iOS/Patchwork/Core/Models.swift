import Foundation

typealias ConvexID = String

enum PatchworkCurrency {
    static let code = "CAD"

    static func formatted(cents: Int) -> String {
        formatted(dollars: Double(cents) / 100)
    }

    static func formatted(dollars: Double) -> String {
        dollars.formatted(.currency(code: code))
    }
}

struct RemoteImageVariant: Codable, Hashable {
    let url: String?
    let width: Int?
    let height: Int?
    let contentType: String?
    let byteSize: Int?
}

struct RemoteImageVariants: Codable, Hashable {
    let thumb: RemoteImageVariant?
    let display: RemoteImageVariant?
    let large: RemoteImageVariant?
}

struct RemoteImageAsset: Codable, Hashable {
    let id: ConvexID
    let cacheKey: String
    let updatedAt: Int?
    let variants: RemoteImageVariants?

    enum CodingKeys: String, CodingKey {
        case id
        case legacyId = "_id"
        case cacheKey
        case updatedAt
        case variants
    }

    init(id: ConvexID, cacheKey: String, updatedAt: Int?, variants: RemoteImageVariants?) {
        self.id = id
        self.cacheKey = cacheKey
        self.updatedAt = updatedAt
        self.variants = variants
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedID =
            try container.decodeIfPresent(ConvexID.self, forKey: .id)
            ?? container.decode(ConvexID.self, forKey: .legacyId)
        id = decodedID
        cacheKey = try container.decodeIfPresent(String.self, forKey: .cacheKey) ?? decodedID
        updatedAt = try container.decodeIfPresent(Int.self, forKey: .updatedAt)
        variants = try container.decodeIfPresent(RemoteImageVariants.self, forKey: .variants)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(cacheKey, forKey: .cacheKey)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(variants, forKey: .variants)
    }
}

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

struct CategoryGroup: Identifiable, Codable, Hashable {
    let id: ConvexID
    let name: String
    let slug: String
    let sortOrder: Int
    let categories: [Category]

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case slug
        case sortOrder
        case categories
    }
}

struct TaskerSummary: Identifiable, Codable, Hashable {
    let id: ConvexID
    let userId: ConvexID
    let displayName: String
    let websiteLinks: [String]
    let socialLinks: [String]
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
    let avatarImage: RemoteImageAsset?
    let categoryCoverImage: RemoteImageAsset?

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case displayName = "name"
        case websiteLinks
        case socialLinks
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
        case avatarImage
        case categoryCoverImage
    }
}

struct TaskerDetail: Codable, Hashable {
    let id: ConvexID
    let userId: ConvexID
    let displayName: String
    let websiteLinks: [String]
    let socialLinks: [String]
    let averageRating: Double?
    let reviewCount: Int?
    let bio: String?
    let verified: Bool?
    let completedJobs: Int?
    let userPhotoUrl: String?
    let profileImage: RemoteImageAsset?
    let isFavourite: Bool
    let reviews: [TaskerReview]
    let categoryProfiles: [TaskerCategoryProfile]

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case displayName
        case websiteLinks
        case socialLinks
        case averageRating = "rating"
        case reviewCount
        case bio
        case verified
        case completedJobs
        case userPhotoUrl
        case profileImage
        case isFavourite
        case reviews
        case categoryProfiles = "categories"
    }
}

struct TaskerReview: Identifiable, Codable, Hashable {
    let id: ConvexID
    let reviewerName: String
    let reviewerPhotoUrl: String?
    let reviewerImage: RemoteImageAsset?
    let rating: Int
    let text: String
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case id
        case reviewerName
        case reviewerPhotoUrl
        case reviewerImage
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
    let coverImage: RemoteImageAsset?
    let portfolioImages: [RemoteImageAsset]?

    enum CodingKeys: String, CodingKey {
        case id
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
        case coverImage
        case portfolioImages
    }
}

struct CurrentUser: Codable, Hashable {
    let id: ConvexID
    let email: String?
    let name: String?
    let roles: UserRoles?
    let location: UserLocation?
    let settings: UserSettings?
    let createdAt: Int?
    let photoImage: RemoteImageAsset?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email
        case name
        case roles
        case location
        case settings
        case createdAt
        case photoImage
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
}

struct ConversationDetail: Identifiable, Codable, Hashable {
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
}

struct ProposalPayload: Codable, Hashable {
    let id: ConvexID
    let conversationId: ConvexID?
    let senderId: ConvexID
    let receiverId: ConvexID
    let rate: Int
    let rateType: String
    let startDateTime: String
    let notes: String?
    let status: String
    let previousProposalId: ConvexID?
    let counterProposalId: ConvexID?
    let clientProposalId: String?
    let createdAt: Int?
    let updatedAt: Int?

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
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: ConvexID
    let conversationId: ConvexID?
    let senderId: ConvexID
    let type: String
    let content: String
    let proposalId: ConvexID?
    let proposal: ProposalPayload?
    let createdAt: Int
    let updatedAt: Int?
    let clientMessageId: String?
    let localStatus: String?

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
        case localStatus
    }
}

struct ModerationBlockStatus: Codable, Hashable {
    let otherUserId: ConvexID
    let currentUserBlockedOther: Bool
    let currentUserBlockedByOther: Bool
    let isBlocked: Bool
    let blockId: ConvexID?
}

struct BlockedUserSummary: Identifiable, Codable, Hashable {
    let blockId: ConvexID
    let blockedUserId: ConvexID
    let name: String
    let email: String?
    let photoUrl: String?
    let photoImage: RemoteImageAsset?
    let conversationId: ConvexID?
    let createdAt: Int

    var id: ConvexID { blockId }
}

struct MessagesPage: Decodable {
    let page: [ChatMessage]
    let isDone: Bool
    let continueCursor: String
}

struct MessagesSinceResponse: Decodable {
    let messages: [ChatMessage]
    let hasMore: Bool
    let latestCursor: Int?
    let latestMessageId: ConvexID?
    let latestMessageAt: Int?
    let latestProposalUpdatedAt: Int?
    let latestProposal: ProposalPayload?
}

struct ThreadDelta: Decodable {
    let conversation: ConversationDetail?
    let messages: [ChatMessage]
    let latestCursor: Int?
    let latestMessageId: ConvexID?
    let latestProposal: ProposalPayload?
    let latestMessageAt: Int?
    let latestProposalUpdatedAt: Int?
    let hasMore: Bool?
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
    let counterpartyImage: RemoteImageAsset?

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
        case counterpartyImage
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

struct TaskerProfileSelf: Identifiable, Codable, Hashable {
    let id: ConvexID
    let displayName: String
    let bio: String?
    let websiteLinks: [String]
    let socialLinks: [String]
    let subscriptionPlan: String
    let subscriptionAccessType: String?
    let subscriptionActiveAccessTypes: [String]?
    let subscriptionStatus: String?
    let subscriptionEndsAt: Int?
    let hasActiveSubscription: Bool?
    let ghostMode: Bool
    let rating: Double?
    let reviewCount: Int?
    let completedJobs: Int?
    let verified: Bool?
    let responseTime: String?
    let createdAt: Int?
    let photoSource: String?
    let photoImage: RemoteImageAsset?
    let categories: [TaskerManagedCategory]

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case displayName
        case bio
        case websiteLinks
        case socialLinks
        case subscriptionPlan
        case subscriptionAccessType
        case subscriptionActiveAccessTypes
        case subscriptionStatus
        case subscriptionEndsAt
        case hasActiveSubscription
        case ghostMode
        case rating
        case reviewCount
        case completedJobs
        case verified
        case responseTime
        case createdAt
        case photoSource
        case photoImage
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
    let coverAssetId: ConvexID?
    let coverImage: RemoteImageAsset?
    let portfolioImages: [RemoteImageAsset]?

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
        case coverAssetId
        case coverImage
        case portfolioImages
    }
}

struct ConvexEnvelope<T: Decodable>: Decodable {
    let status: String
    let value: T?
    let errorMessage: String?
}
