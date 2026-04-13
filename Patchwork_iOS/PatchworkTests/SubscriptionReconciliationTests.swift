import XCTest
@testable import Patchwork

final class SubscriptionReconciliationTests: XCTestCase {
    func testSubscriptionPlanChoiceMapsAnnualProductIdentifier() {
        XCTAssertEqual(
            SubscriptionPlanChoice.subscription.productIdentifier,
            AppConfig.revenueCatAnnualProductID
        )
        XCTAssertEqual(SubscriptionPlanChoice.subscription.backendAccessType, "subscription")
        XCTAssertTrue(SubscriptionPlanChoice.subscription.isRenewable)
    }

    func testLifetimePlanChoiceMapsLifetimeProductIdentifier() {
        XCTAssertEqual(
            SubscriptionPlanChoice.lifetime.productIdentifier,
            AppConfig.revenueCatLifetimeProductID
        )
        XCTAssertEqual(SubscriptionPlanChoice.lifetime.backendAccessType, "lifetime")
        XCTAssertFalse(SubscriptionPlanChoice.lifetime.isRenewable)
    }

    func testEmptyStoreSubscriptionStateHasNoActivePlan() {
        XCTAssertTrue(StoreSubscriptionState.empty.activePlans.isEmpty)
        XCTAssertNil(StoreSubscriptionState.empty.effectivePlan)
        XCTAssertNil(StoreSubscriptionState.empty.willRenew)
        XCTAssertNil(StoreSubscriptionState.empty.expiresAt)
    }
}
