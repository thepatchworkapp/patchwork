import CoreLocation
import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SessionStore.self) private var sessionStore
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager
    @Environment(RevenueCatManager.self) private var revenueCatManager
    @State private var attemptedLocationRecoveryKey: String?
    @State private var locationPromptCompletedForSession = false
    @State private var locationPromptSessionUserId: ConvexID?
    @State private var isForegroundRefreshPending = false
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
                if isForegroundRefreshPending {
                    if appState.currentUser == nil {
                        PatchworkBrandLoadingCard()
                    } else {
                        MainTabView()
                    }
                } else if sessionStore.isRestoringSession || sessionStore.needsSessionRestore {
                    PatchworkBrandLoadingCard()
                } else if !appState.isBootstrapped {
                    PatchworkBrandLoadingCard()
                        .task {
                            await appState.loadBootstrapData(client: sessionStore.client)
                        }
                } else if appState.currentUser == nil {
                    ProfileSetupView()
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
                .accessibilityIdentifier("Root.errorAlertOKButton")
        } message: {
            Text(appState.lastError ?? "")
        }
        .task {
            revenueCatManager.configureIfNeeded()
        }
        .task {
            await restoreSessionAndRefreshIfNeeded(forceRefresh: false)
        }
        .task(id: revenueCatIdentityKey) {
            let userID = sessionStore.isAuthenticated ? appState.currentUser?.id : nil
            await revenueCatManager.syncIdentity(
                currentUserID: userID,
                appState: appState,
                client: sessionStore.client
            )
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
                await restoreSessionAndRefreshIfNeeded(forceRefresh: true)
            }
        }
        .onChange(of: sessionStore.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                appState.resetForSignedOutSession()
                locationPromptCompletedForSession = false
                locationPromptSessionUserId = nil
                isForegroundRefreshPending = false
            }
        }
        .onChange(of: appState.currentUser?.id) { _, newUserId in
            locationPromptCompletedForSession = false
            locationPromptSessionUserId = newUserId
        }
        .task(id: locationRecoveryKey) {
            guard let locationRecoveryKey,
                  attemptedLocationRecoveryKey != locationRecoveryKey else {
                return
            }

            attemptedLocationRecoveryKey = locationRecoveryKey
            await recoverLocationIfNeeded()
        }
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
            Category(id: "category-cleaning", name: "Cleaning", slug: "cleaning", emoji: nil, group: nil),
            Category(id: "category-plumbing", name: "Plumbing", slug: "plumbing", emoji: nil, group: nil),
            Category(id: "category-electrical", name: "Electrical", slug: "electrical", emoji: nil, group: nil),
        ]
        appState.currentUser = CurrentUser(
            id: "debug-preview-user",
            email: "preview@patchwork.app",
            name: "Preview User",
            roles: UserRoles(isSeeker: true, isTasker: true),
            location: UserLocation(
                city: "Waterloo",
                province: "On",
                coordinates: Coordinates(lat: 43.4643, lng: -80.5204)
            ),
            settings: UserSettings(notificationsEnabled: true, locationEnabled: true),
            createdAt: nil
        )
        appState.taskerProfile = TaskerProfileSelf(
            id: "debug-tasker-profile",
            displayName: "Preview User",
            bio: "Reliable local help for same-week household jobs.",
            subscriptionPlan: showsBillingPreview ? "none" : "tasker",
            subscriptionAccessType: showsBillingPreview ? nil : "subscription",
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
            categories: [
                TaskerManagedCategory(
                    id: "debug-tasker-category-cleaning",
                    categoryId: "category-cleaning",
                    categoryName: "Cleaning",
                    categorySlug: "cleaning",
                    bio: "Recurring home cleaning and turnover prep.",
                    rateType: "hourly",
                    hourlyRate: 4500,
                    fixedRate: nil,
                    serviceRadius: 25,
                    rating: 4.8,
                    reviewCount: 18,
                    completedJobs: 24
                ),
                TaskerManagedCategory(
                    id: "debug-tasker-category-plumbing",
                    categoryId: "category-plumbing",
                    categoryName: "Plumbing",
                    categorySlug: "plumbing",
                    bio: "Fixture swaps, leak checks, and small repairs.",
                    rateType: "hourly",
                    hourlyRate: 6500,
                    fixedRate: nil,
                    serviceRadius: 20,
                    rating: 5.0,
                    reviewCount: 10,
                    completedJobs: 18
                ),
            ]
        )
        appState.favouriteTaskers = [
            TaskerSummary(
                id: "debug-favourite-tasker-1",
                userId: "debug-favourite-user-1",
                displayName: "Avery Stone",
                averageRating: 4.8,
                reviewCount: 31,
                distanceLabel: "4.1 km",
                categoryName: "Cleaning",
                rateLabel: "$48/hr",
                verified: true,
                bio: "Recurring home cleaning and deep resets.",
                completedJobs: 64,
                avatarUrl: nil,
                categoryPhotoUrl: nil
            ),
            TaskerSummary(
                id: "debug-favourite-tasker-2",
                userId: "debug-favourite-user-2",
                displayName: "Jordan Vale",
                averageRating: 5.0,
                reviewCount: 18,
                distanceLabel: "7.8 km",
                categoryName: "Electrical",
                rateLabel: "$72/hr",
                verified: true,
                bio: "Fixture installs, troubleshooting, and panel upgrades.",
                completedJobs: 39,
                avatarUrl: nil,
                categoryPhotoUrl: nil
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

    private var locationRecoveryKey: String? {
        guard sessionStore.isAuthenticated,
              let user = appState.currentUser,
              !needsLocationPrompt,
              user.location?.coordinates == nil else {
            return nil
        }

        let city = user.location?.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let province = user.location?.province?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !city.isEmpty || !province.isEmpty else {
            return nil
        }

        return "\(user.id)|\(city)|\(province)"
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

    private func requestAndSyncCurrentLocation(source: String) async -> Bool {
        let status = await locationManager.requestWhenInUseAuthorizationIfNeeded()
        let coordinate = await requestCoordinateWithRetries()
        let didSync: Bool

        if let coordinate {
            didSync = await syncLocation(coordinate, source: source)
        } else if status == .denied || status == .restricted {
            didSync = await syncSavedProfileLocation()
        } else {
            didSync = await syncSavedProfileLocation()
        }

        await appState.refreshAuthedData(client: sessionStore.client)
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

    private func recoverLocationIfNeeded() async {
        guard locationRecoveryKey != nil else {
            return
        }
        guard await syncSavedProfileLocation(surfaceErrors: false) else {
            return
        }
        await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)
    }

    @discardableResult
    private func syncSavedProfileLocation(surfaceErrors: Bool = true) async -> Bool {
        if let profileCoords = appState.currentUser?.location?.coordinates {
            return await syncLocation(
                CLLocationCoordinate2D(latitude: profileCoords.lat, longitude: profileCoords.lng),
                source: "manual"
            )
        }

        let city = appState.currentUser?.location?.city ?? ""
        let province = appState.currentUser?.location?.province ?? ""
        if let coordinate = await locationManager.geocode(city: city, province: province) {
            return await syncLocation(coordinate, source: "manual")
        }
        if surfaceErrors {
            appState.lastError = "Location unavailable. Update your profile location to search nearby taskers."
        }
        return false
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
                coordinates: Coordinates(lat: coordinate.latitude, lng: coordinate.longitude)
            ),
            settings: UserSettings(
                notificationsEnabled: currentUser.settings?.notificationsEnabled,
                locationEnabled: true
            ),
            createdAt: currentUser.createdAt
        )
    }

    private func restoreSessionAndRefreshIfNeeded(forceRefresh: Bool) async {
        guard sessionStore.isAuthenticated else {
            return
        }

        let shouldForceRefresh = forceRefresh || appState.currentUser == nil
        let restored = await sessionStore.restorePersistedSessionIfNeeded(forceRefresh: shouldForceRefresh)
        guard restored else {
            appState.resetForSignedOutSession()
            return
        }

        if appState.isBootstrapped {
            await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)
        }
    }
}

