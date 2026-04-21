import Foundation
import Adapty
import OSLog
import StoreKit

@MainActor
final class AdaptyBillingProvider: BillingProvider {
    private enum Constants {
        static let cachedSubscribedKey = "adapty_cached_is_subscribed"
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yev5080base44",
        category: "AdaptyBillingProvider"
    )

    func loadPaywalls() async throws -> [BillingPaywall] {
        logger.info(
            "AdaptyBillingProvider: Starting paywall load. main=\(BillingConfig.adaptyMainPlacementID, privacy: .public), tokens=\(BillingConfig.adaptyTokensPlacementID, privacy: .public), fallback=\(BillingConfig.adaptyFallbackPlacementIDs.joined(separator: ", "), privacy: .public)"
        )
        _ = await refreshSubscriptionFromProfile()

        let mainPlacement = try await loadPlacement(id: BillingConfig.adaptyMainPlacementID)
        let mainPaywall = try buildPaywall(
            from: mainPlacement,
            id: BillingConfig.adaptyMainPlacementID,
            allowedProductIDs: BillingConfig.subscriptionProductIDs,
            productKind: .subscription
        )
        let mainProductsDescription = self.productIDsDescription(from: mainPaywall.products)
        logger.info(
            "AdaptyBillingProvider: Main paywall resolved with products: \(mainProductsDescription, privacy: .public)"
        )

        var resultPaywalls: [BillingPaywall] = [mainPaywall]

        if let tokensPaywall = await loadTokenPaywall(
            mainPlacement: mainPlacement
        ) {
            resultPaywalls.append(tokensPaywall)
            let tokenProductsDescription = self.productIDsDescription(from: tokensPaywall.products)
            logger.info(
                "AdaptyBillingProvider: Tokens paywall resolved with products: \(tokenProductsDescription, privacy: .public)"
            )
        } else {
            logger.warning("AdaptyBillingProvider: Tokens paywall was not resolved")
        }

        return resultPaywalls
    }

    func purchase(product: BillingProduct) async -> PurchaseResult {
        if let storeKitProduct = product.sourceProduct as? Product {
            return await purchaseStoreKitProduct(
                storeKitProduct,
                billingProductID: product.id
            )
        }

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
        let resolvedUserID = AppUserIdentityConfiguration.resolvedUserID()
        logger.info(
            "AdaptyBillingProvider: Resolved customerUserId=\(resolvedUserID, privacy: .public)"
        )
        return resolvedUserID
    }

    func trackPaywallShown(_ paywall: BillingPaywall?) {
        guard let adaptyPaywall = paywall?.sourcePaywall as? AdaptyPaywall else { return }
        Adapty.logShowPaywall(adaptyPaywall)
    }

