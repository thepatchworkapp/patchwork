import SwiftUI

struct ProfileTaskerSection: View {
    @Environment(AppState.self) private var appState
    @Environment(RevenueCatManager.self) private var revenueCatManager
    @Environment(SessionStore.self) private var sessionStore

    let userName: String?
    let taskerProfile: TaskerProfileSelf?

    @State private var isDiscoverableValue = false
    @State private var isUpdating = false
    @State private var feedbackMessage: SubscriptionFeedbackMessage?
    @State private var isShowingSubscriptions = false
    @State private var didAutoPresentBillingPreview = false

    var body: some View {
        PatchworkSurfaceCard {
            if let taskerProfile {
                postTaskerWorkspaceCard(taskerProfile)
            } else {
                preTaskerWorkspaceCard
            }
        }
        .task(id: taskerGhostModeRefreshKey) {
            isDiscoverableValue = isDiscoverable(for: taskerProfile)
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

    private var preTaskerWorkspaceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tasker Workspace")
                        .font(.patchworkCardTitle)
                        .foregroundStyle(PatchworkTheme.textPrimary)

                    Text("Not set up")
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(PatchworkTheme.surfaceMuted, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(PatchworkTheme.stroke, lineWidth: 1)
                        )
                }

                Spacer(minLength: 12)

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    PatchworkTheme.brandSoft,
                                    PatchworkTheme.brandSoft.opacity(0.62)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 74, height: 62)

                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: PatchworkTheme.brand.opacity(0.18), radius: 8, y: 4)
                }
                .accessibilityHidden(true)
            }

            NavigationLink(value: MainTabProfileRoute.taskerOnboarding) {
                HStack(spacing: 10) {
                    Text("Become a Tasker")
                    Spacer(minLength: 12)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .font(.patchworkBodyStrong)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PatchworkPrimaryButtonStyle())
            .accessibilityIdentifier("Profile.taskerOnboardingLink")
        }
        .accessibilityElement(children: .contain)
    }

    private func postTaskerWorkspaceCard(_ profile: TaskerProfileSelf) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tasker Workspace")
                .font(.patchworkCardTitle)
                .foregroundStyle(PatchworkTheme.textPrimary)

            VStack(spacing: 0) {
                planRow(for: profile)

                Divider()
                    .padding(.leading, 66)

                discoverabilityRow(for: profile)

                Divider()
                    .padding(.leading, 66)

                NavigationLink(value: MainTabProfileRoute.taskerOnboarding) {
                    taskerWorkspaceRowContent(
                        title: "Manage Profile",
                        systemImage: "person",
                        trailing: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(PatchworkTheme.textTertiary)
                                .accessibilityHidden(true)
                        }
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("Profile.taskerOnboardingLink")
            }

            if let feedbackMessage, feedbackMessage.tone == .error {
                PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                    .accessibilityIdentifier("Profile.ghostModeBanner")
            }
        }
    }

    private func planRow(for profile: TaskerProfileSelf) -> some View {
        Button {
            isShowingSubscriptions = true
        } label: {
            taskerWorkspaceRowContent(
                title: "Plan",
                systemImage: "briefcase",
                trailing: {
                    statusChip(
                        title: planChipTitle(for: profile),
                        foreground: planChipForeground(for: profile),
                        background: planChipBackground(for: profile)
                    )
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Profile.visibilitySubscriptionLink")
    }

    private func discoverabilityRow(for profile: TaskerProfileSelf) -> some View {
        taskerWorkspaceRowContent(
            title: "Discoverability",
            systemImage: "eye",
            trailing: {
                Toggle("", isOn: discoverabilityBinding(for: profile))
                    .labelsHidden()
                    .disabled(isUpdating || !canToggleGhostMode(for: profile))
                    .tint(PatchworkTheme.brand)
                    .accessibilityLabel("Discoverability")
                    .accessibilityValue(isDiscoverableValue ? "On" : "Off")
            }
        )
        .accessibilityIdentifier("Profile.discoverabilityRow")
    }

    private func taskerWorkspaceRowContent<Trailing: View>(
        title: String,
        systemImage: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PatchworkTheme.brand)
                .frame(width: 40, height: 40)
                .background(PatchworkTheme.brandSoft.opacity(0.86), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .accessibilityHidden(true)

            Text(title)
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.textPrimary)

            Spacer(minLength: 12)

            trailing()
        }
        .frame(height: 56)
        .contentShape(Rectangle())
    }

    private func statusChip(title: String, foreground: Color, background: Color) -> some View {
        Text(title)
            .font(.patchworkCaption.weight(.semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(background, in: Capsule())
    }

    private func discoverabilityBinding(for profile: TaskerProfileSelf) -> Binding<Bool> {
        Binding(
            get: { isDiscoverableValue },
            set: { newValue in
                guard canToggleGhostMode(for: profile), !isUpdating else {
                    isDiscoverableValue = isDiscoverable(for: profile)
                    return
                }

                isDiscoverableValue = newValue
                Task { await setGhostMode(!newValue) }
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

    private func isDiscoverable(for profile: TaskerProfileSelf?) -> Bool {
        !effectiveGhostMode(for: profile)
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

    private func backendConfirmedPlans(for taskerProfile: TaskerProfileSelf) -> [SubscriptionPlanChoice] {
        BackendSubscriptionPlanResolver.confirmedPlans(
            hasActiveSubscription: taskerProfile.hasActiveSubscription,
            activeAccessTypes: taskerProfile.subscriptionActiveAccessTypes,
            accessType: taskerProfile.subscriptionAccessType,
            tier: taskerProfile.subscriptionTier
        )
    }

    private func backendConfirmedPlan(for taskerProfile: TaskerProfileSelf) -> SubscriptionPlanChoice? {
        BackendSubscriptionPlanResolver.preferredPlan(from: backendConfirmedPlans(for: taskerProfile))
    }

    private func planChipTitle(for taskerProfile: TaskerProfileSelf) -> String {
        if hasStoreAccessPendingBackend(for: taskerProfile) {
            return "Confirming"
        }

        let confirmedPlans = backendConfirmedPlans(for: taskerProfile)
        if confirmedPlans.count > 1 {
            return "Multiple"
        }

        switch taskerProfile.subscriptionStatus ?? "inactive" {
        case "active":
            switch backendConfirmedPlan(for: taskerProfile) {
            case .founders:
                return SubscriptionPlanChoice.founders.title
            case .premium:
                return "Premium"
            case .basic:
                return "Basic"
            default:
                return "Active"
            }
        case "cancel_at_period_end":
            return "Ending soon"
        case "expired":
            return "Expired"
        default:
            return "Click to Activate"
        }
    }

    private func planChipForeground(for taskerProfile: TaskerProfileSelf) -> Color {
        switch taskerProfile.subscriptionStatus ?? "inactive" {
        case "active":
            return PatchworkTheme.brand
        case "cancel_at_period_end":
            return PatchworkTheme.warning
        case "expired":
            return PatchworkTheme.textSecondary
        default:
            return hasStoreAccessPendingBackend(for: taskerProfile) ? PatchworkTheme.brand : PatchworkTheme.textSecondary
        }
    }

    private func planChipBackground(for taskerProfile: TaskerProfileSelf) -> Color {
        switch taskerProfile.subscriptionStatus ?? "inactive" {
        case "active":
            return PatchworkTheme.brandSoft.opacity(0.88)
        case "cancel_at_period_end":
            return PatchworkTheme.warning.opacity(0.14)
        case "expired":
            return PatchworkTheme.surfaceMuted
        default:
            return hasStoreAccessPendingBackend(for: taskerProfile) ? PatchworkTheme.brand.opacity(0.12) : PatchworkTheme.surfaceMuted
        }
    }

    private func effectiveHasActiveAccess(for profile: TaskerProfileSelf) -> Bool {
        profile.hasActiveSubscription == true || revenueCatManager.storeState.hasAccess
    }

    private func hasStoreAccessPendingBackend(for profile: TaskerProfileSelf) -> Bool {
        revenueCatManager.storeState.hasAccess && profile.hasActiveSubscription != true
    }

    private func setGhostMode(_ enabled: Bool) async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            let updatedProfile = try await sessionStore.client.mutation("taskers:setGhostMode", args: ["ghostMode": enabled]) as TaskerProfileSelf
            appState.taskerProfile = updatedProfile
            isDiscoverableValue = isDiscoverable(for: updatedProfile)
            await appState.refreshTaskerProfile(client: sessionStore.client, surfaceErrors: false)
            feedbackMessage = nil
        } catch {
            isDiscoverableValue = isDiscoverable(for: appState.taskerProfile)
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }
}
