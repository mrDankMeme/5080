import Foundation

enum BillingConfig {
    static let adaptyAPIKey = "public_live_eqjH7kqy.OvsOR6U3fqWJgnjfamql"
    static let adaptyMainPlacementID = "main"
    static let adaptyTokensPlacementID = "tokens"
    static let adaptyFallbackPlacementIDs = ["main", "paywall", "default"]
    static let adaptyAccessLevelKey = "premium"

    static let subscriptionProductIDs: [String] = [
        "week_6.99_nottrial",
        "yearly_49.99_nottrial"
    ]

    static let adaptyWeeklyProductID: String = {
        subscriptionProductIDs.first {
            let value = $0.lowercased()
            return value.contains("week")
        } ?? "week_6.99_nottrial"
    }()

    static let adaptyAnnualProductID: String = {
        subscriptionProductIDs.first {
            let value = $0.lowercased()
            return value.contains("year") || value.contains("annual")
        } ?? "yearly_49.99_nottrial"
    }()

    static let tokenProductIDs: [String] = [
        "100_Tokens_9.99",
        "250_Tokens_19.99",
        "500_Tokens_34.99",
        "1000_Tokens_59.99",
        "2000_Tokens_99.99"
    ]
}
