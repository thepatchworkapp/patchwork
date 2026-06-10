import RevenueCat
import SwiftUI

private enum TaskerBillingPlan: String, CaseIterable, Hashable {
    case basic
    case premium
    case founders

    var title: String {
        switch self {
        case .basic:
            return "Basic"
        case .premium:
            return "Premium"
        case .founders:
            return "Founders Club"
        }
    }

    var headline: String {
        switch self {
        case .basic:
            return "CA$4.99"
        case .premium:
            return "CA$47.99"
        case .founders:
            return "CA$95.99"
        }
    }

    var priceSuffix: String {
        switch self {
        case .basic:
            return "/month"
        case .premium:
            return "/year"
        case .founders:
            return "one-time"
        }
    }

    var supportingCopy: String {
        switch self {
        case .basic:
            return "Flexible monthly access.\nCancel anytime."
        case .premium:
            return "Billed yearly.\nBest for steady taskers."
        case .founders:
            return "Pay once for permanent tasker access."
        }
    }

    var buttonTitle: String {
        switch self {
        case .basic:
            return "Start Basic"
        case .premium:
            return "Start Premium"
        case .founders:
            return "Join Founders Club"
        }
    }

    var productIdentifier: String {
        switch self {
        case .basic:
            return AppConfig.revenueCatBasicMonthlyProductID
        case .premium:
            return AppConfig.revenueCatAnnualProductID
        case .founders:
            return AppConfig.revenueCatLifetimeProductID
        }
    }

    var accent: Color {
        switch self {
        case .basic:
            return PatchworkTheme.brand
        case .premium:
            return PatchworkTheme.brandBright
        case .founders:
            return PatchworkTheme.accent
        }
    }

