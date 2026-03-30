import RevenueCat
import SwiftUI

private enum TaskerBillingPlan: String, CaseIterable, Hashable {
    case subscription
    case founders

    var title: String {
        switch self {
        case .subscription:
            return "Subscribe"
        case .founders:
            return "Founders Club"
        }
    }

    var headline: String {
        switch self {
        case .subscription:
            return "$47.99"
        case .founders:
            return "$95.99"
        }
    }

    var priceSuffix: String {
        switch self {
        case .subscription:
            return "/year"
        case .founders:
            return "one-time"
        }
    }

    var supportingCopy: String {
        switch self {
        case .subscription:
            return "Billed yearly.\nOnly $3.99 per month."
        case .founders:
            return "Pay once for\npermanent tasker access."
        }
    }

    var buttonTitle: String {
        switch self {
        case .subscription:
            return "Start subscription"
        case .founders:
            return "Join Founders Club"
        }
    }

    var productIdentifier: String {
        switch self {
        case .subscription:
            return AppConfig.revenueCatAnnualProductID
        case .founders:
            return AppConfig.revenueCatLifetimeProductID
        }
    }

    var accent: Color {
        switch self {
        case .subscription:
            return PatchworkTheme.brand
        case .founders:
            return PatchworkTheme.accent
        }
    }

    var softFill: Color {
        switch self {
        case .subscription:
            return PatchworkTheme.brandSoft.opacity(0.72)
        case .founders:
            return Color.white.opacity(0.92)
        }
    }
}

