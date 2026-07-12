import Foundation
import StoreKit

enum SubscriptionPlan: String, CaseIterable, Equatable, Identifiable {
    case monthly
    case yearly

    static let monthlyProductID = "com.teopateo.TeoPateo.premium.monthly"
    static let yearlyProductID = "com.teopateo.TeoPateo.premium.yearly"

    var id: String { rawValue }

    var productID: String {
        switch self {
        case .monthly:
            Self.monthlyProductID
        case .yearly:
            Self.yearlyProductID
        }
    }

    static var productIDs: Set<String> {
        Set(allCases.map(\.productID))
    }

    init?(productID: String) {
        switch productID {
        case Self.monthlyProductID:
            self = .monthly
        case Self.yearlyProductID:
            self = .yearly
        default:
            return nil
        }
    }
}

enum SubscriptionRenewalState: String, Equatable {
    case active
    case inGracePeriod
    case inBillingRetryPeriod
    case expired
    case revoked
    case unknown
}

struct PremiumEntitlement: Equatable {
    let plan: SubscriptionPlan
    let productID: String
    let originalTransactionID: UInt64
    let transactionID: UInt64
    let purchaseDate: Date
    let expirationDate: Date?
    let isUsingIntroductoryOffer: Bool
    let renewalState: SubscriptionRenewalState
    let willAutoRenew: Bool?

    var isTrial: Bool {
        isUsingIntroductoryOffer
    }
}

enum EntitlementState: Equatable {
    case loading
    case free
    case premium(PremiumEntitlement)

    var isPremium: Bool {
        if case .premium = self {
            return true
        }
        return false
    }

    var premiumEntitlement: PremiumEntitlement? {
        guard case let .premium(entitlement) = self else {
            return nil
        }
        return entitlement
    }
}

enum SubscriptionOperation: Equatable {
    case idle
    case loadingProducts
    case purchasing(SubscriptionPlan)
    case restoringPurchases
}

enum SubscriptionPurchaseResult: Equatable {
    case purchased(PremiumEntitlement)
    case cancelled
    case pending
    case failed(String)
}

