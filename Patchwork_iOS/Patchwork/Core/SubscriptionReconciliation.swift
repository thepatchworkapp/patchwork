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
    var activePlan: SubscriptionPlanChoice?
    var willRenew: Bool?
    var expiresAt: Int?

    static let empty = StoreSubscriptionState(activePlan: nil, willRenew: nil, expiresAt: nil)
}
