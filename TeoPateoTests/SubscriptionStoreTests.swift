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

    @MainActor
    func testFreeEntitlementLocksEveryPremiumFeature() {
        let store = SubscriptionStore(
            refreshOnLaunch: false,
            initialEntitlement: .free
        )

        let locked = PremiumFeature.allCases.allSatisfy { feature in
            !store.hasAccess(to: feature)
        }

        XCTAssertTrue(locked)
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

    @MainActor
    func testPremiumEntitlementUnlocksEveryPremiumFeature() {
        let entitlement = PremiumEntitlement(
            plan: .monthly,
            productID: SubscriptionPlan.monthlyProductID,
            originalTransactionID: 200,
            transactionID: 201,
            purchaseDate: Date(timeIntervalSince1970: 1_000),
            expirationDate: Date(timeIntervalSince1970: 2_000),
            isUsingIntroductoryOffer: false,
            renewalState: .active,
            willAutoRenew: true
        )
        let store = SubscriptionStore(
            refreshOnLaunch: false,
            initialEntitlement: .premium(entitlement)
        )

        let unlocked = PremiumFeature.allCases.allSatisfy { feature in
            store.hasAccess(to: feature)
        }

        XCTAssertTrue(unlocked)
    }

    func testIntroductoryOfferEligibilityStartsEmptyUntilProductsLoad() async {
        let store = await SubscriptionStore(refreshOnLaunch: false)
        let monthlyEligible = await store.isEligibleForIntroductoryOffer(on: .monthly)
        let yearlyEligible = await store.isEligibleForIntroductoryOffer(on: .yearly)

        XCTAssertFalse(monthlyEligible)
        XCTAssertFalse(yearlyEligible)
    }

}
