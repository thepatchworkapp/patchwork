import Foundation

enum SubscriptionPlanChoice: String, CaseIterable, Hashable {
    case basic
    case premium
    case founders

    var title: String {
        switch self {
        case .basic:
            return "Basic"
        case .premium:
            return "Premium yearly"
        case .founders:
            return "Founders Club"
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

    var backendAccessType: String {
        switch self {
        case .basic, .premium:
            return "subscription"
        case .founders:
            return "lifetime"
        }
    }

    var backendTier: String {
        rawValue
    }

    var isRenewable: Bool {
        self == .basic || self == .premium
    }
}

struct StoreSubscriptionState: Equatable {
    var activePlans: [SubscriptionPlanChoice]
    var effectivePlan: SubscriptionPlanChoice?
    var willRenew: Bool?
    var expiresAt: Int?

    var hasAccess: Bool {
        effectivePlan != nil
    }

    var hasRenewableAccess: Bool {
        activePlans.contains(where: \.isRenewable) || willRenew == true
    }

    var hasMultipleActivePlans: Bool {
        activePlans.count > 1
    }

    static let empty = StoreSubscriptionState(activePlans: [], effectivePlan: nil, willRenew: nil, expiresAt: nil)
}

enum BackendSubscriptionPlanResolver {
    static func confirmedPlans(
        hasActiveSubscription: Bool?,
        activeAccessTypes: [String]?,
        accessType: String?,
        tier: String?
    ) -> [SubscriptionPlanChoice] {
        guard hasActiveSubscription == true else {
            return []
        }

        if let tierPlan = planChoice(forBackendAccessType: nil, tier: tier) {
            return [tierPlan]
        }

        let mappedAccessTypes = (activeAccessTypes ?? []).compactMap {
            planChoice(forBackendAccessType: $0)
        }
        if !mappedAccessTypes.isEmpty {
            return mappedAccessTypes
        }

        if let fallbackPlan = planChoice(forBackendAccessType: accessType) {
            return [fallbackPlan]
        }

        return []
    }

    static func preferredPlan(from plans: [SubscriptionPlanChoice]) -> SubscriptionPlanChoice? {
        if plans.contains(.founders) {
            return .founders
        }
        if plans.contains(.premium) {
            return .premium
        }
        if plans.contains(.basic) {
            return .basic
        }
        return nil
    }

    static func planChoice(forBackendAccessType accessType: String?, tier: String? = nil) -> SubscriptionPlanChoice? {
        switch tier {
        case "founders":
            return .founders
        case "premium":
            return .premium
        case "basic":
            return .basic
        default:
            break
        }

        switch accessType {
        case "lifetime":
            return .founders
        case "subscription":
            return .premium
        default:
            return nil
        }
    }
}
