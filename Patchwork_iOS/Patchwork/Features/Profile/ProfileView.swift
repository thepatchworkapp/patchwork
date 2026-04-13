import SafariServices
import SwiftUI

private enum ProfileSidebarDestination: String, Identifiable {
    case favourites

    var id: String { rawValue }
}

struct ProfileView: View {
    private enum MainLayout {
        static let horizontalGutter: CGFloat = 20
        static let topRhythm: CGFloat = 10
        static let bottomPadding: CGFloat = 16
    }

    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    @State private var isSidebarPresented = false
    @State private var activeDestination: ProfileSidebarDestination?

    let onSignOut: () async -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            PatchworkBackdrop(tint: PatchworkTheme.brand)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ProfileAccountSection(
                        user: appState.currentUser,
                        taskerProfile: appState.taskerProfile
                    ) {
                        withAnimation(.snappy(duration: 0.24)) {
                            isSidebarPresented = true
                        }
                    }

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
                    .accessibilityHidden(true)
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

private struct ProfileAccountSection: View {
    let user: CurrentUser?
    let taskerProfile: TaskerProfileSelf?
    let onOpenMenu: () -> Void

    var body: some View {
        PatchworkSurfaceCard {
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    ProfileMenuButton(action: onOpenMenu)
                }

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
                        roleBadge(
                            "Seeker",
                            foreground: PatchworkTheme.success,
                            background: PatchworkTheme.success.opacity(0.14),
                            stroke: PatchworkTheme.success.opacity(0.4),
                            accessibilityIdentifier: "Profile.seekerPill"
                        )
                    }
                    taskerRoleBadge
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
        .accessibilityHidden(true)
    }

