
import Foundation

enum PaywallProductText {

    static func planTitle(for product: BillingProduct, isEnglishUI: Bool) -> String {
        _ = isEnglishUI
        let t = product.timeString.lowercased()
        if t.contains("week") { return "Weekly" }
        if t.contains("year") { return "Yearly" }
        if t.contains("month") { return "Monthly" }
        return product.timeString.capitalizingFirstLetter()
    }

    static func planSubtitle(for product: BillingProduct, isEnglishUI: Bool) -> String {
        _ = isEnglishUI
        let t = product.timeString.lowercased()
        if t.contains("week") { return "1 week" }
        if t.contains("year") { return "12 months" }
        if t.contains("month") { return "1 month" }
        return ""
    }

    static func planPriceText(for product: BillingProduct, isEnglishUI: Bool) -> String {
        product.localizedPrice
    }

    static func planSecondaryPriceText(for product: BillingProduct, isEnglishUI: Bool) -> String? {
        _ = isEnglishUI
        guard product.timeString.lowercased().contains("year") else { return nil }
        guard let localizedPricePerWeek = product.localizedPricePerWeek else { return nil }

        return "\(localizedPricePerWeek) / week"
    }

    static func savingsBadgeText(for product: BillingProduct, comparedTo referenceProduct: BillingProduct?) -> String? {
        guard let referenceProduct,
              let savingsPercent = savingsPercent(for: product, comparedTo: referenceProduct),
              savingsPercent > 0 else {
            return nil
        }

        return "SAVE \(savingsPercent)%"
    }

    private static func savingsPercent(for product: BillingProduct, comparedTo referenceProduct: BillingProduct) -> Int? {
        let productPrice = NSDecimalNumber(decimal: product.price).doubleValue
        let referencePrice = NSDecimalNumber(decimal: referenceProduct.price).doubleValue

        guard productPrice > 0, referencePrice > 0,
              let productDurationInWeeks = durationInWeeks(for: product),
              let referenceDurationInWeeks = durationInWeeks(for: referenceProduct),
              productDurationInWeeks > 0,
              referenceDurationInWeeks > 0 else {
            return nil
        }

        let referenceCostForMatchingDuration = referencePrice * (productDurationInWeeks / referenceDurationInWeeks)
        guard referenceCostForMatchingDuration > productPrice else { return nil }

        let rawSavingsPercent = (1.0 - (productPrice / referenceCostForMatchingDuration)) * 100.0
        let roundedSavingsPercent = Int(rawSavingsPercent.rounded())

        return roundedSavingsPercent > 0 ? roundedSavingsPercent : nil
    }

    private static func durationInWeeks(for product: BillingProduct) -> Double? {
        if let period = product.period {
            return durationInWeeks(for: period)
        }

        let normalizedTimeString = product.timeString.lowercased()
        if normalizedTimeString.contains("week") {
            return 1.0
        }
        if normalizedTimeString.contains("month") {
            return 52.0 / 12.0
        }
        if normalizedTimeString.contains("year") || normalizedTimeString.contains("annual") {
            return 52.0
        }
        if normalizedTimeString.contains("day") {
            return 1.0 / 7.0
        }

        return nil
    }

    private static func durationInWeeks(for period: BillingPeriod) -> Double? {
        let units = Double(period.numberOfUnits)
        guard units > 0 else { return nil }

        switch period.unit {
        case .day:
            return units / 7.0
        case .week:
            return units
        case .month:
            return units * (52.0 / 12.0)
        case .year:
            return units * 52.0
        case .unknown:
            return nil
        }
    }
}
