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
