import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private static let imagePrefetchCount = 12
    private static let defaultListLimit = 50

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
    var blockedUsers: [BlockedUserSummary] = []
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
            categories = try await PatchworkAPI(client: client).categories.list()
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
        let api = PatchworkAPI(client: client)
        do {
            let fetchedCurrentUser = try await api.users.current()
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
                conversations = try await api.conversations.list(
                    role: conversationRole,
                    limit: Self.defaultListLimit
                )
                prefetchConversationImages(conversations)
            } catch {
                conversations = previousConversations
            }

            do {
                jobs = try await api.jobs.list(
                    statusGroup: jobsStatusGroup,
                    limit: Self.defaultListLimit
                )
                prefetchJobImages(jobs)
            } catch {
                jobs = previousJobs
            }

            do {
                taskerProfile = try await api.taskers.currentProfile()
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
            conversations = try await PatchworkAPI(client: client).conversations.list(
                role: role,
                limit: Self.defaultListLimit
            )
            prefetchConversationImages(conversations)
        } catch {
            presentError(error, prefix: "Failed to refresh conversations")
        }
    }

    func refreshJobs(client: ConvexHTTPClient, statusGroup: String) async {
        jobsStatusGroup = statusGroup
        do {
            jobs = try await PatchworkAPI(client: client).jobs.list(
                statusGroup: statusGroup,
                limit: Self.defaultListLimit
            )
            prefetchJobImages(jobs)
        } catch {
            presentError(error, prefix: "Failed to refresh jobs")
        }
    }

    @discardableResult
    func syncLocation(client: ConvexHTTPClient, lat: Double, lng: Double, source: String = "manual") async -> Bool {
        do {
            try await PatchworkAPI(client: client).users.updateLocation(lat: lat, lng: lng, source: source)
            return true
        } catch {
            presentError(error, prefix: "Failed to sync location")
            return false
        }
    }

    func loadTaskerDetail(client: ConvexHTTPClient, taskerId: ConvexID) async {
        do {
            selectedTasker = try await PatchworkAPI(client: client).taskers.get(taskerId: taskerId)
        } catch {
            presentError(error, prefix: "Failed to load tasker details")
        }
    }

    func loadConversation(client: ConvexHTTPClient, conversationId: ConvexID) async {
        do {
            selectedConversation = try await PatchworkAPI(client: client).conversations.get(
                conversationId: conversationId
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
            let excludeUserId: ConvexID?
            if excludeCurrentUserWhenTasker,
               currentUser?.roles?.isTasker == true,
               let currentUserId = currentUser?.id {
                excludeUserId = currentUserId
            } else {
                excludeUserId = nil
            }

            taskers = try await PatchworkAPI(client: client).search.taskers(
                lat: currentCoordinates.lat,
                lng: currentCoordinates.lng,
                radiusKm: radiusKm,
                limit: Self.defaultListLimit,
                categorySlug: categorySlug,
                excludeUserId: excludeUserId
            )
            prefetchTaskerImages(taskers)
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
            favouriteTaskers = try await PatchworkAPI(client: client).taskers.listFavourites(
                limit: Self.defaultListLimit
            )
        } catch {
            if isCancellationError(error) {
                return
            }
            presentError(error, prefix: "Failed to load favourites")
        }
    }

    func refreshBlockedUsers(client: ConvexHTTPClient) async {
        do {
            blockedUsers = try await PatchworkAPI(client: client).moderation.listBlockedUsers(
                limit: Self.defaultListLimit
            )
            prefetchBlockedUserImages(blockedUsers)
        } catch {
            if isCancellationError(error) {
                return
            }
            presentError(error, prefix: "Failed to load blocked users")
        }
    }

    func resetForSignedOutSession() {
        selectedTab = .home
        isBootstrapped = false
        taskers = []
        favouriteTaskers = []
        blockedUsers = []
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

    private func prefetchTaskerImages(_ taskers: [TaskerSummary]) {
        let targets = taskers.prefix(Self.imagePrefetchCount)
        let requests = targets.flatMap { tasker in
            [
                PatchworkImageCache.PrefetchRequest(
                    asset: tasker.avatarImage,
                    preferredVariant: .thumb,
                    legacyURL: tasker.avatarUrl
                ),
                PatchworkImageCache.PrefetchRequest(
                    asset: tasker.categoryCoverImage,
                    preferredVariant: .display,
                    legacyURL: tasker.categoryPhotoUrl
                ),
            ]
        }
        guard !requests.isEmpty else { return }
        Task(priority: .utility) {
            await PatchworkImageCache.shared.prefetch(requests: requests)
        }
    }

    private func prefetchBlockedUserImages(_ users: [BlockedUserSummary]) {
        let requests = users.prefix(Self.imagePrefetchCount).map { user in
            PatchworkImageCache.PrefetchRequest(
                asset: user.photoImage,
                preferredVariant: .thumb,
                legacyURL: user.photoUrl
            )
        }
        guard !requests.isEmpty else { return }
        Task(priority: .utility) {
            await PatchworkImageCache.shared.prefetch(requests: requests)
        }
    }

    private func prefetchConversationImages(_ conversations: [ConversationSummary]) {
        let requests = conversations.prefix(Self.imagePrefetchCount).map { conversation in
            PatchworkImageCache.PrefetchRequest(
                asset: conversation.participantImage,
                preferredVariant: .thumb,
                legacyURL: conversation.participantPhotoUrl
            )
        }
        guard !requests.isEmpty else { return }
        Task(priority: .utility) {
            await PatchworkImageCache.shared.prefetch(requests: requests)
        }
    }

    private func prefetchJobImages(_ jobs: [JobSummary]) {
        let requests = jobs.prefix(Self.imagePrefetchCount).map { job in
            PatchworkImageCache.PrefetchRequest(
                asset: job.counterpartyImage,
                preferredVariant: .thumb,
                legacyURL: job.counterpartyPhotoUrl
            )
        }
        guard !requests.isEmpty else { return }
        Task(priority: .utility) {
            await PatchworkImageCache.shared.prefetch(requests: requests)
        }
    }
}