    var softFill: Color {
        switch self {
        case .basic:
            return PatchworkTheme.brandSoft.opacity(0.72)
        case .premium:
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
    @State private var selectedPlan: TaskerBillingPlan = .basic

    private func log(_ message: String) {
        print("[TaskerBillingSheet] \(message)")
    }

    private var hasActiveAccess: Bool {
        appState.taskerProfile?.hasActiveSubscription == true || revenueCatManager.storeState.hasAccess
    }

    private var hasStoreAccessPendingBackend: Bool {
        revenueCatManager.storeState.hasAccess && appState.taskerProfile?.hasActiveSubscription != true
    }

    private var backendConfirmedPlans: [SubscriptionPlanChoice] {
        BackendSubscriptionPlanResolver.confirmedPlans(
            hasActiveSubscription: appState.taskerProfile?.hasActiveSubscription,
            activeAccessTypes: appState.taskerProfile?.subscriptionActiveAccessTypes,
            accessType: appState.taskerProfile?.subscriptionAccessType,
            tier: appState.taskerProfile?.subscriptionTier
        )
    }

    private var backendConfirmedPlan: SubscriptionPlanChoice? {
        BackendSubscriptionPlanResolver.preferredPlan(from: backendConfirmedPlans)
    }

    private var basicPackage: Package? {
        revenueCatManager.currentOffering?.availablePackages.first {
            $0.storeProduct.productIdentifier == AppConfig.revenueCatBasicMonthlyProductID
        }
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
            let contentMinHeight = proxy.size.height.isFinite ? max(proxy.size.height, 0) : 0
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
                .frame(minHeight: contentMinHeight, alignment: .top)
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
            .accessibilityLabel("Dismiss paywall")
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
            LinearGradient(
                colors: [
                    PatchworkTheme.backgroundWarm,
                    PatchworkTheme.surface.opacity(0.65),
                    PatchworkTheme.brandSoft.opacity(0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(PatchworkTheme.accent.opacity(0.16))
                .frame(width: 180, height: 180)
                .blur(radius: 18)
                .offset(x: 118, y: 34)

            Circle()
                .fill(PatchworkTheme.brand.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 22)
                .offset(x: -132, y: -18)

            Image("TaskerPaywallHero")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 220)
                .padding(.horizontal, -12)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 188, maxHeight: 210)
        .clipShape(.rect(cornerRadius: 36))
        .accessibilityHidden(true)
    }

    private var planLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            paywallPlanCard(for: .basic)
            paywallPlanCard(for: .premium)
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
        let price = priceDisplay(for: plan)
        return TaskerPaywallOptionCard(
            title: plan.title,
            priceAmount: price.amount,
            priceSuffix: price.suffix,
            detail: plan.supportingCopy,
            accent: plan.accent,
            badgeText: plan == .founders ? "Best Value" : nil,
            isSelected: selectedPlan == plan,
            isDisabled: package(for: plan) == nil || isSyncingBackend || pendingPurchasePlan != nil || revenueCatManager.isLoading
        ) {
            selectedPlan = plan
        }
        .accessibilityIdentifier("Subscription.plan.\(plan.rawValue)")
    }

    private var restoreSection: some View {
        VStack(alignment: .center, spacing: 6) {
            Button("Maybe later") {
                dismiss()
            }
            .buttonStyle(PatchworkTextButtonStyle())
            .accessibilityIdentifier("Subscription.maybeLaterButton")

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
        case .basic:
            return PatchworkTheme.heroGradient
        case .premium:
            return LinearGradient(
                colors: [
                    PatchworkTheme.brand,
                    PatchworkTheme.brandBright
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
        .accessibilityElement(children: .combine)
    }

    private var currentAccessTitle: String {
        if hasStoreAccessPendingBackend {
            return "Purchase detected"
        }

        if backendConfirmedPlans.count > 1 {
            return "Tasker access active"
        }

        if backendConfirmedPlan == .founders {
            return "Founders Club active"
        }

        if backendConfirmedPlan == .premium {
            return "Premium active"
        }

        if backendConfirmedPlan == .basic {
            return "Basic active"
        }

        if appState.taskerProfile?.hasActiveSubscription == true {
            return "Tasker access active"
        }

        return "Tasker access inactive"
    }

    private var currentAccessDetail: String {
        if hasStoreAccessPendingBackend {
            return "Your App Store purchase was detected. Patchwork is still finishing account sync."
        }

        if backendConfirmedPlans.count > 1 {
            return "Multiple App Store billing products are active on this account. Patchwork is using the broadest access level while keeping restores and renewals available."
        }

        if backendConfirmedPlan == .founders {
            return "You have permanent tasker access through the App Store."
        }

        if let endsAt = appState.taskerProfile?.subscriptionEndsAt,
           appState.taskerProfile?.subscriptionStatus == "cancel_at_period_end" {
            return "Your subscription stays active until \(formattedDate(endsAt))."
        }

        if backendConfirmedPlan == .premium {
            return "Your Premium yearly tasker access is active and managed through the App Store."
        }

        if backendConfirmedPlan == .basic {
            return "Your Basic monthly tasker access is active and managed through the App Store."
        }

        if appState.taskerProfile?.hasActiveSubscription == true {
            return "Your tasker access is active on this account."
        }

        return "Choose a billing option to start tasking."
    }

    private var accessBadge: some View {
        let title: String
        let foreground: Color
        let background: Color

        if hasStoreAccessPendingBackend {
            title = "Confirming"
            foreground = PatchworkTheme.brand
            background = PatchworkTheme.brand.opacity(0.14)
        } else if appState.taskerProfile?.subscriptionStatus == "cancel_at_period_end" {
            title = "Ending soon"
            foreground = PatchworkTheme.warning
            background = PatchworkTheme.warning.opacity(0.14)
        } else {
            title = "Active"
            foreground = PatchworkTheme.success
            background = PatchworkTheme.success.opacity(0.14)
        }

        return Text(title)
            .font(.patchworkCaption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(background, in: Capsule())
            .accessibilityHidden(true)
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
               revenueCatManager.storeState.hasRenewableAccess || backendConfirmedPlans.contains(where: \.isRenewable) {
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

    private func priceDisplay(for plan: TaskerBillingPlan) -> (amount: String, suffix: String) {
        guard let package = package(for: plan) else {
            return (plan.headline, plan.priceSuffix)
        }
        return (package.storeProduct.localizedPriceString, plan.priceSuffix)
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
        case .basic:
            return basicPackage
        case .premium:
            return annualPackage
        case .founders:
            return foundersPackage
        }
    }

    private func buttonIdentifier(for plan: TaskerBillingPlan) -> String {
        switch plan {
        case .basic:
            return "Subscription.basicButton"
        case .premium:
            return "Subscription.premiumButton"
        case .founders:
            return "Subscription.lifetimeButton"
        }
    }

    private func purchase(plan: TaskerBillingPlan) async {
        guard let package = package(for: plan) else {
            log("Purchase attempted for \(plan.rawValue) but package was unavailable")
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: "This billing option is not available right now.")
            return
        }

        log("Starting purchase for \(plan.rawValue) with product \(package.storeProduct.productIdentifier)")
        pendingPurchasePlan = plan
        feedbackMessage = nil
        defer { pendingPurchasePlan = nil }

        let purchased = await revenueCatManager.purchase(package: package)
        if purchased {
            log("Store purchase completed for \(plan.rawValue)")
            await handleCompletedStoreAction(successText: "Purchase confirmed in the App Store.")
        } else if let lastError = revenueCatManager.lastError, !lastError.isEmpty {
            log("Store purchase failed for \(plan.rawValue): \(lastError)")
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: "Purchase could not be completed. Please try again.")
        }
    }

    private func restorePurchases() async {
        log("Starting restore purchases flow")
        isSyncingBackend = true
        feedbackMessage = nil
        defer { isSyncingBackend = false }

        await revenueCatManager.restorePurchases()
        await syncBackendAfterStoreChange(successText: "Purchases restored from the App Store.")
    }

    private func handleCompletedStoreAction(successText: String) async {
        log("Refreshing store state after completed store action")
        isSyncingBackend = true
        feedbackMessage = nil
        defer { isSyncingBackend = false }

        await revenueCatManager.refresh()
        await syncBackendAfterStoreChange(successText: successText)
    }

    private func syncBackendAfterStoreChange(successText: String) async {
        syncManagerFeedback()

        guard revenueCatManager.storeState.hasAccess else {
            log("No active store plan after store action; skipping backend sync")
            return
        }

        log("Syncing backend after store action with active plans \(revenueCatManager.storeState.activePlans.map(\.rawValue).joined(separator: ","))")
        feedbackMessage = SubscriptionFeedbackMessage(tone: .success, text: successText)

        for _ in 0 ..< 6 {
            await reconcileRevenueCatWithBackend()
            await appState.refreshTaskerProfile(client: sessionStore.client, surfaceErrors: false)

            if appState.taskerProfile?.hasActiveSubscription == true {
                log("Backend sync confirmed active tasker subscription")
                dismiss()
                return
            }

            try? await Task.sleep(for: .seconds(1))
        }

        log("Backend sync did not confirm access after retry window")
        feedbackMessage = SubscriptionFeedbackMessage(
            tone: .warning,
            text: "Your App Store purchase is complete. Patchwork is still confirming tasker access."
        )
    }

    private func reconcileRevenueCatWithBackend() async {
        do {
            let reconciledProfile: TaskerProfileSelf? = try await sessionStore.client.action(
                "taskers:reconcileRevenueCatSubscription",
                args: [:]
            )
            if let reconciledProfile {
                appState.taskerProfile = reconciledProfile
            }
        } catch {
            log("Backend reconciliation action failed: \(error.localizedDescription)")
        }
    }

    private func syncManagerFeedback(preferredMessage: String? = nil) {
        guard shouldSurfaceManagerRefreshError else {
            return
        }

        if let preferredMessage, !preferredMessage.isEmpty {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: preferredMessage)
            return
        }

        if let error = revenueCatManager.lastError, !error.isEmpty {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error)
        }
    }

    private var shouldSurfaceManagerRefreshError: Bool {
        revenueCatManager.currentOffering == nil
            && pendingPurchasePlan == nil
            && !isSyncingBackend
    }

    private func formattedDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