    private func roleBadge(
        _ title: String,
        foreground: Color,
        background: Color,
        stroke: Color,
        accessibilityIdentifier: String
    ) -> some View {
        Text(title)
            .font(.patchworkBodyStrong)
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(background, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(stroke, lineWidth: 1)
            )
            .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var taskerRoleBadge: some View {
        let style: (foreground: Color, background: Color, stroke: Color) = {
            guard let taskerProfile else {
                return (
                    PatchworkTheme.textSecondary,
                    PatchworkTheme.surfaceMuted,
                    PatchworkTheme.stroke
                )
            }

            guard taskerProfile.hasActiveSubscription == true else {
                return (
                    PatchworkTheme.textSecondary,
                    PatchworkTheme.surfaceMuted,
                    PatchworkTheme.stroke
                )
            }

            if taskerProfile.ghostMode == true {
                return (
                    PatchworkTheme.brand,
                    PatchworkTheme.brandSoft.opacity(0.95),
                    PatchworkTheme.strokeStrong
                )
            }

            return (
                PatchworkTheme.success,
                PatchworkTheme.success.opacity(0.14),
                PatchworkTheme.success.opacity(0.4)
            )
        }()

        return roleBadge(
            "Tasker",
            foreground: style.foreground,
            background: style.background,
            stroke: style.stroke,
            accessibilityIdentifier: "Profile.taskerPill"
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
        .accessibilityElement(children: .combine)
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
                        .accessibilityHidden(true)
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
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("\(title): \(value)")
        .accessibilityValue(isUnlocked ? "Unlocked" : "Locked")
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

private struct ProfileMenuButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        .accessibilityLabel("Open settings menu")
        .accessibilityIdentifier("Profile.menuButton")
    }
}

private struct ProfileTaskerSection: View {
    @Environment(AppState.self) private var appState
    @Environment(RevenueCatManager.self) private var revenueCatManager
    @Environment(SessionStore.self) private var sessionStore

    let userName: String?
    let taskerProfile: TaskerProfileSelf?

    @State private var ghostModeValue = false
    @State private var isUpdating = false
    @State private var feedbackMessage: SubscriptionFeedbackMessage?
    @State private var isShowingSubscriptions = false
    @State private var didAutoPresentBillingPreview = false

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

                NavigationLink {
                    TaskerOnboardingView()
                } label: {
                    ProfileLinkRowLabel(title: taskerProfile == nil ? "Complete Tasker Setup" : "Manage Tasker Profile")
                }
                .buttonStyle(.plain)
                .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Profile.taskerOnboardingLink"))

                if let taskerProfile {
                    let billingTitle = effectiveHasActiveAccess(for: taskerProfile)
                        ? "Billing & access"
                        : "Unlock tasker mode"

                    Button {
                        isShowingSubscriptions = true
                    } label: {
                        ProfileLinkRowLabel(title: billingTitle)
                    }
                    .buttonStyle(.plain)
                    .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Profile.visibilitySubscriptionLink"))
                }
            }
        }
        .task(id: taskerGhostModeRefreshKey) {
            ghostModeValue = effectiveGhostMode(for: taskerProfile)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_TASKER_BILLING_PREVIEW_UNPAID"),
                  !didAutoPresentBillingPreview else {
                return
            }

            didAutoPresentBillingPreview = true
            isShowingSubscriptions = true
        }
        .sheet(isPresented: $isShowingSubscriptions) {
            TaskerBillingSheet()
                .patchworkSheetChrome(detents: [.large])
        }
    }

    private func discoverabilityControls(for profile: TaskerProfileSelf) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ghost Mode")
                        .font(.patchworkBodyStrong)
                        .foregroundStyle(PatchworkTheme.textPrimary)

                    Text(ghostModeDescription(for: profile))
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: ghostModeBinding(for: profile))
                    .labelsHidden()
                    .disabled(isUpdating || !canToggleGhostMode(for: profile))
                    .tint(PatchworkTheme.brand)
                    .accessibilityLabel("Ghost Mode")
                    .accessibilityValue(ghostModeValue ? "On" : "Off")
            }

            if let feedbackMessage, feedbackMessage.tone == .error {
                PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                    .accessibilityIdentifier("Profile.ghostModeBanner")
            }

            if !canToggleGhostMode(for: profile) {
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
        .accessibilityElement(children: .combine)
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

            if shouldShowStatusBadge(for: profile) {
                statusBadge(for: profile)
            }
        }
        .padding(14)
        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func ghostModeBinding(for profile: TaskerProfileSelf) -> Binding<Bool> {
        Binding(
            get: { effectiveGhostMode(for: profile) },
            set: { newValue in
                guard canToggleGhostMode(for: profile), !isUpdating else {
                    ghostModeValue = effectiveGhostMode(for: profile)
                    return
                }

                ghostModeValue = newValue
                Task { await setGhostMode(newValue) }
            }
        )
    }

    private var taskerGhostModeRefreshKey: String {
        let rawGhostMode = taskerProfile?.ghostMode == true ? "on" : "off"
        let hasActiveSubscription = taskerProfile?.hasActiveSubscription == true ? "active" : "inactive"
        let subscriptionStatus = taskerProfile?.subscriptionStatus ?? "none"
        return "\(rawGhostMode)|\(hasActiveSubscription)|\(subscriptionStatus)"
    }

    private func canToggleGhostMode(for profile: TaskerProfileSelf) -> Bool {
        profile.hasActiveSubscription == true
    }

    private func effectiveGhostMode(for profile: TaskerProfileSelf?) -> Bool {
        guard let profile else {
            return true
        }

        if canToggleGhostMode(for: profile) {
            return profile.ghostMode
        }

        return true
    }

    private func ghostModeDescription(for profile: TaskerProfileSelf) -> String {
        if !canToggleGhostMode(for: profile) {
            return "Your profile stays hidden from search until you activate paid tasker access."
        }

        return ghostModeValue
            ? "Your profile is hidden from search."
            : "Your profile will appear in search."
    }

    private func statusBadge(for taskerProfile: TaskerProfileSelf) -> some View {
        if hasStoreAccessPendingBackend(for: taskerProfile) {
            return Text("Confirming")
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.brand)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PatchworkTheme.brand.opacity(0.12), in: Capsule())
        }

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

    private func shouldShowStatusBadge(for taskerProfile: TaskerProfileSelf) -> Bool {
        hasStoreAccessPendingBackend(for: taskerProfile) || taskerProfile.subscriptionStatus != "active"
    }

    private func planTitle(for taskerProfile: TaskerProfileSelf) -> String {
        if hasStoreAccessPendingBackend(for: taskerProfile) {
            return "Purchase detected"
        }

        if taskerProfile.subscriptionStatus == "active" {
            switch taskerProfile.subscriptionAccessType {
            case "lifetime":
                return "Founders Club"
            case "subscription":
                return "Subscribed"
            default:
                return "Tasker access active"
            }
        }

        switch taskerProfile.subscriptionPlan {
        case "tasker":
            switch taskerProfile.subscriptionAccessType {
            case "lifetime":
                return "Founders Club"
            case "subscription":
                return "Subscribe"
            default:
                return "Tasker access"
            }
        default:
            return taskerProfile.subscriptionStatus == "expired" ? "Subscription expired" : "No active plan"
        }
    }

    private func planTitleColor(for taskerProfile: TaskerProfileSelf) -> Color {
        if hasStoreAccessPendingBackend(for: taskerProfile) {
            return PatchworkTheme.brand
        }

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
        if hasStoreAccessPendingBackend(for: taskerProfile) {
            return "Your App Store purchase was detected. Patchwork is still finishing account sync."
        }

        let status = taskerProfile.subscriptionStatus ?? "inactive"

        switch status {
        case "active":
            if taskerProfile.subscriptionAccessType == "lifetime" {
                return "Founders Club is active on this account."
            }
            return "Your subscription is active on this account."
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

    private func effectiveHasActiveAccess(for profile: TaskerProfileSelf) -> Bool {
        profile.hasActiveSubscription == true || revenueCatManager.storeState.activePlan != nil
    }

    private func hasStoreAccessPendingBackend(for profile: TaskerProfileSelf) -> Bool {
        revenueCatManager.storeState.activePlan != nil && profile.hasActiveSubscription != true
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
            ghostModeValue = effectiveGhostMode(for: updatedProfile)
            await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)
            feedbackMessage = nil
        } catch {
            ghostModeValue = effectiveGhostMode(for: appState.taskerProfile)
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
                .accessibilityLabel("Close settings")
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
                        .accessibilityHidden(true)

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
                        .accessibilityHidden(true)
                }
                .padding(16)
                .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PatchworkTheme.stroke, lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Profile.sidebarFavouritesButton")
            .accessibilityLabel("Open favourites")

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
                        .accessibilityLabel("Back to settings")
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
                                .accessibilityHidden(true)
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
        .accessibilityElement(children: .combine)
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
        .accessibilityHidden(true)
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
                .accessibilityHidden(true)
            Text(text)
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textPrimary)
        }
    }
}

