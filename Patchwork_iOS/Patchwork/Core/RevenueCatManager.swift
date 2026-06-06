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

    private func log(_ message: String) {
        print("[RevenueCatManager] \(message)")
    }

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
                    log("Logging out current App User ID \(currentAppUserID ?? "unknown")")
                    _ = try await Purchases.shared.logOut()
                }
                currentAppUserID = nil
                currentOffering = nil
                storeState = .empty
                managementURL = nil
                return
            }

            if currentAppUserID != currentUserID {
                log("Logging in App User ID \(currentUserID)")
                _ = try await Purchases.shared.logIn(currentUserID)
                currentAppUserID = currentUserID
            }

            await refresh(appState: appState, client: client)
        } catch {
            log("syncIdentity failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    func refresh(appState: AppState? = nil, client: ConvexHTTPClient? = nil) async {
        configureIfNeeded()
        isLoading = true
        defer { isLoading = false }

        do {
            log("Refreshing offerings and customer info")
            async let offeringsCall = Purchases.shared.offerings()
            async let customerInfoCall = Purchases.shared.customerInfo()

            let offerings = try await offeringsCall
            let customerInfo = try await customerInfoCall

            apply(offerings: offerings, customerInfo: customerInfo)
        } catch {
            log("refresh failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        configureIfNeeded()
        isLoading = true
        defer { isLoading = false }

        do {
            log("Restoring purchases")
            let customerInfo = try await Purchases.shared.restorePurchases()
            apply(customerInfo: customerInfo)
        } catch {
            log("restorePurchases failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func purchase(package: Package) async -> Bool {
        configureIfNeeded()
        isLoading = true
        defer { isLoading = false }

        do {
            log("Purchasing product \(package.storeProduct.productIdentifier)")
            let result = try await Purchases.shared.purchase(package: package)
            apply(customerInfo: result.customerInfo)

            if result.userCancelled {
                log("Purchase cancelled by user for \(package.storeProduct.productIdentifier)")
                lastError = nil
                return false
            }

            log("Purchase succeeded for \(package.storeProduct.productIdentifier)")
            lastError = nil
            return true
        } catch {
            log("purchase failed for \(package.storeProduct.productIdentifier): \(error.localizedDescription)")
            lastError = error.localizedDescription
            return false
        }
    }

    private func apply(offerings: Offerings, customerInfo: CustomerInfo) {
        guard let offering = offerings.offering(identifier: AppConfig.revenueCatOfferingLookupKey) else {
            currentOffering = nil
            apply(customerInfo: customerInfo)
            log("Required offering \(AppConfig.revenueCatOfferingLookupKey) is unavailable")
            lastError = "Required App Store offering is unavailable."
            return
        }

        currentOffering = offering
        log("Loaded offering \(offering.identifier) with \(offering.availablePackages.count) packages")
        lastError = nil
        apply(customerInfo: customerInfo)
    }

    private func apply(customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements.active[AppConfig.revenueCatEntitlementID]
        let managementURL = customerInfo.managementURL
        var activePlans = Set<SubscriptionPlanChoice>()
        if let entitlementPlan = entitlement.flatMap({ plan(for: $0.productIdentifier) }) {
            activePlans.insert(entitlementPlan)
        }

        let orderedActivePlans = SubscriptionPlanChoice.allCases.filter { activePlans.contains($0) }
        let effectivePlan: SubscriptionPlanChoice?
        if activePlans.contains(.founders) {
            effectivePlan = .founders
        } else if activePlans.contains(.premium) {
            effectivePlan = .premium
        } else if activePlans.contains(.basic) {
            effectivePlan = .basic
        } else {
            effectivePlan = nil
        }

        storeState = StoreSubscriptionState(
            activePlans: orderedActivePlans,
            effectivePlan: effectivePlan,
            willRenew: entitlement?.willRenew,
            expiresAt: entitlement?.expirationDate.map { Int($0.timeIntervalSince1970 * 1000) }
        )
        self.managementURL = managementURL
        log("Applied customer info with active plans \(orderedActivePlans.map(\.rawValue).joined(separator: ","))")
    }

    private func plan(for productIdentifier: String) -> SubscriptionPlanChoice? {
        SubscriptionPlanChoice.allCases.first { $0.productIdentifier == productIdentifier }
    }
}
