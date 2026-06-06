import CoreLocation
import SwiftUI
import UIKit
import UserNotifications

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SessionStore.self) private var sessionStore
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager
    @Environment(RevenueCatManager.self) private var revenueCatManager
    @State private var locationPromptCompletedForSession = false
    @State private var locationPromptSessionUserId: ConvexID?
    @State private var isForegroundRefreshPending = false
    @State private var isResolvingPersistedMissingCurrentUser = false
    @State private var attemptedPersistedMissingCurrentUserValidationKey: String?
    @State private var isProfileSetupInProgress = false
    @AppStorage("Patchwork.remoteNotificationDeviceToken") private var remoteNotificationDeviceToken = ""
#if DEBUG
    @State private var didApplyVisualPreview = false
#endif

    var body: some View {
#if DEBUG
        if debugVisualPreviewEnabled {
            MainTabView()
                .task {
                    revenueCatManager.configureIfNeeded()
                    applyDebugVisualPreviewIfNeeded()
                }
        } else {
            liveRoot
        }
#else
        liveRoot
#endif
    }

    private var liveRoot: some View {
        Group {
            if sessionStore.isAuthenticated {
                if shouldShowForegroundRefreshLoading {
                    PatchworkBrandLoadingCard()
                } else if shouldShowSessionRestoreLoading {
                    PatchworkBrandLoadingCard()
                } else if !appState.isBootstrapped {
                    PatchworkBrandLoadingCard()
                        .task {
                            applyCachedCurrentUserIfNeeded()
                            await appState.loadBootstrapData(client: sessionStore.client)
                            if clearInvalidPersistedCredentialIfNeeded() {
                                return
                            }
                            storeCurrentUserSnapshotIfAvailable()
                        }
                } else if profileSetupRoutePolicy.shouldShowProfileSetup {
                    if shouldShowPersistedCurrentUserResolutionLoading
                        || shouldShowPersistedMissingCurrentUserValidationLoading {
                        PatchworkBrandLoadingCard()
                    } else {
                        ProfileSetupView {
                            isProfileSetupInProgress = false
                        }
                        .onAppear {
                            startProfileSetup()
                        }
                    }
                } else if needsLocationPrompt {
                    LocationPermissionGateView(
                        onAllow: {
                            let didSync = await requestAndSyncCurrentLocation(source: "gps")
                            if didSync {
                                markLocationPromptCompletedForCurrentSession()
                            }
                        },
                        onSkip: {
                            markLocationPromptCompletedForCurrentSession()
                        }
                    )
                } else {
                    MainTabView()
                }
            } else {
                AuthFlowView()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { sessionStore.isAuthenticated && appState.lastError != nil },
            set: { _ in appState.lastError = nil }
        )) {
            Button("OK", role: .cancel) {}
                .accessibilityLabel("Dismiss error")
                .accessibilityIdentifier("Root.errorAlertOKButton")
        } message: {
            Text(appState.lastError ?? "")
        }
        .task {
            revenueCatManager.configureIfNeeded()
        }
        .task {
            applyCachedCurrentUserIfNeeded()
            await restoreSessionAndRefreshIfNeeded(forceRefresh: false)
        }
        .task(id: persistedMissingCurrentUserValidationKey) {
            await validatePersistedMissingCurrentUserIfNeeded(validationKey: persistedMissingCurrentUserValidationKey)
        }
        .task(id: appState.signInRequiredAuthFailureID) {
            clearInvalidPersistedCredentialAfterAuthFailureIfNeeded()
        }
        .task(id: revenueCatIdentityKey) {
            let userID = sessionStore.isAuthenticated ? appState.currentUser?.id : nil
            await revenueCatManager.syncIdentity(
                currentUserID: userID,
                appState: appState,
                client: sessionStore.client
            )
            await reconcileRevenueCatWithBackendIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }
            guard sessionStore.isAuthenticated else {
                return
            }
            isForegroundRefreshPending = true
            Task { @MainActor in
                defer { isForegroundRefreshPending = false }
                await restoreSessionAndRefreshIfNeeded(forceRefresh: false)
                await reconcileRevenueCatWithBackendIfNeeded()
                await syncAuthorizedDeviceLocationIfAvailable()
            }
        }
        .onChange(of: sessionStore.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                appState.resetForSignedOutSession()
                locationPromptCompletedForSession = false
                locationPromptSessionUserId = nil
                isForegroundRefreshPending = false
                isResolvingPersistedMissingCurrentUser = false
                attemptedPersistedMissingCurrentUserValidationKey = nil
                isProfileSetupInProgress = false
            }
        }
        .onChange(of: appState.currentUser?.id) { _, newUserId in
            locationPromptCompletedForSession = false
            locationPromptSessionUserId = newUserId
        }
        .onChange(of: appState.currentUser) { _, currentUser in
            sessionStore.storeCurrentUserSnapshot(currentUser)
        }
        .task(id: periodicLocationSyncKey) {
            await periodicallySyncAuthorizedLocation()
        }
        .task(id: periodicSessionRefreshKey) {
            await periodicallyRefreshSession()
        }
        .task(id: pushRegistrationKey) {
            await registerPushTokenIfNeeded()
            await refreshUnreadBadgeCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: PatchworkNotificationCenter.foregroundConversationNotification)) { notification in
            handleForegroundConversationNotification(notification)
        }
    }

    private var shouldShowForegroundRefreshLoading: Bool {
        rootLoadingPolicy.shouldShowForegroundRefreshLoading
    }

    private var shouldShowSessionRestoreLoading: Bool {
        rootLoadingPolicy.shouldShowSessionRestoreLoading
    }

    private var rootLoadingPolicy: RootLoadingPolicy {
        RootLoadingPolicy(
            isAuthenticated: sessionStore.isAuthenticated,
            isRestoringSession: sessionStore.isRestoringSession,
            needsSessionRestore: sessionStore.needsSessionRestore,
            hasAttemptedSessionRestore: sessionStore.hasAttemptedSessionRestore,
            isForegroundRefreshPending: isForegroundRefreshPending,
            isBootstrapped: appState.isBootstrapped,
            hasCurrentUser: appState.currentUser != nil,
            launchedWithPersistedSession: sessionStore.launchedWithPersistedSession,
            hasConfirmedMissingCurrentUser: appState.hasConfirmedMissingCurrentUser,
            hasFailedCurrentUserRefreshWithoutPrevious: appState.hasFailedCurrentUserRefreshWithoutPrevious
        )
    }

    private var profileSetupRoutePolicy: ProfileSetupRoutePolicy {
        ProfileSetupRoutePolicy(
            hasCurrentUser: appState.currentUser != nil,
            isProfileSetupInProgress: isProfileSetupInProgress
        )
    }

    private var periodicSessionRefreshKey: String {
        sessionStore.isAuthenticated ? "authenticated" : "signed-out"
    }

    private var pushRegistrationKey: String {
        [
            sessionStore.isAuthenticated ? "authenticated" : "signed-out",
            appState.currentUser?.id ?? "no-user",
            appState.currentUser?.settings?.notificationsEnabled.map { String($0) } ?? "notifications-unknown",
            remoteNotificationDeviceToken,
        ].joined(separator: "|")
    }

