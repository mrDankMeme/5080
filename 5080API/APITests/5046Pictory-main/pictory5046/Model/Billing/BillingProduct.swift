import Foundation

enum BillingProductKind: String {
    case subscription
    case unknown
}

struct BillingProduct: Identifiable, Equatable {
    let id: String
    let paywallID: String
    let kind: BillingProductKind
    let price: Decimal
    let localizedPrice: String
    let periodTitle: String?
    let currencyCode: String?
    let priceRegionCode: String?
    let isTrial: Bool
    let sourceProduct: Any?

    init(
        id: String,
        paywallID: String,
        kind: BillingProductKind = .unknown,
        price: Decimal = 0,
        localizedPrice: String = "",
        periodTitle: String? = nil,
        currencyCode: String? = nil,
        priceRegionCode: String? = nil,
        isTrial: Bool = false,
        sourceProduct: Any? = nil
    ) {
        self.id = id
        self.paywallID = paywallID
        self.kind = kind
        self.price = price
        self.localizedPrice = localizedPrice
        self.periodTitle = periodTitle
        self.currencyCode = currencyCode
        self.priceRegionCode = priceRegionCode
        self.isTrial = isTrial
        self.sourceProduct = sourceProduct
    }

    static func == (lhs: BillingProduct, rhs: BillingProduct) -> Bool {
        lhs.id == rhs.id
    }
}

struct BillingPaywall: Identifiable, Equatable {
    let id: String
    let products: [BillingProduct]
    let sourcePaywall: Any?

    init(id: String, products: [BillingProduct], sourcePaywall: Any? = nil) {
        self.id = id
        self.products = products
        self.sourcePaywall = sourcePaywall
    }

    static func == (lhs: BillingPaywall, rhs: BillingPaywall) -> Bool {
        lhs.id == rhs.id && lhs.products == rhs.products
    }
}

struct PurchaseResult: Equatable {
    let success: Bool
    let isSubscriptionActive: Bool
    let purchasedProductID: String?
    let transactionID: String?
    let errorMessage: String?
}

struct RestoreResult: Equatable {
    let success: Bool
    let hasActiveSubscription: Bool
    let restoredProductIDs: [String]
    let errorMessage: String?
}

@MainActor
protocol BillingProvider: AnyObject {
    func loadPaywalls() async throws -> [BillingPaywall]
    func purchase(product: BillingProduct) async -> PurchaseResult
    func restorePurchases() async -> RestoreResult
    func hasPremiumAccessSync() -> Bool
    func hasPremiumAccess() async -> Bool
    func userID() -> String
    func trackPaywallShown(_ paywall: BillingPaywall?)
    func trackPaywallClosed(_ paywall: BillingPaywall?)
}

extension BillingProvider {
    func trackPaywallShown(_ paywall: BillingPaywall?) {}
    func trackPaywallClosed(_ paywall: BillingPaywall?) {}
}
