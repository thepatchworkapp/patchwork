import Foundation

enum SubscriptionPlanChoice: String, CaseIterable, Hashable {
    case weekly
    case lifetime

    var title: String {
        switch self {
        case .weekly:
            return "Weekly access"
        case .lifetime:
            return "Lifetime access"
        }
    }

    var productIdentifier: String {
        switch self {
        case .weekly:
            return AppConfig.revenueCatWeeklyProductID
        case .lifetime:
            return AppConfig.revenueCatLifetimeProductID
        }
    }

    var subtitle: String {
        switch self {
        case .weekly:
            return "Auto-renews weekly until cancelled."
        case .lifetime:
            return "One-time purchase with no renewal."
        }
    }

    var backendAccessType: String {
        rawValue
    }

    var isRenewable: Bool {
        self == .weekly
    }

    var purchaseAccessibilityIdentifier: String {
        switch self {
        case .weekly:
            return "Subscription.weeklyButton"
        case .lifetime:
            return "Subscription.lifetimeButton"
        }
    }
}

struct SubscriptionPackageState: Identifiable, Hashable {
    let plan: SubscriptionPlanChoice
    let title: String
    let subtitle: String
    let priceLabel: String

    var id: SubscriptionPlanChoice { plan }
}

struct StoreSubscriptionState: Equatable {
    var activePlan: SubscriptionPlanChoice?
    var willRenew: Bool?
    var expiresAt: Int?

    static let empty = StoreSubscriptionState(activePlan: nil, willRenew: nil, expiresAt: nil)
}

struct BackendSubscriptionSnapshot: Equatable {
    let plan: String
    let status: String?
    let hasActiveSubscription: Bool
    let accessType: String?
    let endsAt: Int?
}

enum SubscriptionSyncAction: Equatable {
    case none
    case activate(SubscriptionPlanChoice, endsAt: Int?)
    case scheduleCancellation
    case unresolvedExpiryGap
}

func determineSubscriptionSyncAction(
    backend: BackendSubscriptionSnapshot?,
    store: StoreSubscriptionState
) -> SubscriptionSyncAction {
    guard let backend else {
        return .none
    }

    guard let activePlan = store.activePlan else {
        return backend.hasActiveSubscription ? .unresolvedExpiryGap : .none
    }

    if backend.plan != "tasker" || backend.hasActiveSubscription == false {
        return .activate(activePlan, endsAt: store.expiresAt)
    }

    if backend.accessType != activePlan.backendAccessType {
        return .activate(activePlan, endsAt: store.expiresAt)
    }

    if activePlan.isRenewable {
        if backend.endsAt != store.expiresAt {
            return .activate(activePlan, endsAt: store.expiresAt)
        }

        if store.willRenew == false {
            return backend.status == "cancel_at_period_end" ? .none : .scheduleCancellation
        }
    }

    if backend.status == "active" {
        return .none
    }

    return .activate(activePlan, endsAt: store.expiresAt)
}

func makeBackendSubscriptionSnapshot(from profile: TaskerProfileSelf?) -> BackendSubscriptionSnapshot? {
    guard let profile else {
        return nil
    }

    return BackendSubscriptionSnapshot(
        plan: profile.subscriptionPlan,
        status: profile.subscriptionStatus,
        hasActiveSubscription: profile.hasActiveSubscription == true,
        accessType: profile.subscriptionAccessType,
        endsAt: profile.subscriptionEndsAt
    )
}
