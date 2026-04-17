import Adapty
import Foundation
import StoreKit

@MainActor
final class AdaptyBillingProvider: BillingProvider {
    private enum Constants {
        static let fallbackUserIDKey = "adapty_fallback_user_id"
        static let cachedSubscribedKey = "adapty_cached_is_subscribed"
    }

    func loadPaywalls() async throws -> [BillingPaywall] {
        _ = await refreshSubscriptionFromProfile()

        let mainPlacement = try await loadPlacement(id: BillingConfig.adaptyMainPlacementID)
        let mainPaywall = try buildPaywall(
            from: mainPlacement,
            id: BillingConfig.adaptyMainPlacementID,
            allowedProductIDs: BillingConfig.subscriptionProductIDs,
            productKind: .subscription
        )

        var resultPaywalls: [BillingPaywall] = [mainPaywall]

        if let tokensPlacement = try? await loadPlacement(id: BillingConfig.adaptyTokensPlacementID),
           let tokensPaywall = try? buildPaywall(
               from: tokensPlacement,
               id: BillingConfig.adaptyTokensPlacementID,
               allowedProductIDs: BillingConfig.tokenProductIDs,
               productKind: .unknown
           )
        {
            resultPaywalls.append(tokensPaywall)
        }

        return resultPaywalls
    }

    func purchase(product: BillingProduct) async -> PurchaseResult {
        guard let adaptyProduct = await resolveAdaptyProduct(from: product) else {
            return PurchaseResult(
                success: false,
                isSubscriptionActive: false,
                purchasedProductID: nil,
                transactionID: nil,
                errorMessage: "Selected product is not available"
            )
        }

        do {
            let purchaseResult = try await Adapty.makePurchase(product: adaptyProduct)
            switch purchaseResult {
            case .userCancelled:
                let hasAccess = await refreshSubscriptionFromProfile()
                return PurchaseResult(
                    success: false,
                    isSubscriptionActive: hasAccess,
                    purchasedProductID: nil,
                    transactionID: nil,
                    errorMessage: "Purchase cancelled"
                )
            case .pending:
                let hasAccess = await refreshSubscriptionFromProfile()
                return PurchaseResult(
                    success: false,
                    isSubscriptionActive: hasAccess,
                    purchasedProductID: nil,
                    transactionID: nil,
                    errorMessage: "Purchase pending approval"
                )
            case .success(let profile, _):
                let key = BillingConfig.adaptyAccessLevelKey
                let hasAccess = profile.accessLevels[key]?.isActive == true
                UserDefaults.standard.set(hasAccess, forKey: Constants.cachedSubscribedKey)
                let purchaseSucceeded: Bool
                if product.kind == .subscription {
                    purchaseSucceeded = hasAccess
                } else {
                    purchaseSucceeded = true
                }
                return PurchaseResult(
                    success: purchaseSucceeded,
                    isSubscriptionActive: hasAccess,
                    purchasedProductID: product.id,
                    transactionID: transactionID(from: purchaseResult),
                    errorMessage: purchaseSucceeded ? nil : "Subscription is not active"
                )
            }
        } catch {
            return PurchaseResult(
                success: false,
                isSubscriptionActive: hasPremiumAccessSync(),
                purchasedProductID: nil,
                transactionID: nil,
                errorMessage: String(describing: error)
            )
        }
    }

    func restorePurchases() async -> RestoreResult {
        do {
            _ = try await Adapty.restorePurchases()
            let hasAccess = await refreshSubscriptionFromProfile()
            return RestoreResult(
                success: hasAccess,
                hasActiveSubscription: hasAccess,
                restoredProductIDs: hasAccess ? BillingConfig.subscriptionProductIDs : [],
                errorMessage: hasAccess ? nil : "Nothing to restore"
            )
        } catch {
            return RestoreResult(
                success: false,
                hasActiveSubscription: hasPremiumAccessSync(),
                restoredProductIDs: [],
                errorMessage: String(describing: error)
            )
        }
    }

    func hasPremiumAccessSync() -> Bool {
        UserDefaults.standard.bool(forKey: Constants.cachedSubscribedKey)
    }

    func hasPremiumAccess() async -> Bool {
        await refreshSubscriptionFromProfile()
    }

    func userID() -> String {
        if let saved = UserDefaults.standard.string(forKey: Constants.fallbackUserIDKey), !saved.isEmpty {
            return saved
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: Constants.fallbackUserIDKey)
        return generated
    }
}

