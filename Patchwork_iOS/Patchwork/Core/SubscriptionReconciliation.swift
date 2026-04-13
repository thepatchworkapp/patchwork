import Foundation

enum SubscriptionPlanChoice: String, CaseIterable, Hashable {
    case subscription
    case lifetime

    var title: String {
        switch self {
        case .subscription:
            return "Subscribe"
        case .lifetime:
            return "Founders Club"
        }
    }

    var productIdentifier: String {
        switch self {
        case .subscription:
            return AppConfig.revenueCatAnnualProductID
        case .lifetime:
            return AppConfig.revenueCatLifetimeProductID
        }
    }

    var backendAccessType: String {
        rawValue
    }

    var isRenewable: Bool {
        self == .subscription
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
        activePlans.contains(.subscription) || willRenew == true
    }

    var hasMultipleActivePlans: Bool {
        activePlans.count > 1
    }

    static let empty = StoreSubscriptionState(activePlans: [], effectivePlan: nil, willRenew: nil, expiresAt: nil)
}
