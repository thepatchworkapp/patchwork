import SwiftUI

struct ProfileTaskerSection: View {
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

                NavigationLink(value: MainTabProfileRoute.taskerOnboarding) {
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

    private func backendConfirmedPlans(for taskerProfile: TaskerProfileSelf) -> [SubscriptionPlanChoice] {
        guard taskerProfile.hasActiveSubscription == true else {
            return []
        }

        let rawAccessTypes = taskerProfile.subscriptionActiveAccessTypes ?? []
        let mappedAccessTypes = rawAccessTypes.compactMap { planChoice(forBackendAccessType: $0) }
        if !mappedAccessTypes.isEmpty {
            return mappedAccessTypes
        }

        if let fallbackPlan = planChoice(forBackendAccessType: taskerProfile.subscriptionAccessType) {
            return [fallbackPlan]
        }

        return []
    }

    private func backendConfirmedPlan(for taskerProfile: TaskerProfileSelf) -> SubscriptionPlanChoice? {
        let confirmedPlans = backendConfirmedPlans(for: taskerProfile)
        if confirmedPlans.contains(.lifetime) {
            return .lifetime
        }
        if confirmedPlans.contains(.subscription) {
            return .subscription
        }
        return nil
    }

    private func planChoice(forBackendAccessType accessType: String?) -> SubscriptionPlanChoice? {
        switch accessType {
        case "lifetime":
            return .lifetime
        case "subscription":
            return .subscription
        default:
            return nil
        }
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

        let confirmedPlans = backendConfirmedPlans(for: taskerProfile)
        let confirmedPlan = backendConfirmedPlan(for: taskerProfile)

        if taskerProfile.subscriptionStatus == "active" {
            if confirmedPlans.count > 1 {
                return "Tasker access active"
            }

            switch confirmedPlan {
            case .lifetime:
                return "Founders Club"
            case .subscription:
                return "Subscribed"
            default:
                return "Tasker access active"
            }
        }

        switch taskerProfile.subscriptionPlan {
        case "tasker":
            if confirmedPlans.count > 1 {
                return "Tasker access"
            }

            switch confirmedPlan {
            case .lifetime:
                return "Founders Club"
            case .subscription:
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

        let confirmedPlans = backendConfirmedPlans(for: taskerProfile)
        let confirmedPlan = backendConfirmedPlan(for: taskerProfile)
        let status = taskerProfile.subscriptionStatus ?? "inactive"

        switch status {
        case "active":
            if confirmedPlans.count > 1 {
                return "Multiple App Store billing products are active on this account. Patchwork is using the broadest access level while keeping restores and renewals available."
            }

            if confirmedPlan == .lifetime {
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
        profile.hasActiveSubscription == true || revenueCatManager.storeState.hasAccess
    }

    private func hasStoreAccessPendingBackend(for profile: TaskerProfileSelf) -> Bool {
        revenueCatManager.storeState.hasAccess && profile.hasActiveSubscription != true
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
            await appState.refreshTaskerProfile(client: sessionStore.client, surfaceErrors: false)
            feedbackMessage = nil
        } catch {
            ghostModeValue = effectiveGhostMode(for: appState.taskerProfile)
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }
}
