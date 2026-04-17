
import Foundation

enum PaywallProductText {

    static func planTitle(for product: BillingProduct, isEnglishUI: Bool) -> String {
        let t = product.timeString.lowercased()
        if isEnglishUI {
            if t.contains("week") { return "Weekly" }
            if t.contains("year") { return "Yearly" }
            if t.contains("month") { return "Monthly" }
            return product.timeString.capitalizingFirstLetter()
        } else {
            if t.contains("week") { return "Еженедельно" }
            if t.contains("year") { return "Ежегодно" }
            if t.contains("month") { return "Ежемесячно" }
            return product.timeString.capitalizingFirstLetter()
        }
    }

    static func planSubtitle(for product: BillingProduct, isEnglishUI: Bool) -> String {
        let t = product.timeString.lowercased()
        if isEnglishUI {
            if t.contains("week") { return "1 week" }
            if t.contains("year") { return "12 month" }
            if t.contains("month") { return "1 month" }
            return ""
        } else {
            if t.contains("week") { return "1 неделя" }
            if t.contains("year") { return "12 месяц" }
            if t.contains("month") { return "1 месяц" }
            return ""
        }
    }

    static func planPriceText(for product: BillingProduct, isEnglishUI: Bool) -> String {
        product.localizedPrice
    }

    static func planSecondaryPriceText(for product: BillingProduct, isEnglishUI: Bool) -> String? {
        guard product.timeString.lowercased().contains("year") else { return nil }
        guard let localizedPricePerWeek = product.localizedPricePerWeek else { return nil }

        return isEnglishUI
        ? "\(localizedPricePerWeek) / week"
        : "\(localizedPricePerWeek) / неделя"
    }
}
