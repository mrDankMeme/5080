import Foundation

enum BillingProductKind: String {
    case subscription
    case unknown
}

enum BillingPeriodUnit: String {
    case day
    case week
    case month
    case year
    case unknown
}

struct BillingPeriod: Equatable {
    let unit: BillingPeriodUnit
    let numberOfUnits: Int
}

struct BillingProduct: Identifiable, Equatable {
    let id: String
    let paywallID: String
    let kind: BillingProductKind
    let price: Decimal
    let localizedPrice: String
    let localizedPricePerWeek: String?
    let period: BillingPeriod?
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
        localizedPricePerWeek: String? = nil,
        period: BillingPeriod? = nil,
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
        self.localizedPricePerWeek = localizedPricePerWeek
        self.period = period
        self.periodTitle = periodTitle
        self.currencyCode = currencyCode
        self.priceRegionCode = priceRegionCode
        self.isTrial = isTrial
        self.sourceProduct = sourceProduct
    }

    var timeString: String {
        if let periodTitle {
            let trimmed = periodTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let period {
            switch period.unit {
            case .week:
                return "week"
            case .month:
                return "month"
            case .year:
                return "year"
            case .day:
                return period.numberOfUnits == 7 ? "week" : "day"
            case .unknown:
                break
            }
        }

        let normalizedID = id.lowercased()
        if normalizedID.contains("week") {
            return "week"
        }
        if normalizedID.contains("month") {
            return "month"
        }
        if normalizedID.contains("year") || normalizedID.contains("annual") {
            return "year"
        }
        if normalizedID.contains("day") {
            return "day"
        }

        return "subscription"
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
    func trackPaywallShown(_ paywall: BillingPaywall?) { }
    func trackPaywallClosed(_ paywall: BillingPaywall?) { }
}
