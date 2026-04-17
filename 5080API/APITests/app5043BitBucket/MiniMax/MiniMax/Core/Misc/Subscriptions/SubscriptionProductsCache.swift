


import Foundation
import StoreKit

final class SubscriptionProductsCache {
    static let shared = SubscriptionProductsCache()
    private init() {}

    private var products: [String: Product] = [:]
    private var isLoading = false

    
    func prefetch(ids: [String]) {
        guard !isLoading else { return }
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                let loaded = try await Product.products(for: ids)
                var dict: [String: Product] = [:]
                for p in loaded {
                    dict[p.id] = p
                }
                await MainActor.run {
                    self.products = dict
                }
            } catch {
                print("[SubscriptionProductsCache] error:", error)
            }
        }
    }

    func product(id: String) -> Product? {
        products[id]
    }
}
