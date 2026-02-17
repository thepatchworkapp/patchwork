import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager

    var body: some View {
        Group {
            if sessionStore.isAuthenticated {
                if !appState.isBootstrapped {
                    ProgressView("Loading Patchwork...")
                        .task {
                            await appState.loadBootstrapData(client: sessionStore.client)
                        }
                } else if appState.currentUser == nil {
                    ProfileSetupView()
                } else if needsLocationPrompt {
                    LocationPermissionGateView(
                        onAllow: {
                            await requestAndSyncCurrentLocation(source: "ios_prompt")
                        },
                        onSkip: {
                            markLocationPromptCompleted()
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
            get: { appState.lastError != nil },
            set: { _ in appState.lastError = nil }
        )) {
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier("Root.errorAlertOKButton")
        } message: {
            Text(appState.lastError ?? "Unknown error")
        }
    }

    private var needsLocationPrompt: Bool {
        guard let user = appState.currentUser else {
            return false
        }
        guard user.settings?.locationEnabled != true else {
            return false
        }
        return !UserDefaults.standard.bool(forKey: locationPromptKey(userId: user.id))
    }

    private func locationPromptKey(userId: ConvexID) -> String {
        "Patchwork.locationPromptCompleted.\(userId)"
    }

    private func markLocationPromptCompleted() {
        guard let user = appState.currentUser else {
            return
        }
        UserDefaults.standard.set(true, forKey: locationPromptKey(userId: user.id))
    }

    private func requestAndSyncCurrentLocation(source: String) async {
        let status = await locationManager.requestWhenInUseAuthorizationIfNeeded()
        let coordinate = await locationManager.requestCurrentCoordinate()

        if coordinate != nil {
            if let coordinate {
                await appState.syncLocation(
                    client: sessionStore.client,
                    lat: coordinate.latitude,
                    lng: coordinate.longitude,
                    source: source
                )
            }
        } else if status == .denied || status == .restricted {
            appState.lastError = "Location permission denied. You can enable it in Settings at any time."
        } else {
            await appState.syncLocation(
                client: sessionStore.client,
                lat: AppConfig.defaultLatitude,
                lng: AppConfig.defaultLongitude,
                source: "fallback_default"
            )
        }

        await appState.refreshAuthedData(client: sessionStore.client)
        markLocationPromptCompleted()
    }
}

private struct ProfileSetupView: View {
    private enum Step {
        case profile
        case location
        case notifications
    }

    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(LocationManager.self) private var locationManager

    @State private var name = ""
    @State private var city = "Toronto"
    @State private var province = "ON"
    @State private var isSaving = false
    @State private var step: Step = .profile

    var body: some View {
        Group {
            switch step {
            case .profile:
                VStack(spacing: 16) {
                    Text("Create Your Profile")
                        .font(.title2.bold())

                    TextField("Full name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("ProfileSetup.nameField")
                    TextField("City", text: $city)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("ProfileSetup.cityField")
                    TextField("Province", text: $province)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("ProfileSetup.provinceField")

                    Button(isSaving ? "Saving..." : "Continue") {
                        Task { await createProfile() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("ProfileSetup.continueButton")
                }

            case .location:
                VStack(spacing: 16) {
                    Text("Location Access")
                        .font(.title2.bold())
                    Text("Allow location so Patchwork can show nearby taskers.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Button("Allow") {
                        Task {
                            await requestAndSyncCurrentLocation()
                            step = .notifications
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("ProfileSetup.locationAllowButton")

                    Button("Skip") {
                        step = .notifications
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("ProfileSetup.locationSkipButton")
                }

            case .notifications:
                VStack(spacing: 16) {
                    Text("Notifications")
                        .font(.title2.bold())
                    Text("Turn on notifications to get messages and quote updates.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Button("Allow") {
                        Task { await finalizeSetup() }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("ProfileSetup.notificationsAllowButton")

                    Button("Skip") {
                        Task { await finalizeSetup() }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("ProfileSetup.notificationsSkipButton")
                }
            }
        }
        .padding(24)
    }

    private func createProfile() async {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await sessionStore.client.mutation(
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
        await appState.refreshAuthedData(client: sessionStore.client)
    }

    private func requestAndSyncCurrentLocation() async {
        _ = await locationManager.requestWhenInUseAuthorizationIfNeeded()
        if let coordinate = await locationManager.requestCurrentCoordinate() {
            await appState.syncLocation(
                client: sessionStore.client,
                lat: coordinate.latitude,
                lng: coordinate.longitude,
                source: "profile_setup"
            )
        } else {
            await appState.syncLocation(
                client: sessionStore.client,
                lat: AppConfig.defaultLatitude,
                lng: AppConfig.defaultLongitude,
                source: "fallback_default"
            )
        }
    }
}

private struct LocationPermissionGateView: View {
    let onAllow: () async -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Location Access")
                .font(.title2.bold())
            Text("Allow location so Patchwork can show nearby taskers and better local matches.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Allow") {
                Task { await onAllow() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("LocationPrompt.allowButton")

            Button("Skip") {
                onSkip()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("LocationPrompt.skipButton")
        }
        .padding(24)
    }
}

private struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

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
                    sessionStore.signOut()
                })
            }
            .accessibilityIdentifier("Tab.profile")
            .tabItem { Label("Profile", systemImage: "person") }
            .tag(AppState.Tab.profile)
        }
    }
}
