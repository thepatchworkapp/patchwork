import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class RevenueCatManager {
    private var isConfigured = false
    private var currentAppUserID: String?

    private(set) var currentOffering: Offering?
    private(set) var storeState: StoreSubscriptionState = .empty
    private(set) var managementURL: URL?
    private(set) var isLoading = false
    private(set) var lastError: String?

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
                currentOffering = nil
                storeState = .empty
                managementURL = nil
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
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        configureIfNeeded()
        isLoading = true
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            apply(customerInfo: customerInfo)
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func purchase(package: Package) async -> Bool {
        configureIfNeeded()
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(customerInfo: result.customerInfo)

            if result.userCancelled {
                lastError = nil
                return false
            }

            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func apply(offerings: Offerings, customerInfo: CustomerInfo) {
        guard let offering = offerings.offering(identifier: AppConfig.revenueCatOfferingLookupKey) else {
            currentOffering = nil
            apply(customerInfo: customerInfo)
            lastError = "Required App Store offering is unavailable."
            return
        }

        currentOffering = offering
        lastError = nil
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
    }

    private func plan(for productIdentifier: String) -> SubscriptionPlanChoice? {
        SubscriptionPlanChoice.allCases.first { $0.productIdentifier == productIdentifier }
    }
}
