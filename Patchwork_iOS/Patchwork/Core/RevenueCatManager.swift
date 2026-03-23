import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class RevenueCatManager {
    private var isConfigured = false
    private var currentAppUserID: String?
    private var packagesByPlan: [SubscriptionPlanChoice: Package] = [:]

    private(set) var availablePackages: [SubscriptionPackageState] = []
    private(set) var storeState: StoreSubscriptionState = .empty
    private(set) var managementURL: URL?
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var lastError: String?
    private(set) var hasUnresolvedExpiryGap = false

    func configureIfNeeded() {
        guard !isConfigured else {
            return
        }

#if DEBUG
        Purchases.logLevel = .debug
#endif
        Purchases.configure(withAPIKey: AppConfig.revenueCatPublicAPIKey)
        isConfigured = true
    }

    func syncIdentity(
        currentUserID: String?,
        appState: AppState? = nil,
        client: ConvexHTTPClient? = nil
    ) async {
        configureIfNeeded()
        lastError = nil

        do {
            guard let currentUserID else {
                if currentAppUserID != nil {
                    _ = try await Purchases.shared.logOut()
                }
                currentAppUserID = nil
                packagesByPlan = [:]
                availablePackages = []
                storeState = .empty
                managementURL = nil
                hasUnresolvedExpiryGap = false
                return
            }

            if currentAppUserID != currentUserID {
                _ = try await Purchases.shared.logIn(currentUserID)
                currentAppUserID = currentUserID
            }

            await refresh(appState: appState, client: client)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refresh(appState: AppState? = nil, client: ConvexHTTPClient? = nil) async {
        configureIfNeeded()
        isLoading = true
        defer { isLoading = false }

        do {
            async let offeringsCall = Purchases.shared.offerings()
            async let customerInfoCall = Purchases.shared.customerInfo()

            let offerings = try await offeringsCall
            let customerInfo = try await customerInfoCall

            apply(offerings: offerings, customerInfo: customerInfo)

            if let appState, let client {
                try await reconcile(appState: appState, client: client)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchase(
        _ plan: SubscriptionPlanChoice,
        appState: AppState,
        client: ConvexHTTPClient
    ) async {
        configureIfNeeded()
        guard let package = packagesByPlan[plan] else {
            lastError = "Subscription option unavailable."
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(customerInfo: result.customerInfo)
            try await reconcile(appState: appState, client: client)
        } catch {
            if let errorCode = error as? ErrorCode,
               errorCode == .purchaseCancelledError {
                return
            }
            lastError = error.localizedDescription
        }
    }

    func restorePurchases(appState: AppState, client: ConvexHTTPClient) async {
        configureIfNeeded()
        isLoading = true
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            apply(customerInfo: customerInfo)
            try await reconcile(appState: appState, client: client)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func apply(offerings: Offerings, customerInfo: CustomerInfo) {
        let offering = offerings.offering(identifier: AppConfig.revenueCatOfferingLookupKey) ?? offerings.current
        let packages = offering?.availablePackages ?? []

        packagesByPlan = Dictionary(
            uniqueKeysWithValues: packages.compactMap { package in
                guard let plan = plan(for: package.storeProduct.productIdentifier) else {
                    return nil
                }
                return (plan, package)
            }
        )

        availablePackages = SubscriptionPlanChoice.allCases.compactMap { plan in
            guard let package = packagesByPlan[plan] else {
                return nil
            }
            return SubscriptionPackageState(
                plan: plan,
                title: plan.title,
                subtitle: plan.subtitle,
                priceLabel: package.storeProduct.localizedPriceString
            )
        }

        apply(customerInfo: customerInfo)
    }

    private func apply(customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements.active[AppConfig.revenueCatEntitlementID]
        let activePlan = entitlement.flatMap { plan(for: $0.productIdentifier) }

        storeState = StoreSubscriptionState(
            activePlan: activePlan,
            willRenew: entitlement?.willRenew,
            expiresAt: entitlement?.expirationDate.map { Int($0.timeIntervalSince1970 * 1000) }
        )
        managementURL = customerInfo.managementURL
        hasUnresolvedExpiryGap = false
    }

    private func reconcile(appState: AppState, client: ConvexHTTPClient) async throws {
        let action = determineSubscriptionSyncAction(
            backend: makeBackendSubscriptionSnapshot(from: appState.taskerProfile),
            store: storeState
        )

        switch action {
        case .none:
            hasUnresolvedExpiryGap = false

        case let .activate(plan, endsAt):
            var args: [String: Any] = [
                "plan": "tasker",
                "accessType": plan.backendAccessType,
            ]
            if let endsAt {
                args["endsAt"] = endsAt
            }
            let updatedProfile = try await client.mutation(
                "taskers:updateSubscriptionPlan",
                args: args
            ) as TaskerProfileSelf
            appState.taskerProfile = updatedProfile
            hasUnresolvedExpiryGap = false
            await appState.refreshAuthedData(client: client, surfaceErrors: false)

        case .scheduleCancellation:
            let updatedProfile = try await client.mutation("taskers:cancelSubscription", args: [:]) as TaskerProfileSelf
            appState.taskerProfile = updatedProfile
            hasUnresolvedExpiryGap = false
            await appState.refreshAuthedData(client: client, surfaceErrors: false)

        case .unresolvedExpiryGap:
            hasUnresolvedExpiryGap = true
        }
    }

    private func plan(for productIdentifier: String) -> SubscriptionPlanChoice? {
        SubscriptionPlanChoice.allCases.first { $0.productIdentifier == productIdentifier }
    }
}