#if DEBUG
    private var debugVisualPreviewEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_EMPTY_TABS")
        || ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_TASKER_BILLING_PREVIEW_UNPAID")
    }

    private func applyDebugVisualPreviewIfNeeded() {
        guard debugVisualPreviewEnabled, !didApplyVisualPreview else {
            return
        }

        didApplyVisualPreview = true
        appState.resetForSignedOutSession()
        appState.isBootstrapped = true
        let showsBillingPreview = ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_TASKER_BILLING_PREVIEW_UNPAID")
        appState.selectedTab = showsBillingPreview ? .profile : .home
        appState.searchRadius = 25
        appState.categories = [
            Category(id: "category-interior-cleaning-services", name: "Interior Cleaning Services", slug: "interior-cleaning-services", emoji: nil, group: "Home & Garden"),
            Category(id: "category-plumber", name: "Plumber", slug: "plumber", emoji: nil, group: "Home & Garden"),
            Category(id: "category-electrician", name: "Electrician", slug: "electrician", emoji: nil, group: "Technical"),
        ]
        appState.currentUser = CurrentUser(
            id: "debug-preview-user",
            email: "preview@patchwork.app",
            name: "Preview User",
            roles: UserRoles(isSeeker: true, isTasker: true),
            location: UserLocation(
                city: "Waterloo",
                province: "On",
                coordinates: Coordinates(lat: 43.4643, lng: -80.5204),
                gpsCoordinates: GPSCoordinates(lat: 43.4643, lng: -80.5204, checkedInAt: 1)
            ),
            settings: UserSettings(notificationsEnabled: true, locationEnabled: true),
            createdAt: nil,
            photoImage: nil
        )
        appState.taskerProfile = TaskerProfileSelf(
            id: "debug-tasker-profile",
            displayName: "Preview User",
            bio: "Reliable local help for same-week household jobs.",
            websiteLinks: ["https://example.com/preview"],
            socialLinks: ["https://instagram.com/preview"],
            subscriptionPlan: showsBillingPreview ? "none" : "tasker",
            subscriptionAccessType: showsBillingPreview ? nil : "subscription",
            subscriptionActiveAccessTypes: showsBillingPreview ? [] : ["subscription"],
            subscriptionStatus: showsBillingPreview ? "inactive" : "active",
            subscriptionEndsAt: nil,
            hasActiveSubscription: !showsBillingPreview,
            ghostMode: false,
            rating: 4.9,
            reviewCount: 28,
            completedJobs: 42,
            verified: true,
            responseTime: "Replies within 1 hour",
            createdAt: 1_704_067_200_000,
            photoSource: "user",
            photoImage: nil,
            categories: [
                TaskerManagedCategory(
                    id: "debug-tasker-category-interior-cleaning-services",
                    categoryId: "category-interior-cleaning-services",
                    categoryName: "Interior Cleaning Services",
                    categorySlug: "interior-cleaning-services",
                    bio: "Recurring home cleaning and turnover prep.",
                    rateType: "hourly",
                    hourlyRate: 4500,
                    fixedRate: nil,
                    serviceRadius: 25,
                    rating: 4.8,
                    reviewCount: 18,
                    completedJobs: 24,
                    coverAssetId: nil,
                    coverImage: nil,
                    portfolioImages: nil
                ),
                TaskerManagedCategory(
                    id: "debug-tasker-category-plumber",
                    categoryId: "category-plumber",
                    categoryName: "Plumber",
                    categorySlug: "plumber",
                    bio: "Fixture swaps, leak checks, and small repairs.",
                    rateType: "hourly",
                    hourlyRate: 6500,
                    fixedRate: nil,
                    serviceRadius: 20,
                    rating: 5.0,
                    reviewCount: 10,
                    completedJobs: 18,
                    coverAssetId: nil,
                    coverImage: nil,
                    portfolioImages: nil
                ),
            ]
        )
        appState.favouriteTaskers = [
            TaskerSummary(
                id: "debug-favourite-tasker-1",
                userId: "debug-favourite-user-1",
                displayName: "Avery Stone",
                websiteLinks: ["https://avery.example"],
                socialLinks: ["https://instagram.com/averystone"],
                averageRating: 4.8,
                reviewCount: 31,
                distanceLabel: "4.1 km",
                categoryName: "Interior Cleaning Services",
                rateLabel: "$48/hr",
                verified: true,
                bio: "Recurring home cleaning and deep resets.",
                completedJobs: 64,
                avatarUrl: nil,
                categoryPhotoUrl: nil,
                avatarImage: nil,
                categoryCoverImage: nil
            ),
            TaskerSummary(
                id: "debug-favourite-tasker-2",
                userId: "debug-favourite-user-2",
                displayName: "Jordan Vale",
                websiteLinks: [],
                socialLinks: [],
                averageRating: 5.0,
                reviewCount: 18,
                distanceLabel: "7.8 km",
                categoryName: "Electrician",
                rateLabel: "$72/hr",
                verified: true,
                bio: "Fixture installs, troubleshooting, and panel upgrades.",
                completedJobs: 39,
                avatarUrl: nil,
                categoryPhotoUrl: nil,
                avatarImage: nil,
                categoryCoverImage: nil
            ),
        ]
    }
