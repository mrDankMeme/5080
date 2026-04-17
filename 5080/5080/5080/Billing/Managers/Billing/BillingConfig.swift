import Foundation

enum BillingConfig {
    static let adaptyAPIKey = "public_live_CklVXnT4.l0kgX6MEcJff9NG1XfPj"
    static let adaptyMainPlacementID = "main"
    static let adaptyTokensPlacementID = "tokens"
    static let adaptyFallbackPlacementIDs = ["main", "paywall", "default"]
    static let adaptyAccessLevelKey = "premium"

    static let subscriptionProductIDs: [String] = [
        "week_6.99_not_trial",
        "yearly_49.99_not_trial"
    ]

    static let adaptyWeeklyProductID: String = {
        subscriptionProductIDs.first {
            let value = $0.lowercased()
            return value.contains("week")
        } ?? "week_6.99_not_trial"
    }()

    static let adaptyAnnualProductID: String = {
        subscriptionProductIDs.first {
            let value = $0.lowercased()
            return value.contains("year") || value.contains("annual")
        } ?? "yearly_49.99_not_trial"
    }()

    static let tokenProductIDs: [String] = [
        "100_tokens_9.99",
        "250_tokens_19.99",
        "500_tokens_34.99",
        "1000_tokens_59.99",
        "2000_tokens_99.99"
    ]
}