struct TaskerBillingSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(RevenueCatManager.self) private var revenueCatManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var feedbackMessage: SubscriptionFeedbackMessage?
    @State private var isSyncingBackend = false
    @State private var pendingPurchasePlan: TaskerBillingPlan?
    @State private var selectedPlan: TaskerBillingPlan = .founders

    private var hasActiveAccess: Bool {
        appState.taskerProfile?.hasActiveSubscription == true || revenueCatManager.storeState.activePlan != nil
    }

    private var annualPackage: Package? {
        revenueCatManager.currentOffering?.availablePackages.first {
            $0.storeProduct.productIdentifier == AppConfig.revenueCatAnnualProductID
        }
    }

    private var foundersPackage: Package? {
        revenueCatManager.currentOffering?.availablePackages.first {
            $0.storeProduct.productIdentifier == AppConfig.revenueCatLifetimeProductID
        }
    }

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: hasActiveAccess ? PatchworkTheme.brandBright : PatchworkTheme.brand)

            if hasActiveAccess {
                activeBillingContent
            } else {
                inactiveBillingContent
            }
        }
        .task {
            await revenueCatManager.refresh()
            syncManagerFeedback()
        }
        .onChange(of: revenueCatManager.lastError) { _, newValue in
            syncManagerFeedback(preferredMessage: newValue)
        }
    }

    private var inactiveBillingContent: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    topBar
                    paywallHeading

                    if let feedbackMessage {
                        PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                            .accessibilityIdentifier("Subscription.statusBanner")
                    }

                    if revenueCatManager.isLoading && revenueCatManager.currentOffering == nil {
                        PatchworkBrandLoadingCard()
                    } else if revenueCatManager.currentOffering != nil {
                        heroArtwork
                        planLayout
                        primaryPurchaseButton
                        Spacer(minLength: 0)
                        restoreSection
                    } else {
                        missingOfferingState
                    }
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("Subscription.customPaywall")
    }

    private var activeBillingContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                topBar

                if let feedbackMessage {
                    PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                        .accessibilityIdentifier("Subscription.statusBanner")
                }

                activeSummaryCard
                activeAccessCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var topBar: some View {
        HStack {
            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PatchworkTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(PatchworkTheme.surface.opacity(0.84), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(PatchworkTheme.stroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Subscription.billingCloseButton")
        }
        .padding(.top, 4)
        .padding(.trailing, 4)
    }

    private var paywallHeading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start tasking!")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(PatchworkTheme.textPrimary)
                .accessibilityIdentifier("Subscription.billingTitle")

            Text("Go live with your Tasker profile and get discovered.")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(PatchworkTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroArtwork: some View {
        ZStack {
            Image("TaskerPaywallHero")
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96)
        .background(
            LinearGradient(
                colors: [
                    PatchworkTheme.surface,
                    PatchworkTheme.backgroundWarm,
                    PatchworkTheme.brandSoft.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(PatchworkTheme.strokeStrong.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: PatchworkTheme.brand.opacity(0.08), radius: 18, y: 9)
    }

    private var planLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            paywallPlanCard(for: .subscription)
            paywallPlanCard(for: .founders)
        }
    }

    private var primaryPurchaseButton: some View {
        Button(pendingPurchasePlan == selectedPlan ? "Working…" : selectedPlan.buttonTitle) {
            Task {
                await purchase(plan: selectedPlan)
            }
        }
        .buttonStyle(PatchworkPrimaryButtonStyle(fill: primaryButtonGradient))
        .shadow(color: selectedPlan.accent.opacity(0.16), radius: 14, y: 6)
        .disabled(package(for: selectedPlan) == nil || isSyncingBackend || pendingPurchasePlan != nil || revenueCatManager.isLoading)
        .accessibilityIdentifier(buttonIdentifier(for: selectedPlan))
    }

    private func paywallPlanCard(for plan: TaskerBillingPlan) -> some View {
        TaskerPaywallOptionCard(
            title: plan.title,
            priceAmount: plan.headline,
            priceSuffix: plan.priceSuffix,
            detail: plan.supportingCopy,
            accent: plan.accent,
            badgeText: plan == .founders ? "Best Value" : nil,
            isSelected: selectedPlan == plan,
            isDisabled: package(for: plan) == nil || isSyncingBackend || pendingPurchasePlan != nil || revenueCatManager.isLoading
        ) {
            selectedPlan = plan
        }
    }

    private var restoreSection: some View {
        VStack(alignment: .center, spacing: 6) {
            Button(isSyncingBackend ? "Restoring…" : "Restore purchases") {
                Task { await restorePurchases() }
            }
            .buttonStyle(PatchworkTextButtonStyle())
            .disabled(isSyncingBackend)
            .accessibilityIdentifier("Subscription.restoreButton")
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var primaryButtonGradient: LinearGradient {
        switch selectedPlan {
        case .subscription:
            return PatchworkTheme.heroGradient
        case .founders:
            return LinearGradient(
                colors: [
                    PatchworkTheme.brandBright,
                    PatchworkTheme.accent,
                    PatchworkTheme.brand
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var activeSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(currentAccessTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(PatchworkTheme.textPrimary)

                Spacer()

                accessBadge
            }

            Text(currentAccessDetail)
                .font(.patchworkBody)
                .foregroundStyle(PatchworkTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
        )
    }

    private var currentAccessTitle: String {
        if revenueCatManager.storeState.activePlan == .lifetime || appState.taskerProfile?.subscriptionAccessType == "lifetime" {
            return "Founders Club active"
        }
        if revenueCatManager.storeState.activePlan == .subscription || appState.taskerProfile?.subscriptionAccessType == "subscription" {
            return "Subscription active"
        }
        return "Tasker access inactive"
    }

    private var currentAccessDetail: String {
        if revenueCatManager.storeState.activePlan == .lifetime || appState.taskerProfile?.subscriptionAccessType == "lifetime" {
            return "You have permanent tasker access through the App Store."
        }

        if let endsAt = appState.taskerProfile?.subscriptionEndsAt,
           appState.taskerProfile?.subscriptionStatus == "cancel_at_period_end" {
            return "Your subscription stays active until \(formattedDate(endsAt))."
        }

        if revenueCatManager.storeState.activePlan == .subscription || appState.taskerProfile?.subscriptionAccessType == "subscription" {
            return "Your yearly tasker access is active and managed through the App Store."
        }

        return "Choose a billing option to start tasking."
    }

    private var accessBadge: some View {
        Text("Active")
            .font(.patchworkCaption)
            .foregroundStyle(PatchworkTheme.success)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(PatchworkTheme.success.opacity(0.14), in: Capsule())
    }

    private var activeAccessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Billing & restore")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(PatchworkTheme.textPrimary)

            Text("Changes, restores, and renewals are handled through the App Store.")
                .font(.patchworkBody)
                .foregroundStyle(PatchworkTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let managementURL = revenueCatManager.managementURL,
               revenueCatManager.storeState.activePlan?.isRenewable != false {
                Button("Manage subscription in App Store") {
                    openURL(managementURL)
                }
                .buttonStyle(PatchworkSecondaryButtonStyle())
                .accessibilityIdentifier("Subscription.manageButton")
            }

            Button(isSyncingBackend ? "Refreshing access…" : "Restore purchases") {
                Task { await restorePurchases() }
            }
            .buttonStyle(PatchworkSecondaryButtonStyle())
            .disabled(isSyncingBackend)
            .accessibilityIdentifier("Subscription.restoreButton")
        }
        .padding(20)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
        )
    }

    private var missingOfferingState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Billing is temporarily unavailable")
                .font(.patchworkCardTitle)
                .foregroundStyle(PatchworkTheme.textPrimary)

            Text("Patchwork could not load the required App Store offering for this device. Try again once your App Store account and RevenueCat catalog have finished syncing.")
                .font(.patchworkBody)
                .foregroundStyle(PatchworkTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(revenueCatManager.isLoading ? "Loading…" : "Try again") {
                Task {
                    await revenueCatManager.refresh()
                    syncManagerFeedback()
                }
            }
            .buttonStyle(PatchworkPrimaryButtonStyle())
            .disabled(revenueCatManager.isLoading)
            .accessibilityIdentifier("Subscription.retryButton")
        }
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
        )
    }

    private func package(for plan: TaskerBillingPlan) -> Package? {
        switch plan {
        case .subscription:
            return annualPackage
        case .founders:
            return foundersPackage
        }
    }

    private func buttonIdentifier(for plan: TaskerBillingPlan) -> String {
        switch plan {
        case .subscription:
            return "Subscription.subscriptionButton"
        case .founders:
            return "Subscription.lifetimeButton"
        }
    }

    private func purchase(plan: TaskerBillingPlan) async {
        guard let package = package(for: plan) else {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: "This billing option is not available right now.")
            return
        }

        pendingPurchasePlan = plan
        feedbackMessage = nil
        defer { pendingPurchasePlan = nil }

        let purchased = await revenueCatManager.purchase(package: package)
        if purchased {
            await handleCompletedStoreAction(successText: "Purchase confirmed in the App Store.")
        } else if let lastError = revenueCatManager.lastError, !lastError.isEmpty {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: lastError)
        }
    }

    private func restorePurchases() async {
        isSyncingBackend = true
        feedbackMessage = nil
        defer { isSyncingBackend = false }

        await revenueCatManager.restorePurchases()
        await syncBackendAfterStoreChange(successText: "Purchases restored from the App Store.")
    }

    private func handleCompletedStoreAction(successText: String) async {
        isSyncingBackend = true
        feedbackMessage = nil
        defer { isSyncingBackend = false }

        await revenueCatManager.refresh()
        await syncBackendAfterStoreChange(successText: successText)
    }

    private func syncBackendAfterStoreChange(successText: String) async {
        syncManagerFeedback()

        guard revenueCatManager.storeState.activePlan != nil else {
            return
        }

        feedbackMessage = SubscriptionFeedbackMessage(tone: .success, text: successText)

        for _ in 0 ..< 6 {
            await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)

            if appState.taskerProfile?.hasActiveSubscription == true {
                dismiss()
                return
            }

            try? await Task.sleep(for: .seconds(1))
        }

        feedbackMessage = SubscriptionFeedbackMessage(
            tone: .warning,
            text: "Your App Store purchase is complete. Patchwork is still confirming tasker access."
        )
    }

    private func syncManagerFeedback(preferredMessage: String? = nil) {
        if let preferredMessage, !preferredMessage.isEmpty {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: preferredMessage)
            return
        }

        if let error = revenueCatManager.lastError, !error.isEmpty {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error)
        }
    }

    private func formattedDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