#endif

    private var revenueCatIdentityKey: String {
        if !sessionStore.isAuthenticated {
            return "signed-out"
        }
        return appState.currentUser?.id ?? "authenticated-no-user"
    }

    private var needsLocationPrompt: Bool {
        guard let user = appState.currentUser else {
            return false
        }
        // Show the iOS location prompt if we haven't shown it before on this device,
        // regardless of whether the backend has locationEnabled from a web session.
        let hasPersistedCompletion = UserDefaults.standard.bool(forKey: locationPromptKey(userId: user.id))
        let hasSessionCompletion = locationPromptCompletedForSession && locationPromptSessionUserId == user.id
        return !(hasPersistedCompletion || hasSessionCompletion)
    }

    private func locationPromptKey(userId: ConvexID) -> String {
        "Patchwork.locationPromptCompleted.\(userId)"
    }

    private var periodicLocationSyncKey: String? {
        guard sessionStore.isAuthenticated,
              let userId = appState.currentUser?.id,
              !needsLocationPrompt else {
            return nil
        }

        return userId
    }

    private func reconcileRevenueCatWithBackendIfNeeded() async {
        guard sessionStore.isAuthenticated,
              revenueCatManager.storeState.hasAccess,
              appState.taskerProfile?.hasActiveSubscription != true else {
            return
        }

        do {
            let reconciledProfile: TaskerProfileSelf? = try await sessionStore.client.action(
                "taskers:reconcileRevenueCatSubscription",
                args: [:]
            )
            if let reconciledProfile {
                appState.taskerProfile = reconciledProfile
            }
        } catch {
            print("[RootView] RevenueCat reconciliation failed: \(error.localizedDescription)")
        }
    }

    private func markLocationPromptCompleted() {
        guard let user = appState.currentUser else {
            return
        }
        UserDefaults.standard.set(true, forKey: locationPromptKey(userId: user.id))
    }

    private func markLocationPromptCompletedForCurrentSession() {
        markLocationPromptCompleted()
        guard let user = appState.currentUser else {
            return
        }
        locationPromptCompletedForSession = true
        locationPromptSessionUserId = user.id
    }

    private func startProfileSetup() {
        guard !isProfileSetupInProgress else {
            return
        }
        isProfileSetupInProgress = true
    }

    private func requestAndSyncCurrentLocation(source: String) async -> Bool {
        let status = await locationManager.requestWhenInUseAuthorizationIfNeeded()
        let coordinate = await requestCoordinateWithRetries()
        let didSync: Bool

        if let coordinate {
            didSync = await syncLocation(coordinate, source: source)
        } else {
            if status == .denied || status == .restricted {
                appState.lastError = "Enable location to appear in nearby searches as a tasker."
            }
            didSync = false
        }

        await appState.refreshAuthedData(client: sessionStore.client)
        return didSync
    }

    private func periodicallySyncAuthorizedLocation() async {
        guard periodicLocationSyncKey != nil else {
            return
        }

        while !Task.isCancelled {
            await syncAuthorizedDeviceLocationIfAvailable()
            try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000)
        }
    }

    private func periodicallyRefreshSession() async {
        guard sessionStore.isAuthenticated else {
            return
        }

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
            guard sessionStore.isAuthenticated else {
                return
            }
            _ = await sessionStore.restorePersistedSessionIfNeeded(forceRefresh: false)
        }
    }

    private func registerPushTokenIfNeeded() async {
        guard sessionStore.isAuthenticated,
              appState.currentUser?.settings?.notificationsEnabled == true,
              !remoteNotificationDeviceToken.isEmpty else {
            return
        }

        do {
            try await PatchworkAPI(client: sessionStore.client).users.registerPushToken(
                remoteNotificationDeviceToken,
                environment: pushTokenEnvironment
            )
        } catch {
            print("[Notifications] Failed to register push token: \(error.localizedDescription)")
        }
    }

    private func refreshUnreadBadgeCount() async {
        guard sessionStore.isAuthenticated,
              appState.currentUser != nil else {
            PatchworkNotificationCenter.updateAppBadge(0)
            return
        }

        do {
            let unreadCount = try await PatchworkAPI(client: sessionStore.client).users.unreadBadgeCount()
            PatchworkNotificationCenter.updateAppBadge(unreadCount)
        } catch {
            print("[Notifications] Failed to refresh badge count: \(error.localizedDescription)")
        }
    }

    private func handleForegroundConversationNotification(_ notification: Notification) {
        guard sessionStore.isAuthenticated,
              appState.currentUser != nil else {
            return
        }

        let conversationId = notification.userInfo?[PatchworkNotificationCenter.conversationIdUserInfoKey] as? ConvexID
        Task { @MainActor in
            if let conversationId,
               PatchworkNotificationCenter.isActiveConversation(conversationId) {
                await refreshUnreadBadgeCount()
                return
            }

            await appState.refreshConversations(
                client: sessionStore.client,
                role: appState.conversationRole,
                surfaceErrors: false
            )
            await refreshUnreadBadgeCount()
        }
    }

    private var pushTokenEnvironment: String {
#if DEBUG
        "sandbox"
#else
        "production"
#endif
    }

    @discardableResult
    private func syncAuthorizedDeviceLocationIfAvailable() async -> Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            break
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        case .authorizedWhenInUse:
            break
