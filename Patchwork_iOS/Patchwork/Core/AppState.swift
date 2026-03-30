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
    var categoriesErrorMessage: String?
    var isLoadingCategories = false
    var taskers: [TaskerSummary] = []
    var favouriteTaskers: [TaskerSummary] = []
    var conversations: [ConversationSummary] = []
    var jobs: [JobSummary] = []
    var currentUser: CurrentUser?
    var taskerProfile: TaskerProfileSelf?

    var activeCategorySlug: String?
    var selectedTasker: TaskerDetail?
    var selectedConversation: ConversationDetail?

    var conversationRole = "seeker"
    var jobsStatusGroup = "active"

    var searchRadius = 25

    var taskerDisplayName = ""
    var taskerBio = ""
    var taskerHourlyRate = ""

    var lastError: String?

    func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    func presentError(_ error: Error, prefix: String? = nil) {
        guard !isCancellationError(error) else {
            return
        }

        if let prefix {
            lastError = "\(prefix): \(error.localizedDescription)"
        } else {
            lastError = error.localizedDescription
        }
    }

    func loadBootstrapData(client: ConvexHTTPClient) async {
        isBootstrapped = false
        await refreshCategories(client: client)
        await refreshAuthedData(client: client, surfaceErrors: false, shouldRefreshCategories: false)
        if currentUser != nil {
            await searchTaskers(
                client: client,
                categorySlug: activeCategorySlug,
                radiusKm: searchRadius,
                excludeCurrentUserWhenTasker: true
            )
        } else {
            taskers = []
        }
        isBootstrapped = true
    }

    func refreshCategories(client: ConvexHTTPClient) async {
        isLoadingCategories = true
        defer { isLoadingCategories = false }

        do {
            categories = try await client.query("categories:listCategories", args: [:])
            categoriesErrorMessage = nil
        } catch {
            categories = []
            categoriesErrorMessage = error.localizedDescription
        }
    }

    func refreshAuthedData(
        client: ConvexHTTPClient,
        surfaceErrors: Bool = true,
        shouldRefreshCategories: Bool = true
    ) async {
        if shouldRefreshCategories {
            await refreshCategories(client: client)
        }

        let previousCurrentUser = currentUser
        let previousConversations = conversations
        let previousJobs = jobs
        let previousTaskerProfile = taskerProfile
        do {
            let fetchedCurrentUser: CurrentUser? = try await client.query("users:getCurrentUser", args: [:])
            guard let fetchedCurrentUser else {
                if let previousCurrentUser {
                    currentUser = previousCurrentUser
                    conversations = previousConversations
                    jobs = previousJobs
                    taskerProfile = previousTaskerProfile
                    return
                }

                currentUser = nil
                conversations = []
                jobs = []
                taskerProfile = nil
                return
            }

            currentUser = fetchedCurrentUser

            do {
                conversations = try await client.query(
                    "conversations:listConversations",
                    args: ["role": conversationRole, "limit": 50]
                )
            } catch {
                conversations = previousConversations
            }

            do {
                jobs = try await client.query(
                    "jobs:listJobs",
                    args: ["statusGroup": jobsStatusGroup, "limit": 50]
                )
            } catch {
                jobs = previousJobs
            }

            do {
                taskerProfile = try await client.query("taskers:getTaskerProfile", args: [:])
            } catch {
                taskerProfile = previousTaskerProfile
            }
        } catch {
            currentUser = previousCurrentUser
            conversations = previousConversations
            jobs = previousJobs
            taskerProfile = previousTaskerProfile
            if surfaceErrors && previousCurrentUser == nil {
                presentError(error, prefix: "Failed to refresh signed-in data")
            }
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
            presentError(error, prefix: "Failed to refresh conversations")
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
            presentError(error, prefix: "Failed to refresh jobs")
        }
    }

    @discardableResult
    func syncLocation(client: ConvexHTTPClient, lat: Double, lng: Double, source: String = "manual") async -> Bool {
        do {
            _ = try await client.mutation(
                "users:updateLocation",
                args: ["lat": lat, "lng": lng, "source": source]
            ) as ConvexID
            return true
        } catch {
            presentError(error, prefix: "Failed to sync location")
            return false
        }
    }

    func loadTaskerDetail(client: ConvexHTTPClient, taskerId: ConvexID) async {
        do {
            selectedTasker = try await client.query("taskers:getTaskerById", args: ["taskerId": taskerId])
        } catch {
            presentError(error, prefix: "Failed to load tasker details")
        }
    }

    func loadConversation(client: ConvexHTTPClient, conversationId: ConvexID) async {
        do {
            selectedConversation = try await client.query(
                "conversations:getConversation",
                args: ["conversationId": conversationId]
            )
        } catch {
            presentError(error, prefix: "Failed to load conversation")
        }
    }

    func openConversation(client: ConvexHTTPClient, conversationId: ConvexID, role: String) async {
        conversationRole = role
        selectedConversation = nil
        selectedTab = .messages
        await loadConversation(client: client, conversationId: conversationId)
        await refreshConversations(client: client, role: role)
    }

    func searchTaskers(
        client: ConvexHTTPClient,
        categorySlug: String?,
        radiusKm: Int,
        excludeCurrentUserWhenTasker: Bool
    ) async {
        do {
            guard let currentCoordinates = currentUser?.location?.coordinates else {
                taskers = []
                return
            }
            var args: [String: Any] = [
                "lat": currentCoordinates.lat,
                "lng": currentCoordinates.lng,
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
            if isCancellationError(error) {
                return
            }
            presentError(error, prefix: "Failed to search taskers")
        }
    }

    func refreshTaskers(
        client: ConvexHTTPClient,
        categorySlug: String? = nil,
        radiusKm: Int? = nil,
        excludeCurrentUserWhenTasker: Bool = true
    ) async {
        await searchTaskers(
            client: client,
            categorySlug: categorySlug ?? activeCategorySlug,
            radiusKm: radiusKm ?? searchRadius,
            excludeCurrentUserWhenTasker: excludeCurrentUserWhenTasker
        )
    }

    func refreshFavouriteTaskers(client: ConvexHTTPClient) async {
        do {
            favouriteTaskers = try await client.query(
                "taskers:listFavouriteTaskers",
                args: ["limit": 50]
            )
        } catch {
            if isCancellationError(error) {
                return
            }
            presentError(error, prefix: "Failed to load favourites")
        }
    }

    func resetForSignedOutSession() {
        selectedTab = .home
        isBootstrapped = false
        taskers = []
        favouriteTaskers = []
        conversations = []
        jobs = []
        currentUser = nil
        taskerProfile = nil
        selectedTasker = nil
        selectedConversation = nil
        categoriesErrorMessage = nil
        isLoadingCategories = false
        lastError = nil
    }
}
