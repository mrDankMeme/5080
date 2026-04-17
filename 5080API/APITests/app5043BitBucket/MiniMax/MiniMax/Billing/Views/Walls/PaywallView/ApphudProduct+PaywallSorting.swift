
import Foundation

extension Array where Element == BillingProduct {

    func paywallSortedProducts() -> [BillingProduct] {
        self.sorted { lhs, rhs in
            let lt = lhs.timeString.lowercased()
            let rt = rhs.timeString.lowercased()

            if lt.contains("week"), rt.contains("year") { return true }
            if lt.contains("year"), rt.contains("week") { return false }

            return lhs.price < rhs.price
        }
    }
}
