import SwiftUI

private enum ProfileSidebarDestination: String, Identifiable {
    case favourites

    var id: String { rawValue }
}

struct ProfileView: View {
    private enum MainLayout {
        static let horizontalGutter: CGFloat = 20
        static let topRhythm: CGFloat = 16
        static let bottomPadding: CGFloat = 16
    }

    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    @State private var isSidebarPresented = false
    @State private var activeDestination: ProfileSidebarDestination?

    let onSignOut: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            PatchworkBackdrop(tint: PatchworkTheme.brand)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ProfileHeaderCard {
                        withAnimation(.snappy(duration: 0.24)) {
                            isSidebarPresented = true
                        }
                    }

                    ProfileAccountSection(
                        user: appState.currentUser,
                        taskerProfile: appState.taskerProfile
                    )
                    ProfileTaskerSection(
                        userName: appState.currentUser?.name,
                        taskerProfile: appState.taskerProfile
                    )
                    ProfileSupportSection(onSignOut: onSignOut)
                    Text(appVersionLabel)
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, MainLayout.horizontalGutter)
            .padding(.top, MainLayout.topRhythm)
            .padding(.bottom, MainLayout.bottomPadding)
            .scrollIndicators(.hidden)
            .allowsHitTesting(!isSidebarPresented && activeDestination == nil)

            if isSidebarPresented {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        closeSidebar()
                    }
                    .transition(.opacity)
            }

            if isSidebarPresented {
                ProfileSidebarMenu(
                    userName: appState.currentUser?.name,
                    onClose: closeSidebar,
                    onOpenFavourites: {
                        openDestination(.favourites)
                    }
                )
                .padding(.top, MainLayout.topRhythm)
                .padding(.trailing, MainLayout.horizontalGutter)
                .padding(.bottom, 8)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(1)
            }

            if activeDestination == .favourites {
                FavouriteTaskersPanel(onClose: closeActiveDestination)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(.snappy(duration: 0.28), value: isSidebarPresented)
        .animation(.snappy(duration: 0.3), value: activeDestination)
        .task {
            await appState.refreshAuthedData(client: sessionStore.client)
        }
    }

    private func closeSidebar() {
        withAnimation(.snappy(duration: 0.24)) {
            isSidebarPresented = false
        }
    }

    private func openDestination(_ destination: ProfileSidebarDestination) {
        withAnimation(.snappy(duration: 0.18)) {
            isSidebarPresented = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.snappy(duration: 0.3)) {
                activeDestination = destination
            }
        }
    }

    private func closeActiveDestination() {
        withAnimation(.snappy(duration: 0.28)) {
            activeDestination = nil
        }
    }

    private var appVersionLabel: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, buildNumber) {
        case let (version?, build?) where !version.isEmpty && !build.isEmpty:
            return "Version \(version) (\(build))"
        case let (version?, _) where !version.isEmpty:
            return "Version \(version)"
        case let (_, build?) where !build.isEmpty:
            return "Build \(build)"
        default:
            return "Version unavailable"
        }
    }
}

private struct ProfileHeaderCard: View {
    let onOpenMenu: () -> Void

    var body: some View {
        PatchworkSurfaceCard {
            HStack(spacing: 16) {
                Text("Profile")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(PatchworkTheme.textPrimary)

                Spacer(minLength: 12)

                Button(action: onOpenMenu) {
                    Label("Menu", systemImage: "line.3.horizontal")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PatchworkTheme.brand)
                        .frame(width: 44, height: 44)
                        .background(PatchworkTheme.brandSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Menu")
                .accessibilityIdentifier("Profile.menuButton")
            }
        }
    }
}

private struct ProfileAccountSection: View {
    let user: CurrentUser?
    let taskerProfile: TaskerProfileSelf?

    var body: some View {
        PatchworkSurfaceCard {
            VStack(spacing: 16) {
                avatar

                VStack(spacing: 8) {
                    Text(user?.name ?? "Signed in")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(PatchworkTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Label(locationLabel, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    if user?.roles?.isSeeker == true {
                        roleBadge("Seeker", isPrimary: false)
                    }
                    if user?.roles?.isTasker == true {
                        roleBadge("Tasker", isPrimary: true)
                    }
                }
                .frame(maxWidth: .infinity)

                profileStatsRow
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PatchworkTheme.brandSoft, PatchworkTheme.surfaceMuted],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(initial)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(PatchworkTheme.brand)
            }
            .frame(width: 108, height: 108)
            .overlay(
                Circle()
                    .stroke(PatchworkTheme.brand.opacity(0.85), lineWidth: 5)
                    .padding(4)
            )
            .overlay(
                Circle()
                    .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
            )

            if taskerProfile?.verified == true {
                ZStack {
                    Circle()
                        .fill(PatchworkTheme.brand)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)
                .offset(x: 4, y: 4)
            }
        }
    }

    private func roleBadge(_ title: String, isPrimary: Bool) -> some View {
        Text(title)
            .font(.patchworkBodyStrong)
            .foregroundStyle(isPrimary ? PatchworkTheme.brand : PatchworkTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isPrimary ? PatchworkTheme.brandSoft.opacity(0.9) : PatchworkTheme.surfaceMuted,
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(isPrimary ? PatchworkTheme.strokeStrong : PatchworkTheme.stroke, lineWidth: 1)
            )
    }

    private var profileStatsRow: some View {
        HStack(spacing: 0) {
            statColumn(
                title: "Rating",
                value: ratingValue,
                icon: "star.fill",
                tint: PatchworkTheme.ratingStar,
                isUnlocked: taskerProfile != nil
            )

            Rectangle()
                .fill(PatchworkTheme.stroke)
                .frame(width: 1)
                .padding(.vertical, 8)
                .padding(.horizontal, 18)

            statColumn(
                title: "Completed jobs",
                value: completedJobsValue,
                icon: "checkmark.circle",
                tint: PatchworkTheme.brand,
                isUnlocked: taskerProfile != nil
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [
                    PatchworkTheme.brandSoft.opacity(0.42),
                    PatchworkTheme.surfaceMuted
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }

    private func statColumn(
        title: String,
        value: String,
        icon: String,
        tint: Color,
        isUnlocked: Bool
    ) -> some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(tint)
                }

            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(PatchworkTheme.textPrimary)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(isUnlocked ? 1 : 0.45)
        .overlay(alignment: .topTrailing) {
            if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PatchworkTheme.brand)
                    .frame(width: 28, height: 28)
                    .background(PatchworkTheme.surface.opacity(0.96), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(PatchworkTheme.stroke, lineWidth: 1)
                    )
            }
        }
    }

    private var ratingValue: String {
        guard let rating = taskerProfile?.rating else {
            return "--"
        }
        return rating.formatted(.number.precision(.fractionLength(1)))
    }

    private var completedJobsValue: String {
        guard let completedJobs = taskerProfile?.completedJobs else {
            return "--"
        }
        return completedJobs.formatted()
    }

    private var locationLabel: String {
        let city = user?.location?.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let province = user?.location?.province?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if city.isEmpty, province.isEmpty {
            return "Location not set"
        }
        if city.isEmpty {
            return province
        }
        if province.isEmpty {
            return city
        }
        return "\(city), \(province)"
    }

    private var initial: String {
        String((user?.name ?? "?").prefix(1)).uppercased()
    }
}

private struct ProfileTaskerSection: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    let userName: String?
    let taskerProfile: TaskerProfileSelf?