private struct ProfileSupportSection: View {
    let onSignOut: () async -> Void

    var body: some View {
        PatchworkSurfaceCard {
            VStack(spacing: 14) {
                NavigationLink {
                    HelpView()
                } label: {
                    ProfileLinkRowLabel(title: "Help & Support")
                }
                .buttonStyle(.plain)
                .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Profile.helpLink"))

                Button("Sign Out", role: .destructive) {
                    Task {
                        await onSignOut()
                    }
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
            .frame(height: 48)
            .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PatchworkTheme.stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct ProfileLinkRowLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PatchworkTheme.textTertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
        .sheet(isPresented: $isShowingSubscriptions) {
            TaskerBillingSheet()
                .patchworkSheetChrome(detents: [.large])
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
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    PatchworkKeyboard.dismiss()
                }

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

                                Text("To become discoverable to Seekers in your area, unlock tasker mode.")
                                    .font(.patchworkBody)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(PatchworkTheme.textSecondary)

                                Button("Unlock tasker mode") {
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
            .scrollDismissesKeyboard(.interactively)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .scrollIndicators(.hidden)
        }
        .patchworkKeyboardDismissToolbar()
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
                                .accessibilityHidden(true)
                        }
                        .padding(16)
                        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(PatchworkTheme.stroke, lineWidth: 1)
                        )
                        .accessibilityElement(children: .combine)
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
                        title: "Review & Accept",
                        message: "Confirm the essentials, then finish creating your tasker profile."
                    )

                    onboardingSummaryRow("Display name", value: displayName)
                    onboardingSummaryRow("Rate", value: reviewRateSummary)
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
                                .accessibilityHidden(true)
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
                    .accessibilityLabel("I agree to the Tasker terms and community guidelines")
                    .accessibilityValue(acceptedTerms ? "Selected" : "Not selected")
                    .accessibilityHint("Required to complete setup")
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
        .accessibilityElement(children: .combine)
    }

