import XCTest
@testable import Patchwork

final class SubscriptionReconciliationTests: XCTestCase {
    func testActivateWhenStoreShowsActivePlanAndBackendIsInactive() {
        let action = determineSubscriptionSyncAction(
            backend: BackendSubscriptionSnapshot(
                plan: "none",
                status: "inactive",
                hasActiveSubscription: false,
                accessType: nil,
                endsAt: nil
            ),
            store: StoreSubscriptionState(activePlan: .weekly, willRenew: true, expiresAt: 1_000)
        )

        XCTAssertEqual(action, .activate(.weekly, endsAt: 1_000))
    }

    func testScheduleCancellationWhenStoreWillNotRenew() {
        let action = determineSubscriptionSyncAction(
            backend: BackendSubscriptionSnapshot(
                plan: "tasker",
                status: "active",
                hasActiveSubscription: true,
                accessType: "weekly",
                endsAt: 2_000
            ),
            store: StoreSubscriptionState(activePlan: .weekly, willRenew: false, expiresAt: 2_000)
        )

        XCTAssertEqual(action, .scheduleCancellation)
    }

    func testNoActionWhenBackendAlreadyMatchesCancelledStoreState() {
        let action = determineSubscriptionSyncAction(
            backend: BackendSubscriptionSnapshot(
                plan: "tasker",
                status: "cancel_at_period_end",
                hasActiveSubscription: true,
                accessType: "weekly",
                endsAt: 2_000
            ),
            store: StoreSubscriptionState(activePlan: .weekly, willRenew: false, expiresAt: 2_000)
        )

        XCTAssertEqual(action, .none)
    }

    func testFlagsUnresolvedExpiryGapWhenStoreHasNoEntitlementButBackendStillActive() {
        let action = determineSubscriptionSyncAction(
            backend: BackendSubscriptionSnapshot(
                plan: "tasker",
                status: "active",
                hasActiveSubscription: true,
                accessType: "weekly",
                endsAt: 2_000
            ),
            store: .empty
        )

        XCTAssertEqual(action, .unresolvedExpiryGap)
    }

    func testNoActionWhenNeitherStoreNorBackendHasActiveSubscription() {
        let action = determineSubscriptionSyncAction(
            backend: BackendSubscriptionSnapshot(
                plan: "none",
                status: "inactive",
                hasActiveSubscription: false,
                accessType: nil,
                endsAt: nil
            ),
            store: .empty
        )

        XCTAssertEqual(action, .none)
    }

    func testLifetimeAccessDoesNotScheduleCancellation() {
        let action = determineSubscriptionSyncAction(
            backend: BackendSubscriptionSnapshot(
                plan: "tasker",
                status: "active",
                hasActiveSubscription: true,
                accessType: "lifetime",
                endsAt: nil
            ),
            store: StoreSubscriptionState(activePlan: .lifetime, willRenew: false, expiresAt: nil)
        )

        XCTAssertEqual(action, .none)
    }
}