    @State private var ghostModeValue = false
    @State private var isUpdating = false
    @State private var feedbackMessage: SubscriptionFeedbackMessage?

    var body: some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tasker Workspace")
                    .font(.patchworkCardTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)

                if let taskerProfile {
                    if taskerProfile.displayName != userName {
                        Text("Listed as: \(taskerProfile.displayName)")
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }

                    accessSummaryCard(taskerProfile)
                    discoverabilityControls(for: taskerProfile)
                } else {
                    Text("Finish tasker onboarding to manage your profile, availability, and discoverability.")
                        .font(.patchworkBody)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                NavigationLink(taskerProfile == nil ? "Complete Tasker Setup" : "Manage Tasker Profile") {
                    TaskerOnboardingView()
                }
                .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Profile.taskerOnboardingLink"))

                if let taskerProfile {
                    NavigationLink(taskerProfile.hasActiveSubscription == true ? "Manage subscriptions" : "Activate subscription") {
                        SubscriptionsView()
                    }
                    .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Profile.visibilitySubscriptionLink"))
                }
            }
        }
        .task(id: taskerProfile?.ghostMode) {
            ghostModeValue = taskerProfile?.ghostMode ?? false
        }
    }

    private func discoverabilityControls(for profile: TaskerProfileSelf) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ghost Mode")
                        .font(.patchworkBodyStrong)
                        .foregroundStyle(PatchworkTheme.textPrimary)

                    Text(ghostModeDescription)
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: ghostModeBinding(for: profile))
                    .labelsHidden()
                    .disabled(isUpdating || profile.hasActiveSubscription != true)
                    .tint(PatchworkTheme.brand)
            }

            if let feedbackMessage {
                PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                    .accessibilityIdentifier("Profile.ghostModeBanner")
            }

            if profile.hasActiveSubscription != true {
                Text("Activate paid tasker access to change this setting.")
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
            }
        }
        .padding(14)
        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }

    private func accessSummaryCard(_ profile: TaskerProfileSelf) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(planTitle(for: profile))
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(planTitleColor(for: profile))
                Text(planDescription(for: profile))
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            statusBadge(for: profile)
        }
        .padding(14)
        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }

    private func ghostModeBinding(for profile: TaskerProfileSelf) -> Binding<Bool> {
        Binding(
            get: { ghostModeValue },
            set: { newValue in
                guard profile.hasActiveSubscription == true, !isUpdating else {
                    ghostModeValue = profile.ghostMode
                    return
                }

                ghostModeValue = newValue
                Task { await setGhostMode(newValue) }
            }
        )
    }

    private var ghostModeDescription: String {
        ghostModeValue
            ? "Your profile is hidden from search."
            : "Your profile will appear in search."
    }

    private func statusBadge(for taskerProfile: TaskerProfileSelf) -> some View {
        let status = taskerProfile.subscriptionStatus ?? "inactive"
        let title: String
        let foreground: Color
        let background: Color

        switch status {
        case "active":
            title = "Subscribed"
            foreground = PatchworkTheme.brand
            background = PatchworkTheme.brand.opacity(0.12)
        case "cancel_at_period_end":
            title = "Ending soon"
            foreground = PatchworkTheme.warning
            background = PatchworkTheme.warning.opacity(0.14)
        case "expired":
            title = "Expired"
            foreground = PatchworkTheme.textSecondary
            background = PatchworkTheme.stroke
        default:
            title = "Inactive"
            foreground = PatchworkTheme.textSecondary
            background = PatchworkTheme.stroke
        }

        return Text(title)
            .font(.patchworkCaption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
    }

    private func planTitle(for taskerProfile: TaskerProfileSelf) -> String {
        switch taskerProfile.subscriptionPlan {
        case "tasker":
            switch taskerProfile.subscriptionAccessType {
            case "lifetime":
                return "Lifetime access"
            case "weekly":
                return "Weekly access"
            default:
                return "Tasker access"
            }
        case "premium":
            return "Premium plan"
        case "basic":
            return "Basic plan"
        default:
            return taskerProfile.subscriptionStatus == "expired" ? "Subscription expired" : "No active plan"
        }
    }

    private func planTitleColor(for taskerProfile: TaskerProfileSelf) -> Color {
        switch taskerProfile.subscriptionStatus ?? "inactive" {
        case "active":
            return PatchworkTheme.brand
        case "cancel_at_period_end":
            return PatchworkTheme.warning
        case "expired":
            return PatchworkTheme.textSecondary
        default:
            return PatchworkTheme.textPrimary
        }
    }

    private func planDescription(for taskerProfile: TaskerProfileSelf) -> String {
        let status = taskerProfile.subscriptionStatus ?? "inactive"

        switch status {
        case "active":
            if taskerProfile.subscriptionAccessType == "lifetime" {
                return "Lifetime tasker access is active on this account."
            }
            return "Paid tasker access is active on this account."
        case "cancel_at_period_end":
            if let endsAt = taskerProfile.subscriptionEndsAt {
                return "Access remains active until \(formattedMonthDayYear(endsAt))."
            }
            return "Cancellation is scheduled for the end of the current term."
        case "expired":
            return "Your paid tasker access has ended."
        default:
            return "Activate paid tasker access to be listed as a tasker."
        }
    }

    private func formattedMonthDayYear(_ millis: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        return date.formatted(.dateTime.month(.wide).day().year())
    }

    private func setGhostMode(_ enabled: Bool) async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            let updatedProfile = try await sessionStore.client.mutation("taskers:setGhostMode", args: ["ghostMode": enabled]) as TaskerProfileSelf
            appState.taskerProfile = updatedProfile
            ghostModeValue = updatedProfile.ghostMode
            await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)
            feedbackMessage = SubscriptionFeedbackMessage(
                tone: .success,
                text: enabled ? "Ghost Mode turned on." : "Ghost Mode turned off."
            )
        } catch {
            ghostModeValue = appState.taskerProfile?.ghostMode ?? false
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }
}

private struct ProfileSidebarMenu: View {
    let userName: String?
    let onClose: () -> Void
    let onOpenFavourites: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Settings")
                    .font(.patchworkSectionTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(PatchworkTheme.surfaceMuted, in: Circle())
                }
                .buttonStyle(.plain)
            }

            if let userName, !userName.isEmpty {
                Text(userName)
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
            }

            Button(action: onOpenFavourites) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PatchworkTheme.brand)
                        .frame(width: 42, height: 42)
                        .background(PatchworkTheme.brandSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Favourites")
                            .font(.patchworkBodyStrong)
                            .foregroundStyle(PatchworkTheme.textPrimary)
                        Text("Saved taskers")
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PatchworkTheme.textTertiary)
                }
                .padding(16)
                .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PatchworkTheme.stroke, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Profile.sidebarFavouritesButton")

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 292)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(PatchworkTheme.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 28, y: 18)
    }
}