#endif
        default:
            return false
        }

        guard let coordinate = await requestCoordinateWithRetries() else {
            return false
        }

        guard let userId = appState.currentUser?.id else {
            return false
        }

        let cachedCoordinate = LocationSyncCache.cachedCoordinate(for: userId)
            ?? appState.currentUser?.location?.gpsCoordinates.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
            }
        guard LocationSyncCache.shouldSyncBackend(
            newCoordinate: coordinate,
            cachedCoordinate: cachedCoordinate
        ) else {
            if cachedCoordinate == nil {
                LocationSyncCache.store(coordinate, for: userId)
            }
            return false
        }

        let didSync = await syncLocation(coordinate, source: "gps")
        if didSync {
            await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)
        }
        return didSync
    }

    private func requestCoordinateWithRetries(maxAttempts: Int = 3) async -> CLLocationCoordinate2D? {
        guard maxAttempts > 0 else {
            return nil
        }

        for attempt in 1 ... maxAttempts {
            if let coordinate = await locationManager.requestCurrentCoordinate() {
                return coordinate
            }
            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        return nil
    }

    @discardableResult
    private func syncLocation(_ coordinate: CLLocationCoordinate2D, source: String) async -> Bool {
        let didSync = await appState.syncLocation(
            client: sessionStore.client,
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            source: source
        )
        if didSync {
            applyLocalLocationUpdate(coordinate)
            if let userId = appState.currentUser?.id {
                LocationSyncCache.store(coordinate, for: userId)
            }
        }
        return didSync
    }

    private func applyLocalLocationUpdate(_ coordinate: CLLocationCoordinate2D) {
        guard let currentUser = appState.currentUser else {
            return
        }

        appState.currentUser = CurrentUser(
            id: currentUser.id,
            email: currentUser.email,
            name: currentUser.name,
            roles: currentUser.roles,
            location: UserLocation(
                city: currentUser.location?.city,
                province: currentUser.location?.province,
                coordinates: Coordinates(lat: coordinate.latitude, lng: coordinate.longitude),
                gpsCoordinates: GPSCoordinates(
                    lat: coordinate.latitude,
                    lng: coordinate.longitude,
                    checkedInAt: Int(Date().timeIntervalSince1970 * 1000)
                )
            ),
            settings: UserSettings(
                notificationsEnabled: currentUser.settings?.notificationsEnabled,
                locationEnabled: true
            ),
            createdAt: currentUser.createdAt,
            photoImage: currentUser.photoImage
        )
    }

    private func restoreSessionAndRefreshIfNeeded(forceRefresh: Bool) async {
        guard sessionStore.isAuthenticated else {
            return
        }

        let restored = await sessionStore.restorePersistedSessionIfNeeded(forceRefresh: forceRefresh)
        guard restored else {
            if !sessionStore.isAuthenticated {
                appState.resetForSignedOutSession()
            }
            return
        }

        if appState.isBootstrapped {
            await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)
            if clearInvalidPersistedCredentialIfNeeded() {
                return
            }
            storeCurrentUserSnapshotIfAvailable()
        }
    }

    private var shouldShowPersistedCurrentUserResolutionLoading: Bool {
        rootLoadingPolicy.shouldShowPersistedCurrentUserResolutionLoading
    }

    private var shouldShowPersistedMissingCurrentUserValidationLoading: Bool {
        isResolvingPersistedMissingCurrentUser
            || persistedMissingCurrentUserValidationKey != nil
    }

    private var persistedMissingCurrentUserValidationKey: String? {
        guard sessionStore.isAuthenticated,
              sessionStore.launchedWithPersistedSession,
              hasPersistedRefreshCredential,
              appState.isBootstrapped,
              appState.currentUser == nil,
              sessionStore.cachedCurrentUser == nil,
              appState.hasConfirmedMissingCurrentUser || appState.hasFailedCurrentUserRefreshWithoutPrevious else {
            return nil
        }

        let currentUserFailureRequiresClear = appState.currentUserRefreshFailure.map {
            sessionStore.shouldClearSessionAfterCredentialFailure($0)
        } ?? false

        guard sessionStore.hasTerminalSessionRestoreFailure
                || currentUserFailureRequiresClear
                || !sessionStore.hasAttemptedSessionRestore else {
            return nil
        }

        return [
            sessionStore.betterAuthSessionToken ?? "no-session-token",
            sessionStore.betterAuthCookie ?? "no-cookie",
            sessionStore.token ?? "no-convex-token",
        ].joined(separator: "|")
    }

    private var hasPersistedRefreshCredential: Bool {
        if let betterAuthCookie = sessionStore.betterAuthCookie, !betterAuthCookie.isEmpty {
            return true
        }
        if let betterAuthSessionToken = sessionStore.betterAuthSessionToken, !betterAuthSessionToken.isEmpty {
            return true
        }
        return false
    }

    private func validatePersistedMissingCurrentUserIfNeeded(validationKey: String?) async {
        guard let validationKey,
              attemptedPersistedMissingCurrentUserValidationKey != validationKey else {
            return
        }

        attemptedPersistedMissingCurrentUserValidationKey = validationKey
        isResolvingPersistedMissingCurrentUser = true
        defer { isResolvingPersistedMissingCurrentUser = false }

        if clearInvalidPersistedCredentialIfNeeded() {
            return
        }

        guard !sessionStore.hasAttemptedSessionRestore else {
            return
        }

        let restored = await sessionStore.restorePersistedSessionIfNeeded(forceRefresh: true)
        guard restored else {
            if !sessionStore.isAuthenticated {
                appState.resetForSignedOutSession()
            }
            return
        }

        await appState.refreshAuthedData(
            client: sessionStore.client,
            surfaceErrors: false,
            shouldRefreshCategories: false
        )
        storeCurrentUserSnapshotIfAvailable()
        _ = clearInvalidPersistedCredentialIfNeeded()
    }

    @discardableResult
    private func clearInvalidPersistedCredentialIfNeeded() -> Bool {
        guard sessionStore.isAuthenticated else {
            return false
        }

        if appState.signInRequiredAuthFailureID != nil {
            sessionStore.clearInvalidPersistedCredential()
            appState.resetForSignedOutSession()
            return true
        }

        guard appState.currentUser == nil,
              appState.hasConfirmedMissingCurrentUser || appState.hasFailedCurrentUserRefreshWithoutPrevious else {
            return false
        }

        let currentUserFailureRequiresClear = appState.currentUserRefreshFailure.map {
            sessionStore.shouldClearSessionAfterCredentialFailure($0)
        } ?? false

        guard sessionStore.hasTerminalSessionRestoreFailure || currentUserFailureRequiresClear else {
            return false
        }

        sessionStore.clearInvalidPersistedCredential()
        appState.resetForSignedOutSession()
        return true
    }

    private func applyCachedCurrentUserIfNeeded() {
        guard sessionStore.isAuthenticated,
              appState.currentUser == nil,
              let cachedCurrentUser = sessionStore.cachedCurrentUser else {
            return
        }

        appState.currentUser = cachedCurrentUser
    }

    private func storeCurrentUserSnapshotIfAvailable() {
        guard sessionStore.isAuthenticated else {
            return
        }

        sessionStore.storeCurrentUserSnapshot(appState.currentUser)
    }

    private func clearInvalidPersistedCredentialAfterAuthFailureIfNeeded() {
        guard sessionStore.isAuthenticated,
              appState.signInRequiredAuthFailureID != nil else {
            return
        }

        sessionStore.clearInvalidPersistedCredential()
        appState.resetForSignedOutSession()
    }
}

struct RootLoadingPolicy: Equatable {
    var isAuthenticated: Bool
    var isRestoringSession: Bool
    var needsSessionRestore: Bool
    var hasAttemptedSessionRestore = false
    var isForegroundRefreshPending: Bool
    var isBootstrapped: Bool
    var hasCurrentUser: Bool
    var launchedWithPersistedSession: Bool
    var hasConfirmedMissingCurrentUser = false
    var hasFailedCurrentUserRefreshWithoutPrevious = false

    var shouldShowForegroundRefreshLoading: Bool {
        isForegroundRefreshPending
            && !hasCurrentUser
            && !preservesAuthenticatedRouteDuringRefresh
    }

    var shouldShowSessionRestoreLoading: Bool {
        (isRestoringSession || needsInitialSessionRestore)
            && !preservesAuthenticatedRouteDuringRefresh
    }

