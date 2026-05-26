import Foundation

struct PatchworkAPI {
    let analytics: Analytics
    let categories: Categories
    let conversations: Conversations
    let jobs: Jobs
    let moderation: Moderation
    let search: Search
    let taskers: Taskers
    let users: Users

    init(client: ConvexHTTPClient) {
        analytics = Analytics(client: client)
        categories = Categories(client: client)
        conversations = Conversations(client: client)
        jobs = Jobs(client: client)
        moderation = Moderation(client: client)
        search = Search(client: client)
        taskers = Taskers(client: client)
        users = Users(client: client)
    }

    struct Analytics {
        private let client: ConvexHTTPClient

        init(client: ConvexHTTPClient) {
            self.client = client
        }

        @discardableResult
        func recordDiscoverCategorySelection(categorySlug: String) async throws -> AnalyticsRecordResult {
            try await client.mutation(
                "analytics:recordDiscoverCategorySelection",
                args: ["categorySlug": categorySlug]
            )
        }

        @discardableResult
        func recordDiscoverCategorySearchSubmit(term: String) async throws -> AnalyticsRecordResult {
            try await client.mutation(
                "analytics:recordDiscoverCategorySearchSubmit",
                args: ["term": term]
            )
        }
    }

    struct Categories {
        private let client: ConvexHTTPClient

        init(client: ConvexHTTPClient) {
            self.client = client
        }

        func list() async throws -> [Category] {
            try await client.query("categories:listCategories", args: [:])
        }
    }

    struct Conversations {
        private let client: ConvexHTTPClient

        init(client: ConvexHTTPClient) {
            self.client = client
        }

        func list(role: String, limit: Int = 50) async throws -> [ConversationSummary] {
            try await client.query(
                "conversations:listConversations",
                args: ["role": role, "limit": limit]
            )
        }

        func get(conversationId: ConvexID) async throws -> ConversationDetail? {
            try await client.query(
                "conversations:getConversation",
                args: ["conversationId": conversationId]
            )
        }
    }

    struct Jobs {
        private let client: ConvexHTTPClient

        init(client: ConvexHTTPClient) {
            self.client = client
        }

        func list(statusGroup: String, limit: Int = 50) async throws -> [JobSummary] {
            try await client.query(
                "jobs:listJobs",
                args: ["statusGroup": statusGroup, "limit": limit]
            )
        }
    }

    struct Moderation {
        private let client: ConvexHTTPClient

        init(client: ConvexHTTPClient) {
            self.client = client
        }

        func listBlockedUsers(limit: Int = 50) async throws -> [BlockedUserSummary] {
            try await client.query(
                "moderation:listBlockedUsers",
                args: ["limit": limit]
            )
        }
    }

    struct Search {
        private let client: ConvexHTTPClient

        init(client: ConvexHTTPClient) {
            self.client = client
        }

        func taskers(
            lat: Double,
            lng: Double,
            radiusKm: Int,
            limit: Int = 50,
            categorySlug: String?,
            excludeUserId: ConvexID?
        ) async throws -> [TaskerSummary] {
            var args: [String: Any] = [
                "lat": lat,
                "lng": lng,
                "radiusKm": radiusKm,
                "limit": limit,
            ]
            if let categorySlug {
                args["categorySlug"] = categorySlug
            }
            if let excludeUserId {
                args["excludeUserId"] = excludeUserId
            }

            return try await client.query("search:searchTaskers", args: args)
        }
    }

    struct Taskers {
        private let client: ConvexHTTPClient

        init(client: ConvexHTTPClient) {
            self.client = client
        }

        func get(taskerId: ConvexID) async throws -> TaskerDetail? {
            try await client.query("taskers:getTaskerById", args: ["taskerId": taskerId])
        }

        func currentProfile() async throws -> TaskerProfileSelf? {
            try await client.query("taskers:getTaskerProfile", args: [:])
        }

        func listFavourites(limit: Int = 50) async throws -> [TaskerSummary] {
            try await client.query(
                "taskers:listFavouriteTaskers",
                args: ["limit": limit]
            )
        }

        func setFavourite(taskerId: ConvexID, isFavourite: Bool) async throws -> TaskerFavouriteResult {
            try await client.mutation(
                "taskers:setFavouriteTasker",
                args: ["taskerId": taskerId, "isFavourite": isFavourite]
            )
        }
    }

    struct Users {
        private let client: ConvexHTTPClient

        init(client: ConvexHTTPClient) {
            self.client = client
        }

        func current() async throws -> CurrentUser? {
            try await client.query("users:getCurrentUser", args: [:])
        }

        @discardableResult
        func registerPushToken(_ token: String, environment: String) async throws -> Bool {
            struct RegisterPushTokenResult: Codable {
                let registered: Bool
            }
            let result: RegisterPushTokenResult = try await client.mutation(
                "users:registerPushToken",
                args: ["token": token, "environment": environment]
            )
            return result.registered
        }

        func unreadBadgeCount() async throws -> Int {
            try await client.query("users:getUnreadBadgeCount", args: [:])
        }

        @discardableResult
        func unregisterPushToken(_ token: String) async throws -> Bool {
            struct UnregisterPushTokenResult: Codable {
                let unregistered: Bool
            }
            let result: UnregisterPushTokenResult = try await client.mutation(
                "users:unregisterPushToken",
                args: ["token": token]
            )
            return result.unregistered
        }

        @discardableResult
        func updateProfile(name: String, city: String, province: String) async throws -> CurrentUser {
            try await client.mutation(
                "users:updateProfile",
                args: ["name": name, "city": city, "province": province]
            )
        }

        @discardableResult
        func updateLocation(lat: Double, lng: Double, source: String) async throws -> ConvexID {
            try await client.mutation(
                "users:updateLocation",
                args: ["lat": lat, "lng": lng, "source": source]
            )
        }
    }
}

struct TaskerFavouriteResult: Codable, Hashable {
    let isFavourite: Bool
}

struct AnalyticsRecordResult: Codable, Hashable {
    let recorded: Bool
    let reason: String?
}