    private var selectedCategoryName: String {
        guard let selectedCategoryId,
              let selectedCategory = categories.first(where: { $0.id == selectedCategoryId }) else {
            return "Choose"
        }
        return selectedCategory.name
    }

    private var reviewRateSummary: String {
        if rateType == "hourly" {
            return formattedPrice(hourlyRate, suffix: "/hr")
        }

        return formattedPrice(fixedRate, suffix: " flat")
    }

    private func formattedPrice(_ value: String, suffix: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = Double(trimmed) ?? 0
        return "\(amount.formatted(.currency(code: "USD")))\(suffix)"
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
                            Text("My Categories")
                                .font(.patchworkCardTitle)
                                .foregroundStyle(PatchworkTheme.textPrimary)

                            Button {
                                addCategorySheet = true
                            } label: {
                                ProfileLinkRowLabel(title: "Add Category")
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
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
                                            .accessibilityHidden(true)
                                    }
                                    .padding(16)
                                    .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(PatchworkTheme.stroke, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("TaskerProfile.category.\(category.categoryId)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $addCategorySheet) {
            NavigationStack {
                AddCategorySheet(
                    categories: categories,
                    existingCategoryIDs: existingCategoryIDs,
                    onAdd: onAddCategory
                )
            }
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
                NavigationStack {
                    EditableTaskerCategorySheet(
                        category: category,
                        onSave: onUpdateCategory,
                        onRemove: {
                            try await onRemoveCategory(category.categoryId)
                        }
                    )
                }
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

    private let maxBioLength = 500

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

                radiusControl
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
            .onChange(of: bio) { _, newValue in
                if newValue.count > maxBioLength {
                    bio = String(newValue.prefix(maxBioLength))
                }
            }
            .accessibilityIdentifier("\(accessibilityPrefix).bioField")

        if let focusedField {
            VStack(alignment: .leading, spacing: 8) {
                field
                    .focused(focusedField, equals: .bio)
                    .simultaneousGesture(TapGesture().onEnded {
                        focusedField.wrappedValue = .bio
                    })
                bioCount
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                field
                bioCount
            }
        }
    }

    @ViewBuilder
    private var hourlyRateField: some View {
        let field = priceField(
            placeholder: "Hourly rate",
            text: $hourlyRate,
            accessibilityIdentifier: "\(accessibilityPrefix).hourlyRateField"
        )

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
        let field = priceField(
            placeholder: "Fixed rate",
            text: $fixedRate,
            accessibilityIdentifier: "\(accessibilityPrefix).fixedRateField"
        )

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

    private var bioCount: some View {
        Text("\(bio.count)/\(maxBioLength)")
            .font(.patchworkCaption)
            .foregroundStyle(bio.count >= maxBioLength ? PatchworkTheme.warning : PatchworkTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityIdentifier("\(accessibilityPrefix).bioCount")
    }

    private var radiusControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Service radius")
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                Spacer()
                Text("\(serviceRadius) km")
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.brand)
                    .accessibilityIdentifier("\(accessibilityPrefix).radiusValue")
            }

            HStack(spacing: 12) {
                radiusStepButton(
                    systemName: "minus",
                    action: { serviceRadius = max(1, serviceRadius - 1) },
                    accessibilityIdentifier: "\(accessibilityPrefix).radiusDecrementButton"
                )

                Slider(
                    value: Binding(
                        get: { Double(serviceRadius) },
                        set: { serviceRadius = Int($0.rounded()) }
                    ),
                    in: 1 ... 250,
                    step: 1
                )
                .tint(PatchworkTheme.brand)
                .accessibilityLabel("Service radius")
                .accessibilityValue("\(serviceRadius) kilometers")
                .accessibilityIdentifier("\(accessibilityPrefix).radiusStepper")

                radiusStepButton(
                    systemName: "plus",
                    action: { serviceRadius = min(250, serviceRadius + 1) },
                    accessibilityIdentifier: "\(accessibilityPrefix).radiusIncrementButton"
                )
            }

            HStack {
                Text("1 km")
                Spacer()
                Text("250 km")
            }
            .font(.patchworkCaption)
            .foregroundStyle(PatchworkTheme.textSecondary)
        }
        .padding(16)
        .background(PatchworkTheme.brandSoft.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
        )
    }

