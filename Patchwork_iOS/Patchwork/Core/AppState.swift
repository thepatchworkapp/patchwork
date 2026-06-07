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
    var categoryGroups: [CategoryGroup] = []
    var categoriesErrorMessage: String?
    var isLoadingCategories = false
    var taskers: [TaskerSummary] = []
    var favouriteTaskers: [TaskerSummary] = []
    var blockedUsers: [BlockedUserSummary] = []
    var conversations: [ConversationSummary] = []
    var jobs: [JobSummary] = []
    var currentUser: CurrentUser?
    private(set) var hasConfirmedMissingCurrentUser = false
    private(set) var hasFailedCurrentUserRefreshWithoutPrevious = false
    private(set) var currentUserRefreshFailure: Error?
    var taskerProfile: TaskerProfileSelf?

    var activeCategorySlug: String?
    var activeCategorySlugs: [String] = []
    var discoverSearchOrigin: DiscoverSearchOrigin?
    var selectedTasker: TaskerDetail?
    var selectedConversation: ConversationDetail?

    var conversationRole = "seeker"
    var jobsStatusGroup = "active"

    var searchRadius = 25

    var taskerDisplayName = ""
    var taskerBio = ""
    var taskerHourlyRate = ""

    var lastError: String?
    private(set) var signInRequiredAuthFailureID: UUID?
    private var latestCategoryRefreshRequestID: UUID?
    private var latestTaskerSearchRequestID: UUID?

    private enum CurrentUserRefreshResult {
        case user(CurrentUser)
        case preservedPrevious(CurrentUser)
        case missingWithoutPrevious
        case failedWithoutPrevious
    }

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

        if isAuthRequestFailure(error) {
            recordSignInRequiredAuthFailure()
            return
        }

        if let prefix {
            lastError = "\(prefix): \(error.localizedDescription)"
        } else {
            lastError = error.localizedDescription
        }
    }

    private func isAuthRequestFailure(_ error: Error) -> Bool {
        if case let PatchworkError.authRefreshFailed(statusCode, message) = error {
            if statusCode == 401 || statusCode == 403 {
                return true
            }
            return Self.isTerminalAuthFailureMessage(message, includesGenericAuthRequestFailure: true)
        }

        if case PatchworkError.missingToken = error {
            return true
        }

        return Self.isTerminalAuthFailureMessage(
            error.localizedDescription,
            includesGenericAuthRequestFailure: true
        )
    }

    private static func isGenericAuthenticationRequestFailure(_ message: String) -> Bool {
        let normalized = message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized == "authentication request failed." || normalized == "authentication request failed"
    }

    private static func isTerminalAuthFailureMessage(
        _ message: String,
        includesGenericAuthRequestFailure: Bool
    ) -> Bool {
        let normalized = message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if includesGenericAuthRequestFailure,
           Self.isGenericAuthenticationRequestFailure(message) {
            return true
        }

        let authFailurePhrases = [
            "unauthorized",
            "forbidden",
            "not authenticated",
            "authentication expired",
            "authentication required",
            "session expired",
            "expired session",
            "invalid session",
            "session is invalid",
            "token expired",
            "expired token",
            "invalid token",
            "token is invalid",
            "invalid jwt",
            "jwt expired",
        ]
        return authFailurePhrases.contains(where: { normalized.contains($0) })
    }

    private func recordSignInRequiredAuthFailure() {
        lastError = nil
        categoriesErrorMessage = nil
        signInRequiredAuthFailureID = UUID()
    }

    func clearSignInRequiredAuthFailure() {
        signInRequiredAuthFailureID = nil
    }

    func loadBootstrapData(client: ConvexHTTPClient) async {
        isBootstrapped = false
        hasConfirmedMissingCurrentUser = false
        await refreshCategories(client: client)
        guard signInRequiredAuthFailureID == nil else {
            return
        }
        await refreshAuthedData(client: client, surfaceErrors: false, shouldRefreshCategories: false)
        guard signInRequiredAuthFailureID == nil else {
            return
        }
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
        guard signInRequiredAuthFailureID == nil else {
            return
        }
        isBootstrapped = true
    }

    func refreshCategories(client: ConvexHTTPClient) async {
        let requestID = UUID()
        latestCategoryRefreshRequestID = requestID
        isLoadingCategories = true
        defer {
            if latestCategoryRefreshRequestID == requestID {
                isLoadingCategories = false
            }
        }

        do {
            let api = PatchworkAPI(client: client)
            async let categoryList = api.categories.list()
            async let groupList = api.categories.listGroups()
            let fetchedCategories = try await categoryList
            let fetchedGroups = try await groupList
            guard latestCategoryRefreshRequestID == requestID else {
                return
            }
            categories = fetchedCategories
            categoryGroups = fetchedGroups
            categoriesErrorMessage = nil
        } catch {
            guard latestCategoryRefreshRequestID == requestID else {
                return
            }
            if isCancellationError(error) {
                return
            }
            if isAuthRequestFailure(error) {
                recordSignInRequiredAuthFailure()
                return
            }
            categoriesErrorMessage = "We couldn't refresh categories. Please try again."
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

        let previousConversations = conversations
        let previousJobs = jobs
        let previousTaskerProfile = taskerProfile

        switch await refreshCurrentUserResult(client: client, surfaceErrors: surfaceErrors) {
        case .user, .preservedPrevious:
            break
        case .missingWithoutPrevious:
            conversations = []
            jobs = []
            taskerProfile = nil
            return
        case .failedWithoutPrevious:
            conversations = previousConversations
            jobs = previousJobs
            taskerProfile = previousTaskerProfile
            return
        }

        await refreshDashboardLists(client: client, surfaceErrors: false)
        await refreshTaskerProfile(client: client, surfaceErrors: false)
    }

    @discardableResult
    func refreshCurrentUser(client: ConvexHTTPClient, surfaceErrors: Bool = true) async -> CurrentUser? {
        switch await refreshCurrentUserResult(client: client, surfaceErrors: surfaceErrors) {
        case let .user(currentUser), let .preservedPrevious(currentUser):
            return currentUser
        case .missingWithoutPrevious, .failedWithoutPrevious:
            return nil
        }
    }

    private func refreshCurrentUserResult(
        client: ConvexHTTPClient,
        surfaceErrors: Bool
    ) async -> CurrentUserRefreshResult {
        let previousCurrentUser = currentUser
        do {
            let fetchedCurrentUser = try await PatchworkAPI(client: client).users.current()
            guard let fetchedCurrentUser else {
                if let previousCurrentUser {
                    currentUser = previousCurrentUser
                    hasConfirmedMissingCurrentUser = false
                    hasFailedCurrentUserRefreshWithoutPrevious = false
                    currentUserRefreshFailure = nil
                    return .preservedPrevious(previousCurrentUser)
                }

                currentUser = nil
                hasConfirmedMissingCurrentUser = true
                hasFailedCurrentUserRefreshWithoutPrevious = false
                currentUserRefreshFailure = nil
                return .missingWithoutPrevious
            }

            currentUser = fetchedCurrentUser
            hasConfirmedMissingCurrentUser = false
            hasFailedCurrentUserRefreshWithoutPrevious = false
            currentUserRefreshFailure = nil
            return .user(fetchedCurrentUser)
        } catch {
            currentUser = previousCurrentUser
            hasConfirmedMissingCurrentUser = false
            hasFailedCurrentUserRefreshWithoutPrevious = previousCurrentUser == nil
            currentUserRefreshFailure = previousCurrentUser == nil ? error : nil
            if surfaceErrors && previousCurrentUser == nil {
                presentError(error, prefix: "Failed to refresh signed-in data")
            }
            if let previousCurrentUser {
                return .preservedPrevious(previousCurrentUser)
            }
            return .failedWithoutPrevious
        }
    }

    func refreshTaskerProfile(client: ConvexHTTPClient, surfaceErrors: Bool = true) async {
        let previousTaskerProfile = taskerProfile
        do {
            taskerProfile = try await PatchworkAPI(client: client).taskers.currentProfile()
        } catch {
            taskerProfile = previousTaskerProfile
            if surfaceErrors {
                presentError(error, prefix: "Failed to refresh tasker profile")
            }
        }
    }

    func refreshDashboardLists(client: ConvexHTTPClient, surfaceErrors: Bool = true) async {
        await refreshConversations(client: client, role: conversationRole, surfaceErrors: surfaceErrors)
        await refreshJobs(client: client, statusGroup: jobsStatusGroup, surfaceErrors: surfaceErrors)
    }

    func refreshConversations(client: ConvexHTTPClient, role: String, surfaceErrors: Bool = true) async {
        conversationRole = role
        do {
            conversations = try await PatchworkAPI(client: client).conversations.list(
                role: role,
                limit: Self.defaultListLimit
            )
            let unreadBadgeCount = try? await PatchworkAPI(client: client).users.unreadBadgeCount()
            PatchworkNotificationCenter.updateAppBadge(unreadBadgeCount ?? totalUnreadCount(conversations))
            prefetchConversationImages(conversations)
        } catch {
            if surfaceErrors {
                presentError(error, prefix: "Failed to refresh conversations")
            }
        }
    }

    func refreshJobs(client: ConvexHTTPClient, statusGroup: String, surfaceErrors: Bool = true) async {
        jobsStatusGroup = statusGroup
        do {
            jobs = try await PatchworkAPI(client: client).jobs.list(
                statusGroup: statusGroup,
                limit: Self.defaultListLimit
            )
            prefetchJobImages(jobs)
        } catch {
            if surfaceErrors {
                presentError(error, prefix: "Failed to refresh jobs")
            }
        }
    }

    @discardableResult
    func syncLocation(
        client: ConvexHTTPClient,
        lat: Double,
        lng: Double,
        source: String = "manual",
        surfaceErrors: Bool = true
    ) async -> Bool {
        do {
            if source == "gps" {
                try await PatchworkAPI(client: client).users.checkInGpsLocation(lat: lat, lng: lng)
            } else {
                try await PatchworkAPI(client: client).users.updateLocation(lat: lat, lng: lng, source: source)
            }
            return true
        } catch {
            if surfaceErrors {
                presentError(error, prefix: "Failed to sync location")
            }
            return false
        }
    }

    func loadTaskerDetail(client: ConvexHTTPClient, taskerId: ConvexID) async {
        do {
            selectedTasker = try await PatchworkAPI(client: client).taskers.get(taskerId: taskerId)
            if let selectedTasker {
                prefetchTaskerDetailImages(selectedTasker)
            }
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
        categorySlugs: [String]? = nil,
        searchOrigin: DiscoverSearchOrigin? = nil,
        radiusKm: Int,
        excludeCurrentUserWhenTasker: Bool
    ) async {
        let requestID = UUID()
        latestTaskerSearchRequestID = requestID
        do {
            if let searchOrigin {
                discoverSearchOrigin = searchOrigin
            }

            guard let resolvedSearchOrigin = searchOrigin ?? discoverSearchOrigin else {
                guard latestTaskerSearchRequestID == requestID else {
                    return
                }
                taskers = []
                return
            }
            let currentCoordinates = resolvedSearchOrigin.coordinates
            let excludeUserId: ConvexID?
            if excludeCurrentUserWhenTasker,
               currentUser?.roles?.isTasker == true,
               let currentUserId = currentUser?.id {
                excludeUserId = currentUserId
            } else {
                excludeUserId = nil
            }

            let results = try await PatchworkAPI(client: client).search.taskers(
                lat: currentCoordinates.lat,
                lng: currentCoordinates.lng,
                radiusKm: radiusKm,
                limit: Self.defaultListLimit,
                categorySlug: categorySlug,
                categorySlugs: categorySlugs,
                excludeUserId: excludeUserId
            )
            guard latestTaskerSearchRequestID == requestID else {
                return
            }
            taskers = results
            prefetchTaskerImages(taskers)
        } catch {
            guard latestTaskerSearchRequestID == requestID else {
                return
            }
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
            categorySlugs: activeCategorySlugs.isEmpty ? nil : activeCategorySlugs,
            searchOrigin: discoverSearchOrigin,
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
        latestCategoryRefreshRequestID = nil
        latestTaskerSearchRequestID = nil
        favouriteTaskers = []
        blockedUsers = []
        conversations = []
        jobs = []
        currentUser = nil
        hasConfirmedMissingCurrentUser = false
        hasFailedCurrentUserRefreshWithoutPrevious = false
        currentUserRefreshFailure = nil
        taskerProfile = nil
        selectedTasker = nil
        selectedConversation = nil
        categoriesErrorMessage = nil
        isLoadingCategories = false
        activeCategorySlug = nil
        activeCategorySlugs = []
        discoverSearchOrigin = nil
        lastError = nil
        signInRequiredAuthFailureID = nil
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

    private func prefetchTaskerDetailImages(_ tasker: TaskerDetail) {
        let firstCategory = tasker.categoryProfiles.first
        var requests = [
            PatchworkImageCache.PrefetchRequest(
                asset: tasker.profileImage,
                preferredVariant: .thumb,
                legacyURL: tasker.userPhotoUrl
            ),
            PatchworkImageCache.PrefetchRequest(
                asset: firstCategory?.coverImage ?? firstCategory?.portfolioImages?.first,
                preferredVariant: .large,
                legacyURL: firstCategory?.firstPhotoUrl
            ),
        ]

        requests.append(contentsOf: (firstCategory?.portfolioImages ?? []).prefix(Self.imagePrefetchCount).map { asset in
            PatchworkImageCache.PrefetchRequest(
                asset: asset,
                preferredVariant: .display
            )
        })

        Task(priority: .utility) {
            await PatchworkImageCache.shared.prefetch(requests: requests)
        }
    }

    private func totalUnreadCount(_ conversations: [ConversationSummary]) -> Int {
        conversations.reduce(0) { total, conversation in
            total + (conversation.seekerUnreadCount ?? 0) + (conversation.taskerUnreadCount ?? 0)
        }
    }
}