/// The single source of truth for App Store subscription products and local
/// entitlement state. Feature gates should read `entitlement.isPremium` rather
/// than independently querying StoreKit.
@MainActor
final class SubscriptionStore: ObservableObject {
    @Published private(set) var entitlement: EntitlementState = .loading
    @Published private(set) var products: [SubscriptionPlan: Product] = [:]
    @Published private(set) var introductoryOfferEligiblePlans: Set<SubscriptionPlan> = []
    @Published private(set) var operation: SubscriptionOperation = .idle
    @Published private(set) var lastErrorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    init(refreshOnLaunch: Bool = true) {
        transactionUpdatesTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: result)
            }
        }

        if refreshOnLaunch {
            Task { [weak self] in
                await self?.refreshStoreKitState()
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var isPremium: Bool {
        entitlement.isPremium
    }

    func product(for plan: SubscriptionPlan) -> Product? {
        products[plan]
    }

    func isEligibleForIntroductoryOffer(on plan: SubscriptionPlan) -> Bool {
        introductoryOfferEligiblePlans.contains(plan)
    }

    /// Reloads storefront pricing and local entitlement state. This is safe to
    /// call when the app returns to the foreground or after a server-side
    /// subscription update.
    func refreshStoreKitState() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        guard operation == .idle || operation == .loadingProducts else { return }

        operation = .loadingProducts
        lastErrorMessage = nil
        defer { operation = .idle }

        do {
            let fetchedProducts = try await Product.products(for: SubscriptionPlan.productIDs)
            products = Dictionary(
                uniqueKeysWithValues: fetchedProducts.compactMap { product in
                    guard let plan = SubscriptionPlan(productID: product.id) else {
                        return nil
                    }
                    return (plan, product)
                }
            )
            var eligiblePlans: Set<SubscriptionPlan> = []
            for product in fetchedProducts {
                guard
                    let plan = SubscriptionPlan(productID: product.id),
                    let subscription = product.subscription,
                    await subscription.isEligibleForIntroOffer
                else {
                    continue
                }
                eligiblePlans.insert(plan)
            }
            introductoryOfferEligiblePlans = eligiblePlans

            if products.isEmpty {
                lastErrorMessage = "Subscriptions are not available right now. Please try again later."
            }
        } catch {
            lastErrorMessage = "Subscriptions are not available right now. Please try again later."
        }
    }

    func purchase(_ plan: SubscriptionPlan) async -> SubscriptionPurchaseResult {
        guard operation == .idle else {
            return .failed("A subscription request is already in progress.")
        }

        if products[plan] == nil {
            await loadProducts()
        }
        guard let product = products[plan] else {
            return .failed("That subscription is not available right now. Please try again later.")
        }

        operation = .purchasing(plan)
        lastErrorMessage = nil
        defer { operation = .idle }

        do {
            switch try await product.purchase() {
            case let .success(verificationResult):
                guard case let .verified(transaction) = verificationResult else {
                    let message = "We could not verify that purchase. Please try again or restore purchases."
                    lastErrorMessage = message
                    return .failed(message)
                }

                await transaction.finish()
                await refreshEntitlements()

                if let entitlement = entitlement.premiumEntitlement {
                    return .purchased(entitlement)
                }

                let message = "Your purchase completed, but your access could not be updated yet. Please restore purchases."
                lastErrorMessage = message
                return .failed(message)

            case .userCancelled:
                return .cancelled

            case .pending:
                return .pending

            @unknown default:
                let message = "We could not complete that purchase. Please try again later."
                lastErrorMessage = message
                return .failed(message)
            }
        } catch {
            let message = "We could not complete that purchase. Please try again later."
            lastErrorMessage = message
            return .failed(message)
        }
    }

    /// Gives the App Store a chance to sync transactions from the customer's
    /// Apple Account, then recomputes the local entitlement from verified data.
    @discardableResult
    func restorePurchases() async -> Bool {
        guard operation == .idle else { return false }

        operation = .restoringPurchases
        lastErrorMessage = nil
        defer { operation = .idle }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return true
        } catch {
            lastErrorMessage = "We could not restore purchases right now. Please try again later."
            return false
        }
    }

    func refreshEntitlements() async {
        var activeTransactions: [Transaction] = []

        for await verificationResult in Transaction.currentEntitlements {
            guard case let .verified(transaction) = verificationResult else {
                continue
            }
            guard SubscriptionPlan(productID: transaction.productID) != nil else {
                continue
            }
            guard transaction.revocationDate == nil else {
                continue
            }
            if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                continue
            }
            activeTransactions.append(transaction)
        }

        guard let transaction = activeTransactions.max(by: Self.isOlderEntitlement) else {
            entitlement = .free
            return
        }

        let renewalDetails = await renewalDetails(for: transaction)
        guard let plan = SubscriptionPlan(productID: transaction.productID) else {
            entitlement = .free
            return
        }

        entitlement = .premium(PremiumEntitlement(
            plan: plan,
            productID: transaction.productID,
            originalTransactionID: transaction.originalID,
            transactionID: transaction.id,
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            isUsingIntroductoryOffer: transaction.offerType == .introductory,
            renewalState: renewalDetails?.state ?? .active,
            willAutoRenew: renewalDetails?.willAutoRenew
        ))
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = transactionResult else {
            return
        }
        guard SubscriptionPlan(productID: transaction.productID) != nil else {
            return
        }

        await transaction.finish()
        await refreshEntitlements()
    }

    private func renewalDetails(for transaction: Transaction) async -> RenewalDetails? {
        guard
            let plan = SubscriptionPlan(productID: transaction.productID),
            let subscription = products[plan]?.subscription
        else {
            return nil
        }

        do {
            let statuses = try await subscription.status
            guard let status = statuses.first(where: { status in
                guard case let .verified(statusTransaction) = status.transaction else {
                    return false
                }
                return statusTransaction.originalID == transaction.originalID
            }) else {
                return nil
            }

            let willAutoRenew: Bool?
            if case let .verified(renewalInfo) = status.renewalInfo {
                willAutoRenew = renewalInfo.willAutoRenew
            } else {
                willAutoRenew = nil
            }

            return RenewalDetails(
                state: Self.renewalState(from: status.state),
                willAutoRenew: willAutoRenew
            )
        } catch {
            return nil
        }
    }

    private static func isOlderEntitlement(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        let lhsDate = lhs.expirationDate ?? lhs.purchaseDate
        let rhsDate = rhs.expirationDate ?? rhs.purchaseDate
        return lhsDate < rhsDate
    }

    private static func renewalState(
        from state: Product.SubscriptionInfo.RenewalState
    ) -> SubscriptionRenewalState {
        switch state {
        case .subscribed:
            .active
        case .inGracePeriod:
            .inGracePeriod
        case .inBillingRetryPeriod:
            .inBillingRetryPeriod
        case .expired:
            .expired
        case .revoked:
            .revoked
        default:
            .unknown
        }
    }
}

private extension SubscriptionStore {
    struct RenewalDetails {
        let state: SubscriptionRenewalState
        let willAutoRenew: Bool?
    }
}