private struct ProfileSetupView: View {
    private enum Step {
        case profile
        case location
        case notifications
    }

    private enum Field: Hashable {
        case name
        case city
        case province
    }

    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(LocationManager.self) private var locationManager

    @State private var name = ""
    @State private var city = ""
    @State private var province = ""
    @State private var isSaving = false
    @State private var createdUserId: ConvexID?
    @State private var resolvedCoordinates: Coordinates?
    @State private var step: Step = .profile
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

            profileStepIcon(systemName: "person.crop.circle.badge.plus", tint: PatchworkTheme.brand)

            PatchworkSectionIntro(
                eyebrow: "Step 1",
                title: "Create your profile",
                message: "Start with the details seekers and taskers will actually see. You can refine this later."
            )

            TextField("Full name", text: $name)
                .patchworkInputFieldStyle()
                .focused($focusedField, equals: .name)
                .accessibilityIdentifier("ProfileSetup.nameField")

            TextField("City", text: $city)
                .patchworkInputFieldStyle()
                .focused($focusedField, equals: .city)
                .accessibilityIdentifier("ProfileSetup.cityField")

            TextField("Province", text: $province)
                .patchworkInputFieldStyle()
                .focused($focusedField, equals: .province)
                .accessibilityIdentifier("ProfileSetup.provinceField")
        }
    }

    private var isProfileStepValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !province.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

            Text("You can keep using the city and province from your profile if you don't want live GPS.")
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textSecondary)
        }
    }

    private var notificationsStepContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingProgress

            profileStepIcon(systemName: "bell.badge.fill", tint: PatchworkTheme.brandBright)

            PatchworkSectionIntro(
                eyebrow: "Step 3",
                title: "Stay in the loop",
                message: "Turn on notifications for messages, quote updates, and accepted jobs."
            )

            Text("You can always change notification preferences later from your profile settings.")
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textSecondary)
        }
    }

    @ViewBuilder
    private var stepActionContent: some View {
        switch step {
        case .profile:
            Button(isSaving ? "Saving..." : "Continue") {
                Task { await createProfile() }
            }
            .buttonStyle(PatchworkPrimaryButtonStyle())
            .disabled(isSaving || !isProfileStepValid)
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
            Button("Allow notifications") {
                Task { await finalizeSetup() }
            }
            .buttonStyle(PatchworkPrimaryButtonStyle())
            .accessibilityIdentifier("ProfileSetup.notificationsAllowButton")

            Button("Maybe later") {
                Task { await finalizeSetup() }
            }
            .buttonStyle(PatchworkSecondaryButtonStyle())
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
    }

    private var onboardingProgress: some View {
        HStack(spacing: 8) {
            Text("Step \(onboardingStepIndex) of 3")
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textTertiary)

            Spacer()

            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == onboardingStepIndex - 1 ? PatchworkTheme.brand : PatchworkTheme.stroke)
                    .frame(width: index == onboardingStepIndex - 1 ? 24 : 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
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

    private func createProfile() async {
        isSaving = true
        defer { isSaving = false }
        do {
            createdUserId = try await sessionStore.client.mutation(
                "users:createProfile",
                args: [
                    "name": name,
                    "city": city,
                    "province": province,
                ]
            ) as ConvexID
            step = .location
        } catch {
            appState.lastError = error.localizedDescription
        }
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
            name: name,
            roles: UserRoles(isSeeker: true, isTasker: false),
            location: UserLocation(
                city: city,
                province: province,
                coordinates: resolvedCoordinates
            ),
            settings: UserSettings(
                notificationsEnabled: false,
                locationEnabled: resolvedCoordinates != nil
            ),
            createdAt: nil
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
            appState.lastError = "Location unavailable. Update your profile city and province to continue."
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

private struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

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

            NavigationStack {
                ProfileView(onSignOut: {
                    appState.resetForSignedOutSession()
                    await sessionStore.signOut()
                })
            }
            .accessibilityIdentifier("Tab.profile")
            .tabItem { Label("Profile", systemImage: "person") }
            .tag(AppState.Tab.profile)
        }
        .tint(PatchworkTheme.brand)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(PatchworkTheme.surface, for: .tabBar)
    }
}
