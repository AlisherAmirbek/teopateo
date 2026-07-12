import XCTest
@testable import TeoPateo

final class SubscriptionStoreTests: XCTestCase {
    func testPlansUseStableProductIdentifiers() {
        XCTAssertEqual(
            SubscriptionPlan.monthly.productID,
            "com.teopateo.TeoPateo.premium.monthly"
        )
        XCTAssertEqual(
            SubscriptionPlan.yearly.productID,
            "com.teopateo.TeoPateo.premium.yearly"
        )
        XCTAssertEqual(SubscriptionPlan(productID: SubscriptionPlan.monthlyProductID), .monthly)
        XCTAssertEqual(SubscriptionPlan(productID: SubscriptionPlan.yearlyProductID), .yearly)
        XCTAssertNil(SubscriptionPlan(productID: "com.teopateo.TeoPateo.unknown"))
    }

    func testFreeEntitlementDoesNotUnlockPremium() {
        XCTAssertFalse(EntitlementState.free.isPremium)
        XCTAssertNil(EntitlementState.free.premiumEntitlement)
        XCTAssertFalse(EntitlementState.loading.isPremium)
    }

    func testPremiumEntitlementRetainsTrialAndRenewalInformation() {
        let entitlement = PremiumEntitlement(
            plan: .yearly,
            productID: SubscriptionPlan.yearlyProductID,
            originalTransactionID: 100,
            transactionID: 101,
            purchaseDate: Date(timeIntervalSince1970: 1_000),
            expirationDate: Date(timeIntervalSince1970: 2_000),
            isUsingIntroductoryOffer: true,
            renewalState: .inGracePeriod,
            willAutoRenew: true
        )
        let state = EntitlementState.premium(entitlement)

        XCTAssertTrue(state.isPremium)
        XCTAssertEqual(state.premiumEntitlement, entitlement)
        XCTAssertTrue(entitlement.isTrial)
        XCTAssertEqual(entitlement.renewalState, .inGracePeriod)
        XCTAssertEqual(entitlement.willAutoRenew, true)
    }

    func testIntroductoryOfferEligibilityStartsEmptyUntilProductsLoad() async {
        let store = await SubscriptionStore(refreshOnLaunch: false)
        let monthlyEligible = await store.isEligibleForIntroductoryOffer(on: .monthly)
        let yearlyEligible = await store.isEligibleForIntroductoryOffer(on: .yearly)

        XCTAssertFalse(monthlyEligible)
        XCTAssertFalse(yearlyEligible)
    }

}