private extension AdaptyBillingProvider {
    func sortProducts(lhs: BillingProduct, rhs: BillingProduct) -> Bool {
        let lhsRank = periodRank(lhs.id)
        let rhsRank = periodRank(rhs.id)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        return lhs.price < rhs.price
    }

    func periodRank(_ productID: String) -> Int {
        let id = productID.lowercased()
        if id.contains("week") { return 0 }
        if id.contains("month") { return 1 }
        if id.contains("year") { return 2 }
        return 3
    }

    func transactionID(from result: AdaptyPurchaseResult) -> String? {
        if #available(iOS 15.0, *), let sk2ID = result.sk2Transaction?.id {
            return String(sk2ID)
        }
        return result.sk1Transaction?.transactionIdentifier
    }

    func refreshSubscriptionFromProfile() async -> Bool {
        do {
            let profile = try await Adapty.getProfile()
            let key = BillingConfig.adaptyAccessLevelKey
            let isActive = profile.accessLevels[key]?.isActive == true
            UserDefaults.standard.set(isActive, forKey: Constants.cachedSubscribedKey)
            return isActive
        } catch {
            return hasPremiumAccessSync()
        }
    }

    func loadPlacement(id: String) async throws -> (paywall: AdaptyPaywall, products: [AdaptyPaywallProduct]) {
        do {
            let paywall = try await Adapty.getPaywall(placementId: id)
            let products = try await Adapty.getPaywallProducts(paywall: paywall)
            return (paywall, products)
        } catch {
            let paywall = try await Adapty.getPaywallForDefaultAudience(placementId: id)
            let products = try await Adapty.getPaywallProducts(paywall: paywall)
            return (paywall, products)
        }
    }

    func buildPaywall(
        from placement: (paywall: AdaptyPaywall, products: [AdaptyPaywallProduct]),
        id paywallID: String,
        allowedProductIDs: [String],
        productKind: BillingProductKind
    ) throws -> BillingPaywall {
        let allProducts = placement.products.map {
            mapBillingProduct($0, paywallID: paywallID, kind: productKind)
        }
        let allowedIDs = Set(allowedProductIDs.map { $0.lowercased() })

        let filtered: [BillingProduct]
        if allowedIDs.isEmpty {
            filtered = allProducts.sorted(by: sortProducts)
        } else {
            filtered = allowedProductIDs.compactMap { id in
                allProducts.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }
            }
        }

        guard !filtered.isEmpty else {
            throw NSError(
                domain: "AdaptyBillingProvider",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No Adapty products loaded for placement '\(paywallID)'"]
            )
        }

        return BillingPaywall(id: paywallID, products: filtered, sourcePaywall: placement.paywall)
    }

    func mapBillingProduct(
        _ product: AdaptyPaywallProduct,
        paywallID: String,
        kind: BillingProductKind = .subscription
    ) -> BillingProduct {
        BillingProduct(
            id: product.vendorProductId,
            paywallID: paywallID,
            kind: kind,
            price: product.price,
            localizedPrice: resolvedLocalizedPrice(from: product),
            periodTitle: resolvedPeriodTitle(from: product.vendorProductId),
            currencyCode: product.currencyCode,
            priceRegionCode: product.regionCode,
            isTrial: false,
            sourceProduct: product
        )
    }

    func resolveAdaptyProduct(from product: BillingProduct) async -> AdaptyPaywallProduct? {
        if let source = product.sourceProduct as? AdaptyPaywallProduct {
            return source
        }

        let allPlacementIDs = [BillingConfig.adaptyMainPlacementID, BillingConfig.adaptyTokensPlacementID] + BillingConfig.adaptyFallbackPlacementIDs
        let placementIDs = Array(NSOrderedSet(array: allPlacementIDs)) as? [String] ?? allPlacementIDs

        for placementID in placementIDs {
            if let paywall = try? await Adapty.getPaywall(placementId: placementID),
               let products = try? await Adapty.getPaywallProducts(paywall: paywall),
               let found = products.first(where: { $0.vendorProductId == product.id })
            {
                return found
            }
        }
        return nil
    }

    func resolvedLocalizedPrice(from product: AdaptyPaywallProduct) -> String {
        let trimmed = product.localizedPrice?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        return NSDecimalNumber(decimal: product.price).stringValue
    }

    func resolvedPeriodTitle(from productID: String) -> String? {
        let id = productID.lowercased()
        if id.contains("week") { return "week" }
        if id.contains("month") { return "month" }
        if id.contains("year") { return "year" }
        return nil
    }
}