    var shouldShowPersistedCurrentUserResolutionLoading: Bool {
        isAuthenticated
            && isBootstrapped
            && !hasCurrentUser
            && launchedWithPersistedSession
            && !needsSessionRestore
            && !hasConfirmedMissingCurrentUser
            && !hasFailedCurrentUserRefreshWithoutPrevious
    }

    private var needsInitialSessionRestore: Bool {
        needsSessionRestore && !hasAttemptedSessionRestore
    }

    private var preservesAuthenticatedRouteDuringRefresh: Bool {
        guard isAuthenticated, isBootstrapped else {
            return false
        }

        if hasCurrentUser {
            return true
        }

        return isForegroundRefreshPending && !launchedWithPersistedSession
    }
}

struct ProfileSetupRoutePolicy: Equatable {
    var hasCurrentUser: Bool
    var isProfileSetupInProgress: Bool

    var shouldShowProfileSetup: Bool {
        !hasCurrentUser || isProfileSetupInProgress
    }

    var shouldStartProfileSetup: Bool {
        !hasCurrentUser && !isProfileSetupInProgress
    }
}

struct ProfileSetupNotificationPrompt: Equatable {
    var authorizationStatus: UNAuthorizationStatus

    var isSystemAuthorized: Bool {
        PatchworkNotificationCenter.isAuthorizationEnabled(authorizationStatus)
    }

    var title: String {
        isSystemAuthorized ? "Notifications are already enabled" : "Stay in the loop"
    }

    var message: String {
        if isSystemAuthorized {
            return "Patchwork works better with notifications enabled for messages, quote updates, and accepted jobs. Keep them on, or disable app notifications for now."
        }
        return "Turn on notifications for messages, quote updates, and accepted jobs."
    }

    var note: String {
        if isSystemAuthorized {
            return "Disabling here only pauses Patchwork notifications. You can change the iOS permission later in Settings."
        }
        return "You can always change notification preferences later from your profile settings."
    }

    var primaryActionTitle: String {
        isSystemAuthorized ? "Keep notifications enabled" : "Allow notifications"
    }

    var secondaryActionTitle: String {
        isSystemAuthorized ? "Disable for now" : "Maybe later"
    }
}

private struct ProfileSetupView: View {
    private enum Step {
        case profile
        case location
        case notifications
    }

    private struct CameraCaptureRequest: Identifiable {
        let id = UUID()
    }

    private enum PhotoSheet: Identifiable {
        case gallery
        case crop(PhotoCropInput)

        var id: String {
            switch self {
            case .gallery:
                return "gallery"
            case .crop(let input):
                return "crop-\(input.id)"
            }
        }
    }

    private enum Field: Hashable {
        case name
        case city
    }

    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(LocationManager.self) private var locationManager
    let onFinished: () -> Void

    @State private var name = ""
    @State private var city = ""
    @State private var province = ""
    @State private var selectedPhotoData: Data?
    @State private var selectedPhotoPreviewImage: UIImage?
    @State private var selectedPhotoAsset: RemoteImageAsset?
    @State private var isUploadingPhoto = false
    @State private var photoUploadError: String?
    @State private var showsPhotoOptions = false
    @State private var cameraCaptureRequest: CameraCaptureRequest?
    @State private var pendingCameraImage: UIImage?
    @State private var photoSheet: PhotoSheet?
    @State private var isSaving = false
    @State private var createdUserId: ConvexID?
    @State private var resolvedCoordinates: Coordinates?
    @State private var step: Step = .profile
    @State private var selectedHomeBase: HomeBaseOption?
    @State private var isFinalizingNotifications = false
    @State private var fallbackNotificationsEnabled = false
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var notificationActionsAreReady = false
    @FocusState private var focusedField: Field?