private struct FavouriteTaskersPanel: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    private let usesVisualPreview = ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_EMPTY_TABS")

    let onClose: () -> Void

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brand)

            VStack(spacing: 0) {
                PatchworkSurfaceCard {
                    HStack(spacing: 14) {
                        Button(action: onClose) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(PatchworkTheme.textPrimary)
                                .frame(width: 50, height: 50)
                                .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(PatchworkTheme.stroke, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Profile.favouritesBackButton")

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Favourites")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(PatchworkTheme.textPrimary)

                            Text(favouritesSubtitle)
                                .font(.patchworkCaption)
                                .foregroundStyle(PatchworkTheme.textSecondary)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 14) {
                        if appState.favouriteTaskers.isEmpty {
                            PatchworkEmptyStateCard(
                                systemImage: "heart.slash",
                                title: "No favourites yet",
                                message: "Saved taskers will appear here once you start favouriting providers."
                            )
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("Profile.favouritesEmptyState")
                        } else {
                            ForEach(appState.favouriteTaskers) { tasker in
                                favouriteTaskerRow(tasker)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
        }
        .task {
            guard !usesVisualPreview else {
                return
            }
            await appState.refreshFavouriteTaskers(client: sessionStore.client)
        }
    }

    private var favouritesSubtitle: String {
        let count = appState.favouriteTaskers.count
        if count == 0 {
            return "Saved taskers will appear here"
        }
        return count == 1 ? "1 saved tasker" : "\(count) saved taskers"
    }

    private func favouriteTaskerRow(_ tasker: TaskerSummary) -> some View {
        PatchworkSurfaceCard {
            HStack(alignment: .top, spacing: 14) {
                favouriteAvatar(for: tasker)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(tasker.displayName)
                            .font(.patchworkBodyStrong)
                            .foregroundStyle(PatchworkTheme.textPrimary)

                        if tasker.verified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(PatchworkTheme.success)
                        }
                    }

                    if let categoryName = tasker.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !categoryName.isEmpty {
                        Text(categoryName)
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }

                    HStack(spacing: 12) {
                        summaryPill(
                            icon: "star.fill",
                            text: tasker.averageRating?.formatted(.number.precision(.fractionLength(1))) ?? "New",
                            tint: PatchworkTheme.ratingStar
                        )

                        summaryPill(
                            icon: "checkmark.circle",
                            text: tasker.completedJobs?.formatted() ?? "0",
                            tint: PatchworkTheme.brand
                        )

                        if let rateLabel = tasker.rateLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !rateLabel.isEmpty {
                            Text(rateLabel)
                                .font(.patchworkCaption)
                                .foregroundStyle(PatchworkTheme.brand)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityIdentifier("Profile.favouriteTasker.\(tasker.id)")
    }

    private func favouriteAvatar(for tasker: TaskerSummary) -> some View {
        let avatarURL = tasker.avatarUrl.flatMap(URL.init(string:))

        return Group {
            if let avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    avatarPlaceholder(for: tasker)
                }
            } else {
                avatarPlaceholder(for: tasker)
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }

    private func avatarPlaceholder(for tasker: TaskerSummary) -> some View {
        ZStack {
            PatchworkTheme.brandSoft
            Text(String(tasker.displayName.prefix(1)).uppercased())
                .font(.title3.weight(.bold))
                .foregroundStyle(PatchworkTheme.brand)
        }
    }

    private func summaryPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(text)
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textPrimary)
        }
    }
}

private struct ProfileSupportSection: View {
    let onSignOut: () -> Void

    var body: some View {
        PatchworkSurfaceCard {
            VStack(spacing: 14) {
                NavigationLink("Help & Support") {
                    HelpView()
                }
                .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Profile.helpLink"))

                Button("Sign Out", role: .destructive) {
                    onSignOut()
                }
                .buttonStyle(PatchworkSecondaryButtonStyle())
                .tint(PatchworkTheme.danger)
                .accessibilityIdentifier("Profile.signOutButton")
            }
        }
    }
}

private struct ProfileLinkRowStyle: ViewModifier {
    let accessibilityIdentifier: String

    func body(content: Content) -> some View {
        content
            .font(.patchworkBodyStrong)
            .foregroundStyle(PatchworkTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.trailing, 34)
            .frame(height: 48)
            .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PatchworkTheme.stroke, lineWidth: 1)
            )
            .overlay(alignment: .trailing) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PatchworkTheme.textTertiary)
                    .padding(.trailing, 16)
            }
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct TaskerOnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var displayName = ""
    @State private var selectedCategoryId: ConvexID?

    @State private var categoryBio = ""
    @State private var rateType = "hourly"
    @State private var hourlyRate = ""
    @State private var fixedRate = ""
    @State private var serviceRadius = 25
    @State private var isShowingSubscriptions = false

    @State private var profileDisplayName = ""
    @State private var addCategorySheet = false

    var body: some View {
        Group {
            if let profile = appState.taskerProfile, step < 4 {
                TaskerProfileManageView(
                    profileDisplayName: $profileDisplayName,
                    addCategorySheet: $addCategorySheet,
                    categories: appState.categories,
                    existingCategoryIDs: Set(profile.categories.map { $0.categoryId }),
                    onSaveProfile: updateTaskerProfile,
                    onRemoveCategory: removeCategory,
                    onAddCategory: { draft in Task { await addCategory(draft: draft) } },
                    onUpdateCategory: updateTaskerCategory
                )
                .onAppear {
                    profileDisplayName = profile.displayName
                }
            } else {
                TaskerCreateFlowView(
                    step: $step,
                    displayName: $displayName,
                    selectedCategoryId: $selectedCategoryId,
                    categories: appState.categories,
                    categoryBio: $categoryBio,
                    rateType: $rateType,
                    hourlyRate: $hourlyRate,
                    fixedRate: $fixedRate,
                    serviceRadius: $serviceRadius,
                    onSubmit: { Task { await createProfile() } },
                    onSubscribe: { isShowingSubscriptions = true },
                    onDone: { dismiss() }
                )
            }
        }
        .navigationTitle("Tasker Setup")
        .navigationDestination(isPresented: $isShowingSubscriptions) {
            SubscriptionsView()
        }
        .task {
            await appState.refreshAuthedData(client: sessionStore.client)
        }
    }

    private func createProfile() async {
        guard let selectedCategoryId else { return }

        let hourlyCents = Int((Double(hourlyRate) ?? 0) * 100)
        let fixedCents = Int((Double(fixedRate) ?? 0) * 100)
        var args: [String: Any] = [
            "displayName": displayName,
            "categoryId": selectedCategoryId,
            "categoryBio": categoryBio,
            "rateType": rateType,
            "serviceRadius": serviceRadius,
        ]
        if rateType == "hourly" {
            args["hourlyRate"] = max(hourlyCents, 1)
        } else {
            args["fixedRate"] = max(fixedCents, 1)
        }

        do {
            _ = try await sessionStore.client.mutation("taskers:createTaskerProfile", args: args) as ConvexID
            step = 4
            isShowingSubscriptions = true
            Task {
                await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)
            }
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func updateTaskerProfile(displayName: String) async throws {
        let updatedProfile = try await sessionStore.client.mutation(
            "taskers:updateTaskerProfile",
            args: [
                "displayName": displayName,
            ]
        ) as TaskerProfileSelf
        appState.taskerProfile = updatedProfile
    }

    private func removeCategory(categoryId: ConvexID) async throws {
        _ = try await sessionStore.client.mutation(
            "taskers:removeTaskerCategory",
            args: ["categoryId": categoryId]
        ) as EmptyResponse
        await appState.refreshAuthedData(client: sessionStore.client)
    }

    private func addCategory(draft: TaskerCategoryDraft) async {
        do {
            _ = try await sessionStore.client.mutation(
                "taskers:addTaskerCategory",
                args: [
                    "categoryId": draft.categoryId,
                    "categoryBio": draft.categoryBio,
                    "rateType": draft.rateType,
                    "hourlyRate": draft.rateType == "hourly" ? max(Int((Double(draft.hourlyRate) ?? 0) * 100), 1) : nil,
                    "fixedRate": draft.rateType == "fixed" ? max(Int((Double(draft.fixedRate) ?? 0) * 100), 1) : nil,
                    "serviceRadius": draft.serviceRadius,
                ].compactMapValues { $0 }
            ) as EmptyResponse
            await appState.refreshAuthedData(client: sessionStore.client)
            addCategorySheet = false
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func updateTaskerCategory(draft: TaskerCategoryDraft) async throws {
        let updatedProfile = try await sessionStore.client.mutation(
            "taskers:updateTaskerCategory",
            args: [
                "categoryId": draft.categoryId,
                "categoryBio": draft.categoryBio,
                "rateType": draft.rateType,
                "hourlyRate": draft.rateType == "hourly" ? max(Int((Double(draft.hourlyRate) ?? 0) * 100), 1) : nil,
                "fixedRate": draft.rateType == "fixed" ? max(Int((Double(draft.fixedRate) ?? 0) * 100), 1) : nil,
                "serviceRadius": draft.serviceRadius,
            ].compactMapValues { $0 }
        ) as TaskerProfileSelf
        appState.taskerProfile = updatedProfile
    }
}

private struct TaskerCategoryDraft {
    let categoryId: ConvexID
    let categoryBio: String
    let rateType: String
    let hourlyRate: String
    let fixedRate: String
    let serviceRadius: Int

    init(
        categoryId: ConvexID,
        categoryBio: String,
        rateType: String,
        hourlyRate: String,
        fixedRate: String,
        serviceRadius: Int
    ) {
        self.categoryId = categoryId
        self.categoryBio = categoryBio
        self.rateType = rateType
        self.hourlyRate = hourlyRate
        self.fixedRate = fixedRate
        self.serviceRadius = serviceRadius
    }

    init(category: TaskerManagedCategory) {
        self.categoryId = category.categoryId
        self.categoryBio = category.bio
        self.rateType = category.rateType
        self.hourlyRate = Self.priceFieldText(from: category.hourlyRate)
        self.fixedRate = Self.priceFieldText(from: category.fixedRate)
        self.serviceRadius = category.serviceRadius
    }

    private static func priceFieldText(from cents: Int?) -> String {
        guard let cents else { return "" }
        return (Double(cents) / 100).formatted(.number.precision(.fractionLength(2)))
    }
}

private enum TaskerCreateFocusField: Hashable {
    case displayName
    case bio
    case hourlyRate
    case fixedRate
}

private struct TaskerCreateFlowView: View {
    @Binding var step: Int
    @Binding var displayName: String
    @Binding var selectedCategoryId: ConvexID?
    let categories: [Category]
    @Binding var categoryBio: String
    @Binding var rateType: String
    @Binding var hourlyRate: String
    @Binding var fixedRate: String
    @Binding var serviceRadius: Int
    let onSubmit: () -> Void
    let onSubscribe: () -> Void
    let onDone: () -> Void

    @State private var acceptedTerms = false
    @FocusState private var focusedField: TaskerCreateFocusField?

    private var canCompleteSetup: Bool {
        acceptedTerms
    }

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brand)

            ScrollView {
                VStack(spacing: 18) {
                    StepHeader(currentStep: min(step, 3))
                        .padding(.top, 12)

                    if step >= 4 {
                        PatchworkSurfaceCard {
                            VStack(spacing: 18) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(PatchworkTheme.success)

                                Text("Tasker profile created")
                                    .font(.patchworkSectionTitle)
                                    .foregroundStyle(PatchworkTheme.textPrimary)

                                Text("To become discoverable to Seekers in your area, subscribe to a plan.")
                                    .font(.patchworkBody)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(PatchworkTheme.textSecondary)

                                Button("Subscribe") {
                                    onSubscribe()
                                }
                                .buttonStyle(PatchworkPrimaryButtonStyle())
                                .accessibilityIdentifier("TaskerOnboarding4.subscribeButton")

                                Button("Done", action: onDone)
                                    .buttonStyle(PatchworkSecondaryButtonStyle())
                                    .accessibilityIdentifier("TaskerOnboarding4.doneButton")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        onboardingStepContent
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var onboardingStepContent: some View {
        switch step {
        case 1:
            PatchworkSurfaceCard {
                VStack(alignment: .leading, spacing: 18) {
                    PatchworkSectionIntro(
                        eyebrow: "Tasker setup",
                        title: "Build your public identity",
                        message: "Choose the name and primary category seekers will see first."
                    )

                    TextField("Display name", text: $displayName)
                        .patchworkInputFieldStyle()
                        .focused($focusedField, equals: .displayName)
                        .accessibilityIdentifier("TaskerOnboarding1.displayNameField")

                    NavigationLink {
                        CategoriesView(
                            title: "Select Primary Category",
                            selectedCategoryID: selectedCategoryId,
                            dismissOnSelect: true,
                            onSelect: { category in
                                selectedCategoryId = category.id
                            }
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Primary category")
                                    .font(.patchworkCaption)
                                    .foregroundStyle(PatchworkTheme.textSecondary)
                                Text(selectedCategoryName)
                                    .font(.patchworkBody)
                                    .foregroundStyle(PatchworkTheme.textPrimary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PatchworkTheme.textTertiary)
                        }
                        .padding(16)
                        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(PatchworkTheme.stroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("TaskerOnboarding1.categoryPicker")

                    Button("Continue") {
                        step = 2
                        focusedField = .bio
                    }
                    .buttonStyle(PatchworkPrimaryButtonStyle())
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategoryId == nil)
                    .accessibilityIdentifier("TaskerOnboarding1.continueButton")
                }
            }
        case 2:
            VStack(spacing: 18) {
                CategoryServiceDetailsSection(
                    title: "Service details",
                    eyebrow: "Tasker setup",
                    message: "Set your pricing and service range with clean, explicit terms.",
                    bio: $categoryBio,
                    rateType: $rateType,
                    hourlyRate: $hourlyRate,
                    fixedRate: $fixedRate,
                    serviceRadius: $serviceRadius,
                    focusedField: $focusedField,
                    accessibilityPrefix: "TaskerOnboarding2"
                )

                HStack(spacing: 12) {
                    Button("Back") { step = 1 }
                        .buttonStyle(PatchworkSecondaryButtonStyle())
                        .accessibilityIdentifier("TaskerOnboarding2.backButton")

                    Button("Continue") { step = 3 }
                        .buttonStyle(PatchworkPrimaryButtonStyle())
                        .disabled(categoryBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("TaskerOnboarding2.continueButton")
                }
            }
        default:
            PatchworkSurfaceCard {
                VStack(alignment: .leading, spacing: 18) {
                    PatchworkSectionIntro(
                        eyebrow: "Tasker setup",
                        title: "Review & accept",
                        message: "Confirm the essentials, then finish creating your tasker profile."
                    )

                    onboardingSummaryRow("Display name", value: displayName)
                    onboardingSummaryRow("Rate type", value: rateType.capitalized)
                    onboardingSummaryRow("Radius", value: "\(serviceRadius) km")

                    Button {
                        acceptedTerms.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text("I agree to the Tasker terms and community guidelines.")
                                .font(.patchworkBody)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(PatchworkTheme.textPrimary)
                            Spacer(minLength: 12)
                            Image(systemName: acceptedTerms ? "checkmark.circle.fill" : "circle")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(acceptedTerms ? PatchworkTheme.brand : PatchworkTheme.strokeStrong)
                        }
                        .padding(16)
                        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(PatchworkTheme.stroke, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("TaskerOnboarding4.acceptTermsToggle")

                    HStack(spacing: 12) {
                        Button("Back") { step = 2 }
                            .buttonStyle(PatchworkSecondaryButtonStyle())
                            .accessibilityIdentifier("TaskerOnboarding4.backButton")

                        Button("Complete Setup", action: onSubmit)
                            .buttonStyle(PatchworkPrimaryButtonStyle())
                            .disabled(!canCompleteSetup)
                            .accessibilityIdentifier("TaskerOnboarding4.completeButton")
                    }
                }
            }
        }
    }

    private func onboardingSummaryRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.textPrimary)
        }
    }

    private var selectedCategoryName: String {
        guard let selectedCategoryId,
              let selectedCategory = categories.first(where: { $0.id == selectedCategoryId }) else {
            return "Choose"
        }
        return selectedCategory.name
    }
}

private struct TaskerProfileManageView: View {
    @Environment(AppState.self) private var appState

    @Binding var profileDisplayName: String
    @Binding var addCategorySheet: Bool
    let categories: [Category]
    let existingCategoryIDs: Set<ConvexID>
    let onSaveProfile: (String) async throws -> Void
    let onRemoveCategory: (ConvexID) async throws -> Void
    let onAddCategory: (TaskerCategoryDraft) -> Void
    let onUpdateCategory: (TaskerCategoryDraft) async throws -> Void

    @State private var selectedCategoryID: ConvexID?
    @State private var feedbackMessage: SubscriptionFeedbackMessage?
    @State private var isSavingProfile = false

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brandBright)

            ScrollView {
                VStack(spacing: 18) {
                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 18) {
                            PatchworkSectionIntro(
                                eyebrow: "Tasker profile",
                                title: "Keep your listing sharp",
                                message: "Update your display name here. Edit each category to control the bio, pricing, and service radius seekers actually see."
                            )

                            TextField("Display name", text: $profileDisplayName)
                                .patchworkInputFieldStyle()
                                .accessibilityIdentifier("TaskerProfile.displayNameField")

                            if let feedbackMessage {
                                PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                                    .accessibilityIdentifier("TaskerProfile.statusBanner")
                            }

                            Button(isSavingProfile ? "Saving..." : "Save") {
                                Task { await saveProfile() }
                            }
                                .buttonStyle(PatchworkPrimaryButtonStyle())
                                .disabled(isSavingProfile || profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .accessibilityIdentifier("TaskerProfile.saveButton")
                        }
                    }

                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Categories")
                                .font(.patchworkCardTitle)
                                .foregroundStyle(PatchworkTheme.textPrimary)

                            NavigationLink("Browse Category Library") {
                                CategoriesView(title: "Category Library", dismissOnSelect: false, onSelect: { _ in })
                            }
                            .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "TaskerProfile.categoryLibraryLink"))

                            ForEach(appState.taskerProfile?.categories ?? []) { category in
                                Button {
                                    selectedCategoryID = category.categoryId
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(category.categoryName)
                                                .font(.patchworkBodyStrong)
                                                .foregroundStyle(PatchworkTheme.textPrimary)
                                            Text(summaryLabel(for: category))
                                                .font(.patchworkCaption)
                                                .foregroundStyle(PatchworkTheme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(PatchworkTheme.textTertiary)
                                    }
                                    .padding(16)
                                    .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(PatchworkTheme.stroke, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("TaskerProfile.category.\(category.categoryId)")
                            }

                            Button("Add Category") {
                                addCategorySheet = true
                            }
                            .buttonStyle(PatchworkSecondaryButtonStyle())
                            .accessibilityIdentifier("TaskerProfile.addCategoryButton")

                            NavigationLink("Category Help") {
                                HelpView()
                            }
                            .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "TaskerProfile.categoryHelpLink"))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $addCategorySheet) {
            AddCategorySheet(
                categories: categories,
                existingCategoryIDs: existingCategoryIDs,
                onAdd: onAddCategory
            )
            .patchworkSheetChrome()
        }
        .sheet(
            isPresented: Binding(
                get: { selectedCategoryID != nil && selectedCategory != nil },
                set: { isPresented in
                    if !isPresented {
                        selectedCategoryID = nil
                    }
                }
            )
        ) {
            if let category = selectedCategory {
                EditableTaskerCategorySheet(
                    category: category,
                    onSave: onUpdateCategory,
                    onRemove: {
                        try await onRemoveCategory(category.categoryId)
                    }
                )
                .patchworkSheetChrome()
            }
        }
        .onChange(of: profileDisplayName) { _, _ in
            if feedbackMessage?.tone == .success {
                feedbackMessage = nil
            }
        }
    }

    private var selectedCategory: TaskerManagedCategory? {
        guard let selectedCategoryID else {
            return nil
        }

        return appState.taskerProfile?.categories.first(where: { $0.categoryId == selectedCategoryID })
    }

    private func saveProfile() async {
        let trimmedDisplayName = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDisplayName.isEmpty else {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: "Display name is required.")
            return
        }

        isSavingProfile = true
        feedbackMessage = nil
        defer { isSavingProfile = false }

        do {
            try await onSaveProfile(trimmedDisplayName)
            feedbackMessage = SubscriptionFeedbackMessage(tone: .success, text: "Display name updated.")
        } catch {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }

    private func summaryLabel(for category: TaskerManagedCategory) -> String {
        let rateTypeLabel = category.rateType.capitalized
        let priceLabel: String
        if category.rateType == "hourly", let hourlyRate = category.hourlyRate {
            priceLabel = "$\((Double(hourlyRate) / 100).formatted(.number.precision(.fractionLength(2))))/hr"
        } else if let fixedRate = category.fixedRate {
            priceLabel = "$\((Double(fixedRate) / 100).formatted(.number.precision(.fractionLength(2))))"
        } else {
            priceLabel = "Rate unavailable"
        }

        return "\(rateTypeLabel) • \(priceLabel) • \(category.serviceRadius) km"
    }
}

private struct CategoryServiceDetailsSection: View {
    private enum FallbackField: Hashable {
        case bio
        case hourlyRate
        case fixedRate
    }

    let title: String
    let eyebrow: String?
    let message: String?
    @Binding var bio: String
    @Binding var rateType: String
    @Binding var hourlyRate: String
    @Binding var fixedRate: String
    @Binding var serviceRadius: Int
    var focusedField: FocusState<TaskerCreateFocusField?>.Binding? = nil
    let accessibilityPrefix: String

    var body: some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                if let message {
                    PatchworkSectionIntro(
                        eyebrow: eyebrow,
                        title: title,
                        message: message
                    )
                } else {
                    Text(title)
                        .font(.patchworkCardTitle)
                        .foregroundStyle(PatchworkTheme.textPrimary)
                }

                bioField

                Picker("Rate type", selection: $rateType) {
                    Text("Hourly").tag("hourly")
                    Text("Fixed").tag("fixed")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("\(accessibilityPrefix).rateTypePicker")

                if rateType == "hourly" {
                    hourlyRateField
                } else {
                    fixedRateField
                }

                Stepper("Service radius: \(serviceRadius) km", value: $serviceRadius, in: 1 ... 250)
                    .font(.patchworkBody)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                    .padding(16)
                    .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PatchworkTheme.stroke, lineWidth: 1)
                    )
                    .accessibilityIdentifier("\(accessibilityPrefix).radiusStepper")
            }
        }
    }

    @ViewBuilder
    private var bioField: some View {
        let field = TextEditor(text: $bio)
            .font(.patchworkBody)
            .foregroundStyle(PatchworkTheme.textPrimary)
            .frame(minHeight: 110)
            .padding(10)
            .background(PatchworkTheme.surface, in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                    .stroke(PatchworkTheme.stroke, lineWidth: 1)
            )
            .accessibilityIdentifier("\(accessibilityPrefix).bioField")

        if let focusedField {
            field
                .focused(focusedField, equals: .bio)
                .simultaneousGesture(TapGesture().onEnded {
                    focusedField.wrappedValue = .bio
                })
        } else {
            field
        }
    }

    @ViewBuilder
    private var hourlyRateField: some View {
        let field = TextField("Hourly rate", text: $hourlyRate)
            .keyboardType(.decimalPad)
            .patchworkInputFieldStyle()
            .accessibilityIdentifier("\(accessibilityPrefix).hourlyRateField")

        if let focusedField {
            field
                .focused(focusedField, equals: .hourlyRate)
                .simultaneousGesture(TapGesture().onEnded {
                    focusedField.wrappedValue = .hourlyRate
                })
        } else {
            field
        }
    }

    @ViewBuilder
    private var fixedRateField: some View {
        let field = TextField("Fixed rate", text: $fixedRate)
            .keyboardType(.decimalPad)
            .patchworkInputFieldStyle()
            .accessibilityIdentifier("\(accessibilityPrefix).fixedRateField")

        if let focusedField {
            field
                .focused(focusedField, equals: .fixedRate)
                .simultaneousGesture(TapGesture().onEnded {
                    focusedField.wrappedValue = .fixedRate
                })
        } else {
            field
        }
    }
}

private struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let categories: [Category]
    let existingCategoryIDs: Set<ConvexID>
    let onAdd: (TaskerCategoryDraft) -> Void

    @State private var selectedCategoryId: ConvexID?
    @State private var categoryBio = ""
    @State private var rateType = "hourly"
    @State private var hourlyRate = ""
    @State private var fixedRate = ""
    @State private var serviceRadius = 25

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.accent)

            ScrollView {
                VStack(spacing: 18) {
                    PatchworkTopBar(title: "Add Category", onBack: { dismiss() })
                        .accessibilityIdentifier("AddCategorySheet.cancelButton")

                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 18) {
                            PatchworkSectionIntro(
                                eyebrow: "Tasker profile",
                                title: "Add another service",
                                message: "Expand your listing with a new category, clear pricing, and service radius."
                            )

                            NavigationLink {
                                CategoriesView(
                                    title: "Select Category",
                                    selectedCategoryID: selectedCategoryId,
                                    excludedCategoryIDs: existingCategoryIDs,
                                    dismissOnSelect: true,
                                    onSelect: { category in
                                        selectedCategoryId = category.id
                                    }
                                )
                            } label: {
                                HStack {
                                    Text("Category")
                                        .font(.patchworkCaption)
                                        .foregroundStyle(PatchworkTheme.textSecondary)
                                    Spacer()
                                    Text(selectedCategoryName)
                                        .font(.patchworkBody)
                                        .foregroundStyle(PatchworkTheme.textPrimary)
                                }
                                .padding(16)
                                .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(PatchworkTheme.stroke, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("AddCategorySheet.categoryPicker")

                            CategoryServiceDetailsSection(
                                title: "Details",
                                eyebrow: nil,
                                message: nil,
                                bio: $categoryBio,
                                rateType: $rateType,
                                hourlyRate: $hourlyRate,
                                fixedRate: $fixedRate,
                                serviceRadius: $serviceRadius,
                                accessibilityPrefix: "AddCategorySheet"
                            )

                            Button("Add") {
                                guard let selectedCategoryId else { return }
                                onAdd(
                                    TaskerCategoryDraft(
                                        categoryId: selectedCategoryId,
                                        categoryBio: categoryBio,
                                        rateType: rateType,
                                        hourlyRate: hourlyRate,
                                        fixedRate: fixedRate,
                                        serviceRadius: serviceRadius
                                    )
                                )
                            }
                            .buttonStyle(PatchworkPrimaryButtonStyle())
                            .disabled(!canSubmit)
                            .accessibilityIdentifier("AddCategorySheet.addButton")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var availableCategories: [Category] {
        categories.filter { !existingCategoryIDs.contains($0.id) }
    }

    private var selectedCategoryName: String {
        guard let selectedCategoryId,
              let selectedCategory = availableCategories.first(where: { $0.id == selectedCategoryId }) else {
            return "Choose"
        }
        return selectedCategory.name
    }

    private var canSubmit: Bool {
        guard selectedCategoryId != nil,
              !categoryBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        if rateType == "hourly" {
            return (Double(hourlyRate) ?? 0) > 0
        }
        return (Double(fixedRate) ?? 0) > 0
    }
}

private struct EditableTaskerCategorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: TaskerManagedCategory
    let onSave: (TaskerCategoryDraft) async throws -> Void
    let onRemove: () async throws -> Void

    @State private var categoryBio: String
    @State private var rateType: String
    @State private var hourlyRate: String
    @State private var fixedRate: String
    @State private var serviceRadius: Int
    @State private var feedbackMessage: SubscriptionFeedbackMessage?
    @State private var isSaving = false
    @State private var isRemoving = false

    init(
        category: TaskerManagedCategory,
        onSave: @escaping (TaskerCategoryDraft) async throws -> Void,
        onRemove: @escaping () async throws -> Void
    ) {
        self.category = category
        self.onSave = onSave
        self.onRemove = onRemove

        let draft = TaskerCategoryDraft(category: category)
        _categoryBio = State(initialValue: draft.categoryBio)
        _rateType = State(initialValue: draft.rateType)
        _hourlyRate = State(initialValue: draft.hourlyRate)
        _fixedRate = State(initialValue: draft.fixedRate)
        _serviceRadius = State(initialValue: draft.serviceRadius)
    }

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.accent)

            ScrollView {
                VStack(spacing: 18) {
                    PatchworkTopBar(title: category.categoryName, onBack: { dismiss() })
                        .accessibilityIdentifier("TaskerProfile.categoryCloseButton")

                    if let feedbackMessage {
                        PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                            .accessibilityIdentifier("TaskerProfile.categoryStatusBanner")
                    }

                    CategoryServiceDetailsSection(
                        title: "Public listing details",
                        eyebrow: "Category",
                        message: "This bio, rate, and radius drive what seekers see first for this service.",
                        bio: $categoryBio,
                        rateType: $rateType,
                        hourlyRate: $hourlyRate,
                        fixedRate: $fixedRate,
                        serviceRadius: $serviceRadius,
                        accessibilityPrefix: "TaskerProfileCategorySheet"
                    )

                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Performance")
                                .font(.patchworkCardTitle)
                                .foregroundStyle(PatchworkTheme.textPrimary)
                            detailRow("Rating", value: ratingLabel)
                            detailRow("Reviews", value: countLabel(category.reviewCount))
                            detailRow("Completed Jobs", value: countLabel(category.completedJobs))
                        }
                    }

                    Button(isSaving ? "Saving..." : "Save Changes") {
                        Task { await saveChanges() }
                    }
                    .buttonStyle(PatchworkPrimaryButtonStyle())
                    .disabled(isSaving || isRemoving || !canSubmit)
                    .accessibilityIdentifier("TaskerProfile.categorySaveButton")

                    Button("Remove Category", role: .destructive) {
                        Task { await removeCategory() }
                    }
                    .buttonStyle(PatchworkSecondaryButtonStyle())
                    .disabled(isSaving || isRemoving)
                    .accessibilityIdentifier("TaskerProfile.removeCategoryButton")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var canSubmit: Bool {
        guard !categoryBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        if rateType == "hourly" {
            return (Double(hourlyRate) ?? 0) > 0
        }
        return (Double(fixedRate) ?? 0) > 0
    }

    private func saveChanges() async {
        guard canSubmit else {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: "Enter a bio, price, and service radius before saving.")
            return
        }

        isSaving = true
        feedbackMessage = nil
        defer { isSaving = false }

        do {
            try await onSave(
                TaskerCategoryDraft(
                    categoryId: category.categoryId,
                    categoryBio: categoryBio.trimmingCharacters(in: .whitespacesAndNewlines),
                    rateType: rateType,
                    hourlyRate: hourlyRate.trimmingCharacters(in: .whitespacesAndNewlines),
                    fixedRate: fixedRate.trimmingCharacters(in: .whitespacesAndNewlines),
                    serviceRadius: serviceRadius
                )
            )
            dismiss()
        } catch {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }

    private func removeCategory() async {
        isRemoving = true
        feedbackMessage = nil
        defer { isRemoving = false }

        do {
            try await onRemove()
            dismiss()
        } catch {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.textPrimary)
        }
    }

    private var ratingLabel: String {
        guard let rating = category.rating else { return "Not rated" }
        return rating.formatted(.number.precision(.fractionLength(1)))
    }

    private func countLabel(_ value: Int?) -> String {
        guard let value else { return "Unavailable" }
        return value.formatted()
    }
}