    private func priceField(
        placeholder: String,
        text: Binding<String>,
        accessibilityIdentifier: String
    ) -> some View {
        HStack(spacing: 10) {
            Text("$")
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.brand)
                .accessibilityHidden(true)

            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.patchworkBody)
                .foregroundStyle(PatchworkTheme.textPrimary)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
        .padding(.horizontal, 16)
        .frame(height: PatchworkMetrics.fieldHeight)
        .background(
            PatchworkTheme.surface,
            in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }

    private func radiusStepButton(
        systemName: String,
        action: @escaping () -> Void,
        accessibilityIdentifier: String
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.bold))
                .foregroundStyle(PatchworkTheme.brand)
                .frame(width: 36, height: 36)
                .background(PatchworkTheme.surface, in: Circle())
                .overlay(Circle().stroke(PatchworkTheme.strokeStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName == "minus" ? "Decrease service radius" : "Increase service radius")
        .accessibilityIdentifier(accessibilityIdentifier)
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
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    PatchworkKeyboard.dismiss()
                }

            PatchworkBackdrop(tint: PatchworkTheme.accent)

            ScrollView {
                VStack(spacing: 18) {
                    PatchworkTopBar(title: "Add Category", onBack: { dismiss() })
                        .accessibilityIdentifier("AddCategorySheet.cancelButton")

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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
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
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .patchworkKeyboardDismissToolbar()
        .onAppear {
            resetSelectionIfNeeded()
        }
        .onChange(of: existingCategoryIDs) { _, _ in
            resetSelectionIfNeeded()
        }
    }

    private var availableCategories: [Category] {
        categories.filter { !existingCategoryIDs.contains($0.id) }
    }

    private var hasValidSelection: Bool {
        guard let selectedCategoryId else {
            return false
        }
        return availableCategories.contains(where: { $0.id == selectedCategoryId })
    }

    private var selectedCategoryName: String {
        guard let selectedCategoryId,
              let selectedCategory = availableCategories.first(where: { $0.id == selectedCategoryId }) else {
            return "Choose"
        }
        return selectedCategory.name
    }

    private var canSubmit: Bool {
        guard hasValidSelection,
              !categoryBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        if rateType == "hourly" {
            return (Double(hourlyRate) ?? 0) > 0
        }
        return (Double(fixedRate) ?? 0) > 0
    }

    private func resetSelectionIfNeeded() {
        guard let selectedCategoryId else {
            return
        }

        if !availableCategories.contains(where: { $0.id == selectedCategoryId }) {
            self.selectedCategoryId = nil
        }
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
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    PatchworkKeyboard.dismiss()
                }

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
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .patchworkKeyboardDismissToolbar()
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
        .accessibilityElement(children: .combine)
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

private struct HelpView: View {
    @State private var legalDocument: LegalDocument?

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.accent)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PatchworkSectionIntro(
                        eyebrow: "Support",
                        title: "Help",
                        message: "Review Patchwork's policies or send feedback directly from the app."
                    )

                    PatchworkSurfaceCard {
                        VStack(spacing: 14) {
                            Button {
                                legalDocument = .terms
                            } label: {
                                ProfileLinkRowLabel(title: "Terms of Service")
                            }
                            .buttonStyle(.plain)
                            .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Help.termsLink"))

                            Button {
                                legalDocument = .privacy
                            } label: {
                                ProfileLinkRowLabel(title: "Privacy Policy")
                            }
                            .buttonStyle(.plain)
                            .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Help.privacyLink"))

                            NavigationLink {
                                FeedbackView()
                            } label: {
                                ProfileLinkRowLabel(title: "Send Feedback")
                            }
                            .buttonStyle(.plain)
                            .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Help.feedbackLink"))
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
        .sheet(item: $legalDocument) { document in
            LegalDocumentView(document: document)
        }
        .accessibilityIdentifier("Help.list")
    }
}

private enum LegalDocument: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }

    var url: URL {
        switch self {
        case .privacy:
            return URL(string: "https://ddga.ltd/patchwork/privacy")!
        case .terms:
            return URL(string: "https://ddga.ltd/patchwork/terms")!
        }
    }
}