    var body: some View {
        OnboardingStageLayout(tint: accentColorForStep) {
            stepContent
        } actions: {
            stepActionContent
        }
        .onAppear {
            guard step == .profile else {
                return
            }
            focusedField = .name
        }
        .onChange(of: step) { _, newValue in
            focusedField = newValue == .profile ? .name : nil
            if newValue != .notifications {
                notificationActionsAreReady = false
            }
        }
        .task(id: step) {
            guard step == .notifications else {
                return
            }
            await refreshNotificationAuthorizationStatus()
            await armNotificationActionsAfterTransition()
        }
        .confirmationDialog("Profile photo", isPresented: $showsPhotoOptions, titleVisibility: .visible) {
            if CameraCaptureView.isCameraAvailable {
                Button("Take Photo") {
                    cameraCaptureRequest = CameraCaptureRequest()
                }
            }
            Button("Choose from Gallery") {
                photoSheet = .gallery
            }
            if hasSelectedPhoto {
                Button("Remove Photo", role: .destructive) {
                    clearSelectedPhoto()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(item: $cameraCaptureRequest, onDismiss: presentPendingCameraCrop) { _ in
            CameraCaptureView { image in
                pendingCameraImage = image
                cameraCaptureRequest = nil
            }
            .ignoresSafeArea()
        }
        .sheet(item: $photoSheet) { sheet in
            switch sheet {
            case .gallery:
                GalleryPickerView(selectionLimit: 1) { images in
                    presentCropIfNeeded(images.first)
                }
            case .crop(let input):
                PhotoCropEditor(input: input) {
                    photoSheet = nil
                } onConfirm: { draft in
                    selectedPhotoData = draft.data
                    selectedPhotoPreviewImage = draft.previewImage
                    selectedPhotoAsset = nil
                    photoUploadError = nil
                    photoSheet = nil
                }
            }
        }
    }

    private var accentColorForStep: Color {
        switch step {
        case .profile:
            return PatchworkTheme.brand
        case .location:
            return PatchworkTheme.accent
        case .notifications:
            return PatchworkTheme.brandBright
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .profile:
            profileStepContent
        case .location:
            locationStepContent
        case .notifications:
            notificationsStepContent
        }
    }

    private var profileStepContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingProgress

            PatchworkSectionIntro(
                eyebrow: "Step 1",
                title: "Create your profile",
                message: "Start with the details seekers and taskers will actually see. You can refine this later."
            )

            VStack(spacing: 12) {
                AvatarPhotoControl(
                    localImage: selectedPhotoPreviewImage,
                    remoteAsset: selectedPhotoAsset,
                    size: 112,
                    isBusy: isUploadingPhoto || isSaving,
                    accessibilityIdentifier: "ProfileSetup.photoPicker",
                    action: { showsPhotoOptions = true }
                ) {
                    avatarPickerPlaceholder
                }

                if isUploadingPhoto {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(PatchworkTheme.brand)
                        Text("Uploading photo...")
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else if let photoUploadError {
                    PatchworkInlineStatusBanner(tone: .error, text: photoUploadError)
                        .accessibilityIdentifier("ProfileSetup.photoError")
                }
            }
            .frame(maxWidth: .infinity)

            TextField("Full name", text: $name)
                .patchworkInputFieldStyle()
                .focused($focusedField, equals: .name)
                .accessibilityIdentifier("ProfileSetup.nameField")

            HomeBaseDropdownField(
                placeholder: "Home base",
                text: $city,
                selectedHomeBase: $selectedHomeBase,
                fieldAccessibilityIdentifier: "ProfileSetup.cityField",
                suggestionAccessibilityPrefix: "ProfileSetup.homeBaseSuggestion",
                noResultsAccessibilityIdentifier: "ProfileSetup.homeBaseNoResults",
                noResultsMessage: "Select a suggested home base to continue.",
                onTextChanged: {
                    clearHomeBaseSelectionIfNeeded()
                },
                onSelect: { suggestion in
                    selectHomeBase(suggestion)
                    focusedField = nil
                }
            )
        }
    }

    private var isProfileStepValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && hasSelectedValidHomeBase
    }

    private var locationStepContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingProgress

            profileStepIcon(systemName: "location.circle.fill", tint: PatchworkTheme.accent)

            PatchworkSectionIntro(
                eyebrow: "Step 2",
                title: "Share your location",
                message: "Allow location so Patchwork can show the nearest taskers and keep local matches relevant."
            )

            Text("You can keep using your profile home base if you don't want live GPS.")
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textSecondary)
        }
    }

    private var notificationsStepContent: some View {
        let prompt = ProfileSetupNotificationPrompt(authorizationStatus: notificationAuthorizationStatus)

        return VStack(alignment: .leading, spacing: 18) {
            onboardingProgress

            profileStepIcon(systemName: "bell.badge.fill", tint: PatchworkTheme.brandBright)

            PatchworkSectionIntro(
                eyebrow: "Step 3",
                title: prompt.title,
                message: prompt.message
            )

            Text(prompt.note)
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textSecondary)
        }
    }

    @ViewBuilder
    private var stepActionContent: some View {
        switch step {
        case .profile:
            Button(isSaving ? "Saving..." : (isUploadingPhoto ? "Uploading..." : "Continue")) {
                Task { await createProfile() }
            }
            .buttonStyle(PatchworkPrimaryButtonStyle())
            .disabled(isSaving || isUploadingPhoto || !isProfileStepValid)
            .accessibilityIdentifier("ProfileSetup.continueButton")
        case .location:
            Button("Allow location") {
                Task {
                    let didSync = await requestAndSyncCurrentLocation()
                    guard didSync else {
                        return
                    }
                    markLocationPromptCompleted()
                    step = .notifications
                }
            }
            .buttonStyle(PatchworkPrimaryButtonStyle())
            .accessibilityIdentifier("ProfileSetup.locationAllowButton")

            Button("Use profile location instead") {
                Task {
                    let didSync = await syncSavedProfileLocation()
                    guard didSync else {
                        return
                    }
                    markLocationPromptCompleted()
                    step = .notifications
                }
            }
            .buttonStyle(PatchworkSecondaryButtonStyle())
            .accessibilityIdentifier("ProfileSetup.locationSkipButton")
        case .notifications:
            let prompt = ProfileSetupNotificationPrompt(authorizationStatus: notificationAuthorizationStatus)

            Button(prompt.primaryActionTitle) {
                Task {
                    guard !isFinalizingNotifications else { return }
                    isFinalizingNotifications = true
                    defer { isFinalizingNotifications = false }
                    let notificationsEnabled = await PatchworkNotificationCenter.requestAuthorizationAndRegister()
                    await refreshNotificationAuthorizationStatus()
                    await saveNotificationPreferenceAndFinalize(notificationsEnabled: notificationsEnabled)
                }
            }
            .buttonStyle(PatchworkPrimaryButtonStyle())
            .disabled(isFinalizingNotifications || !notificationActionsAreReady)
            .accessibilityIdentifier("ProfileSetup.notificationsAllowButton")

            Button(prompt.secondaryActionTitle) {
                Task {
                    guard !isFinalizingNotifications else { return }
                    isFinalizingNotifications = true
                    defer { isFinalizingNotifications = false }
                    await saveNotificationPreferenceAndFinalize(notificationsEnabled: false)
                }
            }
            .buttonStyle(PatchworkSecondaryButtonStyle())
            .disabled(isFinalizingNotifications || !notificationActionsAreReady)
            .accessibilityIdentifier("ProfileSetup.notificationsSkipButton")
        }
    }

    private func profileStepIcon(systemName: String, tint: Color) -> some View {
        Circle()
            .fill(tint.opacity(0.14))
            .frame(width: 84, height: 84)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .accessibilityHidden(true)
    }

    private var onboardingProgress: some View {
        HStack(spacing: 8) {
            Text("Step \(onboardingStepIndex) of 3")
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(onboardingStepIndex) of 3")
    }

    private var onboardingStepIndex: Int {
        switch step {
        case .profile:
            1
        case .location:
            2
        case .notifications:
            3
        }
    }

    private var hasSelectedPhoto: Bool {
        selectedPhotoData != nil || selectedPhotoPreviewImage != nil || selectedPhotoAsset != nil
    }

    private var trimmedCity: String {
        city.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedProvince: String {
        province.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSelectedValidHomeBase: Bool {
        guard let selectedHomeBase else {
            return false
        }

        return selectedHomeBase.city.caseInsensitiveCompare(trimmedCity) == .orderedSame
    }

    private func selectHomeBase(_ suggestion: HomeBaseOption) {
        selectedHomeBase = suggestion
        city = suggestion.city
        province = suggestion.province
        focusedField = nil
    }

    private func clearHomeBaseSelectionIfNeeded() {
        guard selectedHomeBase != nil, !hasSelectedValidHomeBase else {
            return
        }
        selectedHomeBase = nil
    }

    private func createProfile() async {
        isSaving = true
        photoUploadError = nil
        defer { isSaving = false }
        do {
            if createdUserId == nil {
                let args: [String: Any] = [
                    "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
                    "city": trimmedCity,
                    "province": trimmedProvince,
                ]
                createdUserId = try await sessionStore.client.mutation(
                    "users:createProfile",
                    args: args
                ) as ConvexID
            }

            let didAttachPhoto = await attachSelectedPhotoIfNeeded()
            guard didAttachPhoto else {
                return
            }

            step = .location
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func saveNotificationPreferenceAndFinalize(notificationsEnabled: Bool) async {
        fallbackNotificationsEnabled = notificationsEnabled
        do {
            let updatedUser = try await PatchworkAPI(client: sessionStore.client).users.updateNotificationSettings(
                notificationsEnabled: notificationsEnabled
            )
            appState.currentUser = updatedUser
        } catch {
            print("[Notifications] Failed to save notification preference: \(error.localizedDescription)")
            applyLocalNotificationPreference(notificationsEnabled)
        }
        await finalizeSetup()
        onFinished()
    }

    private func applyLocalNotificationPreference(_ notificationsEnabled: Bool) {
        guard let currentUser = appState.currentUser else {
            return
        }

        appState.currentUser = CurrentUser(
            id: currentUser.id,
            email: currentUser.email,
            name: currentUser.name,
            roles: currentUser.roles,
            location: currentUser.location,
            settings: UserSettings(
                notificationsEnabled: notificationsEnabled,
                locationEnabled: currentUser.settings?.locationEnabled
            ),
            createdAt: currentUser.createdAt,
            photoImage: currentUser.photoImage
        )
    }

    private func finalizeSetup() async {
        for attempt in 1 ... 5 {
            await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)
            if appState.currentUser != nil {
                return
            }
            if attempt < 5 {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        guard let createdUserId else {
            return
        }

        appState.lastError = nil
        appState.currentUser = CurrentUser(
            id: createdUserId,
            email: sessionStore.emailForOTP,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            roles: UserRoles(isSeeker: true, isTasker: false),
            location: UserLocation(
                city: trimmedCity,
                province: trimmedProvince,
                coordinates: resolvedCoordinates,
                gpsCoordinates: nil
            ),
            settings: UserSettings(
                notificationsEnabled: fallbackNotificationsEnabled,
                locationEnabled: resolvedCoordinates != nil
            ),
            createdAt: nil,
            photoImage: selectedPhotoAsset
        )

        Task {
            await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)
        }
    }

    private func markLocationPromptCompleted() {
        guard let createdUserId else {
            return
        }
        UserDefaults.standard.set(true, forKey: "Patchwork.locationPromptCompleted.\(createdUserId)")
    }

    private func refreshNotificationAuthorizationStatus() async {
        notificationAuthorizationStatus = await PatchworkNotificationCenter.authorizationStatus()
    }

    private func armNotificationActionsAfterTransition() async {
        notificationActionsAreReady = false
        try? await Task.sleep(nanoseconds: 800_000_000)
        guard step == .notifications else {
            return
        }
        notificationActionsAreReady = true
    }

    private var avatarPickerPlaceholder: some View {
        ZStack {
            PatchworkTheme.brandSoft
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(PatchworkTheme.brand)
        }
    }

    private func presentCropIfNeeded(_ image: UIImage?) {
        guard let image else {
            photoSheet = nil
            return
        }

        photoSheet = .crop(PhotoCropInput(image: image, purpose: .userPhoto))
    }

    private func presentPendingCameraCrop() {
        guard let pendingCameraImage else {
            return
        }

        self.pendingCameraImage = nil
        presentCropIfNeeded(pendingCameraImage)
    }

    @discardableResult
    private func attachSelectedPhotoIfNeeded() async -> Bool {
        guard let selectedPhotoData else {
            return true
        }

        isUploadingPhoto = true
        defer { isUploadingPhoto = false }

        do {
            let photoAsset: RemoteImageAsset
            if let selectedPhotoAsset {
                photoAsset = selectedPhotoAsset
            } else {
                let uploadService = ImageAssetUploadService(client: sessionStore.client)
                let uploadedAsset = try await uploadService.uploadImage(data: selectedPhotoData, purpose: "userPhoto")
                selectedPhotoAsset = uploadedAsset
                photoAsset = uploadedAsset
            }

            _ = try await sessionStore.client.mutation(
                "users:updateProfilePhoto",
                args: ["photoAssetId": photoAsset.id]
            ) as CurrentUser
            return true
        } catch {
            photoUploadError = "Your profile was created, but we couldn't save this photo. Try Continue again or Remove the photo. \(error.localizedDescription)"
            return false
        }
    }

    private func clearSelectedPhoto() {
        let assetToDelete = selectedPhotoAsset
        selectedPhotoData = nil
        selectedPhotoPreviewImage = nil
        selectedPhotoAsset = nil
        photoUploadError = nil
        cameraCaptureRequest = nil
        photoSheet = nil

        if let assetToDelete {
            Task {
                let _: RemoteImageAsset? = try? await sessionStore.client.mutation(
                    "files:deleteImageAsset",
                    args: ["imageAssetId": assetToDelete.id]
                )
            }
        }
    }

    @discardableResult
    private func requestAndSyncCurrentLocation() async -> Bool {
        _ = await locationManager.requestWhenInUseAuthorizationIfNeeded()
        if let coordinate = await requestCoordinateWithRetries() {
            return await syncLocation(coordinate, source: "gps")
        }
        return await syncSavedProfileLocation()
    }

    private func requestCoordinateWithRetries(maxAttempts: Int = 3) async -> CLLocationCoordinate2D? {
        guard maxAttempts > 0 else {
            return nil
        }

        for attempt in 1 ... maxAttempts {
            if let coordinate = await locationManager.requestCurrentCoordinate() {
                return coordinate
            }
            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        return nil
    }

    @discardableResult
    private func syncSavedProfileLocation() async -> Bool {
        if let coordinate = await locationManager.geocode(city: city, province: province) {
            return await syncLocation(coordinate, source: "manual")
        } else {
            appState.lastError = "Location unavailable. Update your profile home base to continue."
            return false
        }
    }

    @discardableResult
    private func syncLocation(_ coordinate: CLLocationCoordinate2D, source: String) async -> Bool {
        let didSync = await appState.syncLocation(
            client: sessionStore.client,
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            source: source
        )
        if didSync {
            resolvedCoordinates = Coordinates(lat: coordinate.latitude, lng: coordinate.longitude)
            if source == "gps", let createdUserId {
                LocationSyncCache.store(coordinate, for: createdUserId)
            }
        }
        return didSync
    }
}

private struct LocationPermissionGateView: View {
    let onAllow: () async -> Void
    let onSkip: () -> Void

    @State private var isRequesting = false

    var body: some View {
        OnboardingStageLayout(tint: PatchworkTheme.accent) {
            VStack(alignment: .leading, spacing: 20) {
                Circle()
                    .fill(PatchworkTheme.accent.opacity(0.14))
                    .frame(width: 84, height: 84)
                    .overlay {
                        Image(systemName: "location.fill")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(PatchworkTheme.accent)
                    }
                    .accessibilityHidden(true)

                PatchworkSectionIntro(
                    eyebrow: "Local search",
                    title: "Enable location",
                    message: "Patchwork uses your location to show nearby taskers and improve local job matches."
                )

                Text("You can change this anytime in Settings.")
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textTertiary)
            }
        } actions: {
            Button {
                isRequesting = true
                Task {
                    await onAllow()
                    isRequesting = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isRequesting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isRequesting ? "Locating..." : "Allow location")
                }
            }
            .buttonStyle(PatchworkPrimaryButtonStyle())
            .disabled(isRequesting)
            .accessibilityLabel("Allow Location")
            .accessibilityIdentifier("LocationPrompt.allowButton")

            Button("Not now") {
                onSkip()
            }
            .buttonStyle(PatchworkSecondaryButtonStyle())
            .accessibilityLabel("Skip location permission")
            .accessibilityIdentifier("LocationPrompt.skipButton")
        }
    }
}

private struct OnboardingStageLayout<Content: View, Actions: View>: View {
    let tint: Color
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: tint)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 176)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                actions
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 14)
            .background {
                LinearGradient(
                    colors: [
                        PatchworkTheme.surface.opacity(0),
                        PatchworkTheme.surface.opacity(0.8),
                        PatchworkTheme.surface.opacity(0.96),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

enum MainTabProfileRoute: Hashable {
    case taskerOnboarding
}

private struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @State private var profilePath: [MainTabProfileRoute] = []
    @AppStorage("Patchwork.taskerOnboardingDraft") private var taskerOnboardingDraftJSON = ""
    @AppStorage("Patchwork.taskerOnboardingRouteActive") private var taskerOnboardingRouteActive = false
    @AppStorage("Patchwork.taskerOnboardingRouteUserId") private var taskerOnboardingRouteUserId = ""
    @AppStorage("Patchwork.remoteNotificationDeviceToken") private var remoteNotificationDeviceToken = ""

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(PatchworkTheme.surface)
        appearance.shadowColor = UIColor(PatchworkTheme.stroke)

        let selected = UIColor(PatchworkTheme.brand)
        let normal = UIColor(PatchworkTheme.textSecondary)
        appearance.stackedLayoutAppearance.selected.iconColor = selected
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selected]
        appearance.stackedLayoutAppearance.normal.iconColor = normal
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normal]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .accessibilityIdentifier("Tab.home")
            .tabItem { Label("Seek", systemImage: "magnifyingglass") }
            .tag(AppState.Tab.home)

            NavigationStack {
                JobsView()
            }
            .accessibilityIdentifier("Tab.jobs")
            .tabItem { Label("Jobs", systemImage: "briefcase") }
            .tag(AppState.Tab.jobs)

            NavigationStack {
                MessagesView()
            }
            .accessibilityIdentifier("Tab.messages")
            .tabItem { Label("Messages", systemImage: "message") }
            .tag(AppState.Tab.messages)

            NavigationStack(path: $profilePath) {
                ProfileView(onSignOut: {
                    await unregisterPushTokenIfNeeded()
                    clearTaskerOnboardingRouteState(clearDraft: true)
                    appState.resetForSignedOutSession()
                    await sessionStore.signOut()
                }, onDeleteAccount: {
                    await unregisterPushTokenIfNeeded()
                    let _: EmptyResponse = try await sessionStore.client.mutation("users:deleteAccount", args: [:])
                    clearTaskerOnboardingRouteState(clearDraft: true)
                    appState.resetForSignedOutSession()
                    await sessionStore.signOut()
                })
                .navigationDestination(for: MainTabProfileRoute.self) { route in
                    switch route {
                    case .taskerOnboarding:
                        TaskerOnboardingView()
                    }
                }
            }
            .accessibilityIdentifier("Tab.profile")
            .tabItem { Label("Profile", systemImage: "person") }
            .tag(AppState.Tab.profile)
        }
        .tint(PatchworkTheme.brand)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(PatchworkTheme.surface, for: .tabBar)
        .onAppear {
            reconcileTaskerOnboardingRouteState()
        }
        .onChange(of: appState.isBootstrapped) { _, _ in
            reconcileTaskerOnboardingRouteState()
        }
        .onChange(of: appState.taskerProfile?.id) { _, taskerProfileId in
            if taskerProfileId != nil {
                clearTaskerOnboardingRouteState()
            } else {
                reconcileTaskerOnboardingRouteState()
            }
        }
        .onChange(of: profilePath) { _, newPath in
            taskerOnboardingRouteActive = newPath.contains(.taskerOnboarding)
            taskerOnboardingRouteUserId = taskerOnboardingRouteActive ? (appState.currentUser?.id ?? "") : ""
        }
        .onChange(of: appState.selectedTab) { _, selectedTab in
            if selectedTab != .profile {
                profilePath = []
                clearTaskerOnboardingRouteState()
            }
        }
    }

    private func reconcileTaskerOnboardingRouteState() {
        guard taskerOnboardingRouteActive,
              !taskerOnboardingDraftJSON.isEmpty,
              appState.isBootstrapped,
              let currentUserId = appState.currentUser?.id,
              appState.taskerProfile == nil else {
            if appState.currentUser == nil || appState.taskerProfile != nil {
                clearTaskerOnboardingRouteState()
            }
            return
        }

        guard taskerOnboardingRouteUserId == currentUserId,
              appState.selectedTab == .profile else {
            clearTaskerOnboardingRouteState()
            return
        }

        guard !profilePath.contains(.taskerOnboarding) else {
            return
        }

        appState.selectedTab = .profile
        profilePath = [.taskerOnboarding]
    }

    private func clearTaskerOnboardingRouteState(clearDraft: Bool = false) {
        taskerOnboardingRouteActive = false
        taskerOnboardingRouteUserId = ""
        if clearDraft {
            taskerOnboardingDraftJSON = ""
        }
    }

    private func unregisterPushTokenIfNeeded() async {
        guard sessionStore.isAuthenticated,
              !remoteNotificationDeviceToken.isEmpty else {
            return
        }

        do {
            try await PatchworkAPI(client: sessionStore.client).users.unregisterPushToken(remoteNotificationDeviceToken)
        } catch {
            print("[Notifications] Failed to unregister push token: \(error.localizedDescription)")
        }
    }
}