private struct SubscriptionFeedbackMessage: Identifiable, Equatable {
    let id = UUID()
    let tone: PatchworkInlineStatusBanner.Tone
    let text: String
}

struct SubscriptionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(RevenueCatManager.self) private var revenueCatManager
    @Environment(\.openURL) private var openURL

    @State private var isUpdating = false
    @State private var feedbackMessage: SubscriptionFeedbackMessage?

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brandBright)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PatchworkSectionIntro(
                        eyebrow: "Billing",
                        title: "Subscriptions",
                        message: "Manage App Store renewals, restores, and tasker access from one billing screen."
                    )

                    if let feedbackMessage {
                        PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                            .accessibilityIdentifier("Subscription.statusBanner")
                    }

                    if let profile = appState.taskerProfile {
                        currentPlanCard(profile)
                        plansOrManagementCard(profile)

                        if profile.hasActiveSubscription == true,
                           profile.subscriptionStatus == "cancel_at_period_end" {
                            cancellationCard(profile)
                        }
                    } else {
                        PatchworkSurfaceCard {
                            VStack(spacing: 16) {
                                Circle()
                                    .fill(PatchworkTheme.brandSoft)
                                    .frame(width: 76, height: 76)
                                    .overlay {
                                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(PatchworkTheme.brand)
                                    }

                                Text("Finish Tasker Setup First")
                                    .font(.patchworkCardTitle)
                                    .foregroundStyle(PatchworkTheme.textPrimary)

                                Text("Subscriptions only apply after your tasker profile is complete.")
                                    .font(.patchworkBody)
                                    .foregroundStyle(PatchworkTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Subscriptions")
        .task {
            await revenueCatManager.refresh(appState: appState, client: sessionStore.client)
            syncRevenueCatFeedback()
        }
        .onChange(of: revenueCatManager.lastError) { _, newValue in
            guard let newValue, !newValue.isEmpty else { return }
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: newValue)
        }
        .onChange(of: revenueCatManager.hasUnresolvedExpiryGap) { _, hasGap in
            guard hasGap else { return }
            feedbackMessage = SubscriptionFeedbackMessage(
                tone: .warning,
                text: "The App Store and Patchwork still need to finish one subscription reconciliation step."
            )
        }
    }

    private func currentPlanCard(_ profile: TaskerProfileSelf) -> some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(planTitle(for: profile))
                            .font(.patchworkCardTitle)
                            .foregroundStyle(PatchworkTheme.textPrimary)
                        Text(planDescription(for: profile))
                            .font(.patchworkBody)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Text(profile.subscriptionStatus == "active" ? "Active" : profile.subscriptionStatus == "cancel_at_period_end" ? "Ending soon" : "Inactive")
                        .font(.patchworkCaption)
                        .foregroundStyle(subscriptionStatusColor(profile))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(subscriptionStatusColor(profile).opacity(0.12), in: Capsule())
                }

                if let endsAt = profile.subscriptionEndsAt,
                   profile.subscriptionStatus == "cancel_at_period_end" {
                    LabeledContent("Term ends", value: formattedDate(endsAt))
                        .font(.patchworkCaption)
                }

                if revenueCatManager.isLoading {
                    ProgressView("Refreshing App Store status...")
                        .font(.patchworkCaption)
                }
            }
        }
    }

    @ViewBuilder
    private func plansOrManagementCard(_ profile: TaskerProfileSelf) -> some View {
        let hasRenewableAccess = revenueCatManager.storeState.activePlan?.isRenewable ?? (profile.subscriptionAccessType == "weekly")

        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(profile.hasActiveSubscription == true ? "Access Management" : "Access Options")
                    .font(.patchworkCardTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)

                if profile.hasActiveSubscription == true {
                    if hasRenewableAccess, let managementURL = revenueCatManager.managementURL {
                        Button("Manage subscription in App Store") {
                            openURL(managementURL)
                        }
                        .buttonStyle(PatchworkSecondaryButtonStyle())
                        .accessibilityIdentifier("Subscription.manageButton")
                    } else if hasRenewableAccess {
                        Text("Open this screen after the App Store has loaded your subscription details on this device to manage renewals.")
                            .font(.patchworkBody)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    } else {
                        Text("Lifetime access is a one-time purchase. There is nothing to renew or cancel in the App Store.")
                            .font(.patchworkBody)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }

                    Button("Restore purchases") {
                        Task { await restorePurchases() }
                    }
                    .buttonStyle(PatchworkSecondaryButtonStyle())
                    .disabled(isUpdating || revenueCatManager.isLoading)
                    .accessibilityIdentifier("Subscription.restoreButton")
                } else {
                    if revenueCatManager.availablePackages.isEmpty {
                        Text("Subscription options are unavailable until RevenueCat loads the current App Store offering.")
                            .font(.patchworkBody)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    } else {
                        ForEach(revenueCatManager.availablePackages) { package in
                            Button {
                                Task { await purchase(package.plan) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(package.title)
                                            .font(.patchworkBodyStrong)
                                            .foregroundStyle(PatchworkTheme.textPrimary)
                                        Text(package.subtitle)
                                            .font(.patchworkCaption)
                                            .foregroundStyle(PatchworkTheme.textSecondary)
                                        Text(package.priceLabel)
                                            .font(.patchworkCaption)
                                            .foregroundStyle(PatchworkTheme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right.circle.fill")
                                        .foregroundStyle(PatchworkTheme.brand)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(PatchworkTheme.stroke, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isUpdating || revenueCatManager.isPurchasing)
                            .accessibilityIdentifier(package.plan.purchaseAccessibilityIdentifier)
                        }
                    }

                    Button("Restore purchases") {
                        Task { await restorePurchases() }
                    }
                    .buttonStyle(PatchworkSecondaryButtonStyle())
                    .disabled(isUpdating || revenueCatManager.isLoading)
                    .accessibilityIdentifier("Subscription.restoreButton")
                }
            }
        }
    }

    private func cancellationCard(_ profile: TaskerProfileSelf) -> some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cancellation")
                    .font(.patchworkCardTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                Text(profile.subscriptionEndsAt.map(formattedDate) ?? "Cancellation scheduled for the end of the current term.")
                    .font(.patchworkBody)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                    .accessibilityIdentifier("Subscription.cancellationScheduledText")
            }
        }
    }

    private func purchase(_ plan: SubscriptionPlanChoice) async {
        isUpdating = true
        defer { isUpdating = false }
        await revenueCatManager.purchase(plan, appState: appState, client: sessionStore.client)
        syncRevenueCatFeedback(successText: "Subscription updated from the App Store.")
    }

    private func restorePurchases() async {
        isUpdating = true
        defer { isUpdating = false }
        await revenueCatManager.restorePurchases(appState: appState, client: sessionStore.client)
        syncRevenueCatFeedback(successText: "App Store purchases restored.")
    }

    private func syncRevenueCatFeedback(successText: String? = nil) {
        if let error = revenueCatManager.lastError, !error.isEmpty {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error)
            return
        }

        if revenueCatManager.hasUnresolvedExpiryGap {
            feedbackMessage = SubscriptionFeedbackMessage(
                tone: .warning,
                text: "The App Store and Patchwork still need to finish one subscription reconciliation step."
            )
            return
        }

        if let successText {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .success, text: successText)
        }
    }

    private func planTitle(for profile: TaskerProfileSelf) -> String {
        switch profile.subscriptionPlan {
        case "tasker":
            switch profile.subscriptionAccessType {
            case "lifetime":
                return "Lifetime access"
            case "weekly":
                return "Weekly access"
            default:
                return "Tasker access"
            }
        case "premium":
            return "Premium plan"
        case "basic":
            return "Basic plan"
        default:
            return profile.subscriptionStatus == "expired" ? "Subscription expired" : "No active plan"
        }
    }

    private func planDescription(for profile: TaskerProfileSelf) -> String {
        switch profile.subscriptionStatus ?? "inactive" {
        case "active":
            if profile.subscriptionAccessType == "lifetime" {
                return "Lifetime access is active. Your profile is discoverable and Ghost Mode can be toggled at any time."
            }
            return "Your profile is discoverable and Ghost Mode can be toggled at any time."
        case "cancel_at_period_end":
            if let endsAt = profile.subscriptionEndsAt {
                return "Cancellation is scheduled for \(formattedDate(endsAt)). Ghost Mode turns back on automatically then."
            }
            return "Cancellation is scheduled for the end of the current term."
        case "expired":
            return "Your paid plan has ended. Ghost Mode is back on until you activate a new plan."
        default:
            return "Ghost Mode stays on until you activate a paid plan."
        }
    }

    private func formattedDate(_ millis: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        return date.formatted(.dateTime.month(.wide).day().year())
    }

    private func subscriptionStatusColor(_ profile: TaskerProfileSelf) -> Color {
        switch profile.subscriptionStatus ?? "inactive" {
        case "active":
            return PatchworkTheme.brand
        case "cancel_at_period_end":
            return PatchworkTheme.warning
        default:
            return PatchworkTheme.textSecondary
        }
    }
}

private struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brandBright)

            VStack(spacing: 18) {
                PatchworkSurfaceCard {
                    VStack(spacing: 18) {
                        Circle()
                            .fill(PatchworkTheme.brandSoft)
                            .frame(width: 84, height: 84)
                            .overlay {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundStyle(PatchworkTheme.brand)
                            }

                        PatchworkSectionIntro(
                            eyebrow: "Premium",
                            title: "Upgrade to Premium",
                            message: "Premium gives you a searchable PIN and keeps the same Ghost Mode controls as Basic while your plan stays active."
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            premiumBullet("Searchable premium PIN for direct referrals")
                            premiumBullet("The same visibility controls with a stronger brand signal")
                            premiumBullet("A cleaner upgrade path for repeat clients")
                        }

                        Button("Close") { dismiss() }
                            .buttonStyle(PatchworkPrimaryButtonStyle())
                            .accessibilityIdentifier("PremiumUpgradeView.closeButton")
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func premiumBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PatchworkTheme.success)
            Text(text)
                .font(.patchworkBody)
                .foregroundStyle(PatchworkTheme.textPrimary)
        }
    }
}

private struct HelpView: View {
    private let faqs: [(question: String, category: String)] = [
        ("How accurate is location tracking?", "Location"),
        ("What if no Taskers are available?", "Search"),
        ("How do I report a safety concern?", "Safety"),
        ("Can Taskers pay for better placement?", "Reviews"),
        ("How are rankings determined?", "Reviews"),
        ("What if I need to cancel a job?", "Jobs"),
    ]

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.accent)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PatchworkSectionIntro(
                        eyebrow: "Support",
                        title: "Help",
                        message: "Answers, support contacts, and the ranking promise that keeps discovery trustworthy."
                    )

                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Frequently asked questions")
                                .font(.patchworkCardTitle)
                                .foregroundStyle(PatchworkTheme.textPrimary)

                            ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(faq.question)
                                            .font(.patchworkBodyStrong)
                                            .foregroundStyle(PatchworkTheme.textPrimary)
                                        Text(faq.category)
                                            .font(.patchworkCaption)
                                            .foregroundStyle(PatchworkTheme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(PatchworkTheme.textTertiary)
                                }
                                .padding(.vertical, 4)
                                .accessibilityIdentifier("Help.faq.\(index)")
                            }
                        }
                    }

                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Support")
                                .font(.patchworkCardTitle)
                                .foregroundStyle(PatchworkTheme.textPrimary)
                            helpDetailRow("Email", value: "support@patchwork.app")
                                .textSelection(.enabled)
                                .accessibilityIdentifier("Help.emailSupport")
                            helpDetailRow("Phone", value: "1-800-PATCH-WK")
                                .accessibilityIdentifier("Help.phoneSupport")
                            Text("Mon-Fri, 9 AM - 5 PM ET")
                                .font(.patchworkCaption)
                                .foregroundStyle(PatchworkTheme.textSecondary)
                        }
                    }

                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ranking promise")
                                .font(.patchworkCardTitle)
                                .foregroundStyle(PatchworkTheme.textPrimary)
                            Text("Patchwork never accepts payment for better placement. Rankings are based solely on:")
                                .font(.patchworkBody)
                                .foregroundStyle(PatchworkTheme.textSecondary)
                            premiumBullet("Verified client reviews and ratings")
                            premiumBullet("Proximity to your location")
                            premiumBullet("Recent activity and response time")
                            premiumBullet("Completion rate and reliability")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Help")
        .accessibilityIdentifier("Help.list")
    }

    private func helpDetailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.textPrimary)
        }
    }

    private func premiumBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PatchworkTheme.success)
            Text(text)
                .font(.patchworkBody)
                .foregroundStyle(PatchworkTheme.textPrimary)
        }
    }
}

private struct StepHeader: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(1 ... 3, id: \.self) { value in
                Circle()
                    .fill(value <= currentStep ? Color.indigo : Color.gray.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(value <= currentStep && value < currentStep ? "\u{2713}" : "\(value)")
                            .font(.caption.bold())
                            .foregroundStyle(value <= currentStep ? .white : .secondary)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
