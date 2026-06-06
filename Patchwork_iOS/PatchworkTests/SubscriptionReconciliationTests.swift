import XCTest
@testable import Patchwork

final class SubscriptionReconciliationTests: XCTestCase {
    func testBasicPlanChoiceMapsMonthlyProductIdentifier() {
        XCTAssertEqual(
            SubscriptionPlanChoice.basic.productIdentifier,
            AppConfig.revenueCatBasicMonthlyProductID
        )
        XCTAssertEqual(SubscriptionPlanChoice.basic.backendAccessType, "subscription")
        XCTAssertEqual(SubscriptionPlanChoice.basic.backendTier, "basic")
        XCTAssertTrue(SubscriptionPlanChoice.basic.isRenewable)
    }

    func testPremiumPlanChoiceMapsAnnualProductIdentifier() {
        XCTAssertEqual(
            SubscriptionPlanChoice.premium.productIdentifier,
            AppConfig.revenueCatAnnualProductID
        )
        XCTAssertEqual(SubscriptionPlanChoice.premium.title, "Premium yearly")
        XCTAssertEqual(SubscriptionPlanChoice.premium.backendAccessType, "subscription")
        XCTAssertEqual(SubscriptionPlanChoice.premium.backendTier, "premium")
        XCTAssertTrue(SubscriptionPlanChoice.premium.isRenewable)
    }

    func testFoundersPlanChoiceMapsLifetimeProductIdentifier() {
        XCTAssertEqual(
            SubscriptionPlanChoice.founders.productIdentifier,
            AppConfig.revenueCatLifetimeProductID
        )
        XCTAssertEqual(SubscriptionPlanChoice.founders.backendAccessType, "lifetime")
        XCTAssertEqual(SubscriptionPlanChoice.founders.backendTier, "founders")
        XCTAssertFalse(SubscriptionPlanChoice.founders.isRenewable)
    }

    func testEmptyStoreSubscriptionStateHasNoActivePlan() {
        XCTAssertTrue(StoreSubscriptionState.empty.activePlans.isEmpty)
        XCTAssertNil(StoreSubscriptionState.empty.effectivePlan)
        XCTAssertNil(StoreSubscriptionState.empty.willRenew)
        XCTAssertNil(StoreSubscriptionState.empty.expiresAt)
    }
}