    func trackPaywallClosed(_ paywall: BillingPaywall?) {
        guard let adaptyPaywall = paywall?.sourcePaywall as? AdaptyPaywall else { return }
        Adapty.logShowPaywall(adaptyPaywall)
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
            let syncedUserID = AppUserIdentityConfiguration.synchronizePersistedUserID(
                profile.customerUserId ?? AppUserIdentityConfiguration.resolvedUserID()
            )
            let key = BillingConfig.adaptyAccessLevelKey
            let isActive = profile.accessLevels[key]?.isActive == true
            UserDefaults.standard.set(isActive, forKey: Constants.cachedSubscribedKey)
            logger.info(
                "AdaptyBillingProvider: Refreshed profile. rawProfileId=\(profile.profileId, privacy: .public), customerUserId=\((profile.customerUserId ?? "nil"), privacy: .public), syncedAppUserId=\((syncedUserID ?? AppUserIdentityConfiguration.resolvedUserID()), privacy: .public), accessLevelKey=\(key, privacy: .public), isActive=\(isActive)"
            )
            return isActive
        } catch {
            logger.error("AdaptyBillingProvider: Failed to refresh profile - \(String(describing: error), privacy: .public)")
            return hasPremiumAccessSync()
        }
    }

    func loadPlacement(id: String) async throws -> (paywall: AdaptyPaywall, products: [AdaptyPaywallProduct]) {
        logger.info("AdaptyBillingProvider: Loading placement \(id, privacy: .public) via getPaywall")
        do {
            let paywall = try await Adapty.getPaywall(placementId: id)
            let products = try await Adapty.getPaywallProducts(paywall: paywall)
            let vendorProductIDs = self.vendorProductIDsDescription(from: products)
            logger.info(
                "AdaptyBillingProvider: Placement \(id, privacy: .public) loaded via getPaywall. products=\(vendorProductIDs, privacy: .public)"
            )
            return (paywall, products)
        } catch {
            logger.error(
                "AdaptyBillingProvider: getPaywall failed for placement \(id, privacy: .public) - \(String(describing: error), privacy: .public). Retrying with default audience"
            )
            let paywall = try await Adapty.getPaywallForDefaultAudience(placementId: id)
            let products = try await Adapty.getPaywallProducts(paywall: paywall)
            let vendorProductIDs = self.vendorProductIDsDescription(from: products)
            logger.info(
                "AdaptyBillingProvider: Placement \(id, privacy: .public) loaded via default audience. products=\(vendorProductIDs, privacy: .public)"
            )
            return (paywall, products)
        }
    }

    func loadTokenPaywall(
        mainPlacement: (paywall: AdaptyPaywall, products: [AdaptyPaywallProduct])
    ) async -> BillingPaywall? {
        let placementIDs = deduplicatedPlacementIDs(
            primary: BillingConfig.adaptyTokensPlacementID,
            fallback: BillingConfig.adaptyFallbackPlacementIDs + [BillingConfig.adaptyMainPlacementID]
        )
        logger.info(
            "AdaptyBillingProvider: Resolving token paywall across placements: \(placementIDs.joined(separator: ", "), privacy: .public)"
        )

        for placementID in placementIDs {
            let placement: (paywall: AdaptyPaywall, products: [AdaptyPaywallProduct])

            if placementID == BillingConfig.adaptyMainPlacementID {
                placement = mainPlacement
                let vendorProductIDs = self.vendorProductIDsDescription(from: placement.products)
                logger.info(
                    "AdaptyBillingProvider: Reusing already loaded main placement for token lookup. products=\(vendorProductIDs, privacy: .public)"
                )
            } else if let loadedPlacement = try? await loadPlacement(id: placementID) {
                placement = loadedPlacement
            } else {
                logger.warning("AdaptyBillingProvider: Failed to load placement \(placementID, privacy: .public) during token lookup")
                continue
            }

            if let tokenPaywall = buildTokenPaywall(
                from: placement,
                sourcePlacementID: placementID
            ) {
                return tokenPaywall
            }
        }

        #if DEBUG
        if let localStoreKitPaywall = await loadLocalStoreKitTokenPaywall() {
            logger.info("AdaptyBillingProvider: Falling back to local StoreKit token products")
            return localStoreKitPaywall
        }
        #endif

        logger.warning("AdaptyBillingProvider: Token products were not found in any configured placement")
        return nil
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
        let allProductsDescription = self.productIDsDescription(from: allProducts)
        let filteredProductsDescription = self.productIDsDescription(from: filtered)
        let expectedIDsDescription = allowedProductIDs.joined(separator: ", ")

        logger.info(
            "AdaptyBillingProvider: Building paywall \(paywallID, privacy: .public). allProducts=\(allProductsDescription, privacy: .public), expected=\(expectedIDsDescription, privacy: .public), filtered=\(filteredProductsDescription, privacy: .public)"
        )

        guard !filtered.isEmpty else {
            logger.error(
                "AdaptyBillingProvider: No filtered products for paywall \(paywallID, privacy: .public). allProducts=\(allProductsDescription, privacy: .public), expected=\(expectedIDsDescription, privacy: .public)"
            )
            throw NSError(
                domain: "AdaptyBillingProvider",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No Adapty products loaded for placement '\(paywallID)'"]
            )
        }

        return BillingPaywall(id: paywallID, products: filtered, sourcePaywall: placement.paywall)
    }

    func buildTokenPaywall(
        from placement: (paywall: AdaptyPaywall, products: [AdaptyPaywallProduct]),
        sourcePlacementID: String
    ) -> BillingPaywall? {
        let allProducts = placement.products.map {
            mapBillingProduct(
                $0,
                paywallID: BillingConfig.adaptyTokensPlacementID,
                kind: .unknown
            )
        }

        let exactMatches = BillingConfig.tokenProductIDs.compactMap { allowedID in
            allProducts.first { $0.id.caseInsensitiveCompare(allowedID) == .orderedSame }
        }

        let heuristicMatches = allProducts
            .filter { isLikelyTokenProductID($0.id) }
            .sorted(by: sortTokenProducts)
        let allTokenCandidatesDescription = self.productIDsDescription(from: allProducts)
        let exactMatchesDescription = self.productIDsDescription(from: exactMatches)
        let heuristicMatchesDescription = self.productIDsDescription(from: heuristicMatches)

        logger.info(
            "AdaptyBillingProvider: Token candidates from placement \(sourcePlacementID, privacy: .public). all=\(allTokenCandidatesDescription, privacy: .public), exact=\(exactMatchesDescription, privacy: .public), heuristic=\(heuristicMatchesDescription, privacy: .public)"
        )

        let resolvedProducts: [BillingProduct]
        if exactMatches.count == BillingConfig.tokenProductIDs.count {
            resolvedProducts = exactMatches
        } else if heuristicMatches.count > exactMatches.count {
            resolvedProducts = heuristicMatches
            logger.info(
                "AdaptyBillingProvider: Using token heuristic for placement \(sourcePlacementID, privacy: .public) with \(heuristicMatches.count) products"
            )
        } else {
            resolvedProducts = exactMatches
        }

        guard !resolvedProducts.isEmpty else {
            logger.warning(
                "AdaptyBillingProvider: No token products resolved for placement \(sourcePlacementID, privacy: .public). expected=\(BillingConfig.tokenProductIDs.joined(separator: ", "), privacy: .public)"
            )
            return nil
        }

        logger.info(
            "AdaptyBillingProvider: Loaded \(resolvedProducts.count) token products from placement \(sourcePlacementID, privacy: .public)"
        )

        return BillingPaywall(
            id: BillingConfig.adaptyTokensPlacementID,
            products: resolvedProducts,
            sourcePaywall: placement.paywall
        )
    }

    func mapBillingProduct(
        _ product: AdaptyPaywallProduct,
        paywallID: String,
        kind: BillingProductKind = .subscription
    ) -> BillingProduct {
        let resolvedPeriod = resolvedBillingPeriod(from: product.subscriptionPeriod)

        return BillingProduct(
            id: product.vendorProductId,
            paywallID: paywallID,
            kind: kind,
            price: product.price,
            localizedPrice: resolvedLocalizedPrice(from: product),
            period: resolvedPeriod,
            periodTitle: resolvedPeriodTitle(from: resolvedPeriod, fallbackProductID: product.vendorProductId),
            currencyCode: product.currencyCode,
            priceRegionCode: product.regionCode,
            isTrial: false,
            sourceProduct: product
        )
    }

    func mapBillingProduct(
        _ product: Product,
        paywallID: String,
        kind: BillingProductKind = .unknown
    ) -> BillingProduct {
        let resolvedPeriod = resolvedBillingPeriod(from: product.subscription?.subscriptionPeriod)

        return BillingProduct(
            id: product.id,
            paywallID: paywallID,
            kind: kind,
            price: product.price,
            localizedPrice: product.displayPrice,
            period: resolvedPeriod,
            periodTitle: resolvedPeriodTitle(from: resolvedPeriod, fallbackProductID: product.id),
            currencyCode: nil,
            priceRegionCode: nil,
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
               let found = products.first(where: { $0.vendorProductId == product.id }) {
                logger.info(
                    "AdaptyBillingProvider: Resolved source product \(product.id, privacy: .public) in placement \(placementID, privacy: .public)"
                )
                return found
            }
        }
        logger.error(
            "AdaptyBillingProvider: Failed to resolve source product \(product.id, privacy: .public) in placements \(placementIDs.joined(separator: ", "), privacy: .public)"
        )
        return nil
    }

    func resolvedLocalizedPrice(from product: AdaptyPaywallProduct) -> String {
        let trimmed = product.localizedPrice?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        return NSDecimalNumber(decimal: product.price).stringValue
    }

    func resolvedBillingPeriod(from period: AdaptySubscriptionPeriod?) -> BillingPeriod? {
        guard let period else { return nil }

        return BillingPeriod(
            unit: resolvedBillingPeriodUnit(from: period.unit),
            numberOfUnits: period.numberOfUnits
        )
    }

    func resolvedBillingPeriod(from period: Product.SubscriptionPeriod?) -> BillingPeriod? {
        guard let period else { return nil }

        return BillingPeriod(
            unit: resolvedBillingPeriodUnit(from: period.unit),
            numberOfUnits: period.value
        )
    }

    func resolvedBillingPeriodUnit(from unit: AdaptySubscriptionPeriod.Unit) -> BillingPeriodUnit {
        switch unit {
        case .day:
            return .day
        case .week:
            return .week
        case .month:
            return .month
        case .year:
            return .year
        case .unknown:
            return .unknown
        }
    }

    func resolvedBillingPeriodUnit(from unit: Product.SubscriptionPeriod.Unit) -> BillingPeriodUnit {
        switch unit {
        case .day:
            return .day
        case .week:
            return .week
        case .month:
            return .month
        case .year:
            return .year
        @unknown default:
            return .unknown
        }
    }

    func resolvedPeriodTitle(from period: BillingPeriod?, fallbackProductID productID: String) -> String? {
        if let period {
            switch period.unit {
            case .day:
                return "day"
            case .week:
                return "week"
            case .month:
                return "month"
            case .year:
                return "year"
            case .unknown:
                break
            }
        }

        let id = productID.lowercased()
        if id.contains("week") { return "week" }
        if id.contains("month") { return "month" }
        if id.contains("year") { return "year" }
        return nil
    }

    func deduplicatedPlacementIDs(primary: String, fallback: [String]) -> [String] {
        let allIDs = [primary] + fallback
        return Array(NSOrderedSet(array: allIDs)) as? [String] ?? allIDs
    }

    func sortTokenProducts(lhs: BillingProduct, rhs: BillingProduct) -> Bool {
        let lhsTokens = tokenAmount(from: lhs.id) ?? .max
        let rhsTokens = tokenAmount(from: rhs.id) ?? .max

        if lhsTokens != rhsTokens {
            return lhsTokens < rhsTokens
        }

        return lhs.price < rhs.price
    }

    func isLikelyTokenProductID(_ productID: String) -> Bool {
        let normalizedID = productID.lowercased()
        return normalizedID.contains("token") && tokenAmount(from: productID) != nil
    }

    func tokenAmount(from productID: String) -> Int? {
        let parts = productID.split { !$0.isNumber }
        guard let firstNumericChunk = parts.first else {
            return nil
        }
        return Int(firstNumericChunk)
    }

    func loadLocalStoreKitTokenPaywall() async -> BillingPaywall? {
        do {
            let products = try await Product.products(for: BillingConfig.tokenProductIDs)
            let orderedProducts = BillingConfig.tokenProductIDs.compactMap { expectedID in
                products.first { $0.id.caseInsensitiveCompare(expectedID) == .orderedSame }
            }
            let resolvedProducts = (orderedProducts.isEmpty ? products : orderedProducts)
                .map {
                    mapBillingProduct(
                        $0,
                        paywallID: BillingConfig.adaptyTokensPlacementID,
                        kind: .unknown
                    )
                }
                .sorted(by: sortTokenProducts)

            guard !resolvedProducts.isEmpty else {
                return nil
            }

            let tokenProductsDescription = productIDsDescription(from: resolvedProducts)
            logger.info(
                "AdaptyBillingProvider: Local StoreKit token products resolved: \(tokenProductsDescription, privacy: .public)"
            )

            return BillingPaywall(
                id: BillingConfig.adaptyTokensPlacementID,
                products: resolvedProducts,
                sourcePaywall: nil
            )
        } catch {
            logger.error(
                "AdaptyBillingProvider: Failed local StoreKit token fallback - \(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    func purchaseStoreKitProduct(
        _ product: Product,
        billingProductID: String
    ) async -> PurchaseResult {
        do {
            let purchaseResult = try await product.purchase()
            switch purchaseResult {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return PurchaseResult(
                        success: true,
                        isSubscriptionActive: hasPremiumAccessSync(),
                        purchasedProductID: billingProductID,
                        transactionID: String(transaction.id),
                        errorMessage: nil
                    )
                case .unverified(_, let error):
                    return PurchaseResult(
                        success: false,
                        isSubscriptionActive: hasPremiumAccessSync(),
                        purchasedProductID: nil,
                        transactionID: nil,
                        errorMessage: error.localizedDescription
                    )
                }
            case .pending:
                return PurchaseResult(
                    success: false,
                    isSubscriptionActive: hasPremiumAccessSync(),
                    purchasedProductID: nil,
                    transactionID: nil,
                    errorMessage: "Purchase pending approval"
                )
            case .userCancelled:
                return PurchaseResult(
                    success: false,
                    isSubscriptionActive: hasPremiumAccessSync(),
                    purchasedProductID: nil,
                    transactionID: nil,
                    errorMessage: "Purchase cancelled"
                )
            @unknown default:
                return PurchaseResult(
                    success: false,
                    isSubscriptionActive: hasPremiumAccessSync(),
                    purchasedProductID: nil,
                    transactionID: nil,
                    errorMessage: "Purchase failed"
                )
            }
        } catch {
            return PurchaseResult(
                success: false,
                isSubscriptionActive: hasPremiumAccessSync(),
                purchasedProductID: nil,
                transactionID: nil,
                errorMessage: error.localizedDescription
            )
        }
    }

    func productIDsDescription(from products: [BillingProduct]) -> String {
        guard !products.isEmpty else { return "[]" }
        return "[\(products.map(\.id).joined(separator: ", "))]"
    }

    func vendorProductIDsDescription(from products: [AdaptyPaywallProduct]) -> String {
        guard !products.isEmpty else { return "[]" }
        return "[\(products.map(\.vendorProductId).joined(separator: ", "))]"
    }
}