private struct LegalDocumentView: UIViewControllerRepresentable {
    let document: LegalDocument

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: document.url)
        controller.preferredControlTintColor = UIColor(PatchworkTheme.brand)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct FeedbackView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var feedbackMessage: SubscriptionFeedbackMessage?
    @State private var isSubmitting = false

    private let maxFeedbackLength = 2000

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brandBright)

            ScrollView {
                VStack(spacing: 18) {
                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 18) {
                            PatchworkSectionIntro(
                                eyebrow: "Support",
                                title: "Send Feedback",
                                message: "Share product feedback, bugs, or rough edges in your own words."
                            )

                            if let feedbackMessage {
                                PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                                    .accessibilityIdentifier("Feedback.statusBanner")
                            }

                            TextEditor(text: $message)
                                .font(.patchworkBody)
                                .foregroundStyle(PatchworkTheme.textPrimary)
                                .frame(minHeight: 160)
                                .padding(10)
                                .background(PatchworkTheme.surface, in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                                        .stroke(PatchworkTheme.stroke, lineWidth: 1)
                                )
                                .onChange(of: message) { _, newValue in
                                    if newValue.count > maxFeedbackLength {
                                        message = String(newValue.prefix(maxFeedbackLength))
                                    }
                                }
                                .accessibilityIdentifier("Feedback.messageField")

                            Text("\(message.count)/\(maxFeedbackLength)")
                                .font(.patchworkCaption)
                                .foregroundStyle(message.count >= maxFeedbackLength ? PatchworkTheme.warning : PatchworkTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .accessibilityIdentifier("Feedback.messageCount")

                            Button(isSubmitting ? "Sending..." : "Send Feedback") {
                                Task { await submitFeedback() }
                            }
                            .buttonStyle(PatchworkPrimaryButtonStyle())
                            .disabled(isSubmitting || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("Feedback.submitButton")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Feedback")
    }

    private func submitFeedback() async {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: "Enter your feedback before sending.")
            return
        }

        isSubmitting = true
        feedbackMessage = nil
        defer { isSubmitting = false }

        do {
            _ = try await sessionStore.client.mutation("feedback:submit", args: ["message": trimmedMessage]) as ConvexID
            feedbackMessage = SubscriptionFeedbackMessage(tone: .success, text: "Feedback sent. Thank you.")
            try? await Task.sleep(nanoseconds: 500_000_000)
            dismiss()
        } catch {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
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
