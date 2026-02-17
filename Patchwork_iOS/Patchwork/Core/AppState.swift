import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    enum Tab: Hashable {
        case home
        case messages
        case jobs
        case profile
    }

    var selectedTab: Tab = .home
    var isBootstrapped = false

    var categories: [Category] = []
    var taskers: [TaskerSummary] = []
    var conversations: [ConversationSummary] = []
    var jobs: [JobSummary] = []
    var myRequests: [JobRequestSummary] = []
    var currentUser: CurrentUser?
    var taskerProfile: TaskerProfileSelf?

    var activeCategorySlug: String?
    var selectedTasker: TaskerDetail?
    var selectedConversation: ConversationDetail?

    var conversationRole = "seeker"
    var jobsStatusGroup = "active"

    var requestDescription = ""
    var requestAddress = ""
    var requestCity = "Toronto"
    var requestProvince = "ON"
    var requestRadius = 25

    var taskerDisplayName = ""
    var taskerBio = ""
    var taskerHourlyRate = ""

    var lastError: String?

    func loadBootstrapData(client: ConvexHTTPClient) async {
        isBootstrapped = false
        do {
            async let categoriesCall: [Category] = client.query("categories:listCategories", args: [:])
            async let taskersCall: [TaskerSummary] = client.query(
                "search:searchTaskers",
                args: [
                    "lat": AppConfig.defaultLatitude,
                    "lng": AppConfig.defaultLongitude,
                    "radiusKm": 25,
                    "limit": 50,
                ]
            )
            categories = try await categoriesCall
            taskers = try await taskersCall
            await refreshAuthedData(client: client)
            isBootstrapped = true
        } catch {
            lastError = error.localizedDescription
            isBootstrapped = true
        }
    }

    func refreshAuthedData(client: ConvexHTTPClient) async {
        do {
            currentUser = try await client.query("users:getCurrentUser", args: [:])
            async let conversationsCall: [ConversationSummary] = client.query(
                "conversations:listConversations",
                args: ["role": conversationRole, "limit": 50]
            )
            async let jobsCall: [JobSummary] = client.query(
                "jobs:listJobs",
                args: ["statusGroup": jobsStatusGroup, "limit": 50]
            )
            async let requestsCall: [JobRequestSummary]? = client.query("jobRequests:listMyJobRequests", args: ["limit": 50])
            async let taskerProfileCall: TaskerProfileSelf? = client.query("taskers:getTaskerProfile", args: [:])

            conversations = try await conversationsCall
            jobs = try await jobsCall
            myRequests = try await requestsCall ?? []
            taskerProfile = try await taskerProfileCall
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshConversations(client: ConvexHTTPClient, role: String) async {
        conversationRole = role
        do {
            conversations = try await client.query(
                "conversations:listConversations",
                args: ["role": role, "limit": 50]
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshJobs(client: ConvexHTTPClient, statusGroup: String) async {
        jobsStatusGroup = statusGroup
        do {
            jobs = try await client.query(
                "jobs:listJobs",
                args: ["statusGroup": statusGroup, "limit": 50]
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func syncLocation(client: ConvexHTTPClient, lat: Double, lng: Double, source: String = "manual") async {
        do {
            _ = try await client.mutation(
                "users:updateLocation",
                args: ["lat": lat, "lng": lng, "source": source]
            ) as ConvexID
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadTaskerDetail(client: ConvexHTTPClient, taskerId: ConvexID) async {
        do {
            selectedTasker = try await client.query("taskers:getTaskerById", args: ["taskerId": taskerId])
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadConversation(client: ConvexHTTPClient, conversationId: ConvexID) async {
        do {
            selectedConversation = try await client.query(
                "conversations:getConversation",
                args: ["conversationId": conversationId]
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func searchTaskers(
        client: ConvexHTTPClient,
        categorySlug: String?,
        radiusKm: Int,
        excludeCurrentUserWhenTasker: Bool
    ) async {
        do {
            var args: [String: Any] = [
                "lat": AppConfig.defaultLatitude,
                "lng": AppConfig.defaultLongitude,
                "radiusKm": radiusKm,
                "limit": 50,
            ]
            if let categorySlug {
                args["categorySlug"] = categorySlug
            }
            if excludeCurrentUserWhenTasker,
               currentUser?.roles?.isTasker == true,
               let currentUserId = currentUser?.id {
                args["excludeUserId"] = currentUserId
            }

            taskers = try await client.query("search:searchTaskers", args: args)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
