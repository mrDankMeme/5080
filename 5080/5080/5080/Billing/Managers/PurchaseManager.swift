import SwiftUI
import Combine
import OSLog
import Adapty

@MainActor
final class PurchaseManager: ObservableObject {
    private let billingProvider: BillingProvider
    private let backendService: MiniMaxBackendService

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.arn.5080base44", category: "PurchaseManager")

    enum PurchaseState: Equatable {
        case idle
        case loading
        case ready
        case purchasing
        case error(String)

        static func == (lhs: PurchaseState, rhs: PurchaseState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.ready, .ready), (.purchasing, .purchasing):
                return true
            case (.error(let lhsMsg), .error(let rhsMsg)):
                return lhsMsg == rhsMsg
            default:
                return false
            }
        }
    }

    @Published private(set) var paywall: BillingPaywall?
    @Published private(set) var products: [BillingProduct] = []
    @Published private(set) var tokenPaywall: BillingPaywall?
    @Published private(set) var tokenProducts: [BillingProduct] = []
    @Published private(set) var tokenPurchaseError: String? = nil
    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published var purchaseError: String? = nil
    @Published var failRestoreText: String? = nil
    @Published var userId: String = ""
    @Published private(set) var availableGenerations: Int = 0
    @Published private(set) var activeSubscriptionPlanTitle: String?
    @Published private(set) var servicePricesByKey: [String: Int] = [:]
    @Published private(set) var klingModelPrices: [KlingModelPrice] = []

    @AppStorage("OnBoardEnd") var isOnboardingFinished: Bool = false
    @Published var isShowedPaywall: Bool = false

    var isReady: Bool {
        purchaseState == .ready && !products.isEmpty && paywall != nil
    }

    var isTokensReady: Bool {
        purchaseState != .loading && !tokenProducts.isEmpty && tokenPaywall != nil
    }

    var isLoading: Bool {
        purchaseState == .loading || purchaseState == .purchasing
    }

    @MainActor
    static let shared = PurchaseManager()

    private init() {
        let billingProvider = AdaptyBillingProvider()
        self.billingProvider = billingProvider
        self.backendService = Self.makeBackendService()

        logger.info("PurchaseManager: Initializing billing manager")
        purchaseState = .loading
        self.userId = billingProvider.userID()
        logger.info("PurchaseManager: Using app userId \(self.userId, privacy: .public)")
        self.isSubscribed = billingProvider.hasPremiumAccessSync()
        self.activeSubscriptionPlanTitle = isSubscribed ? "Premium Plan" : nil
        self.isShowedPaywall = !isSubscribed && isOnboardingFinished

        Task {
            await loadPaywalls()
            await refreshSubscriptionStatusFromProvider()
        }
    }

    func loadPaywalls() async {
        logger.info("PurchaseManager: Starting paywall fetch")
        do {
            let paywalls = try await billingProvider.loadPaywalls()
            let fetchedPaywallsDescription = self.paywallDebugDescription(paywalls)
            logger.info(
                "PurchaseManager: Fetched \(paywalls.count) paywalls -> \(fetchedPaywallsDescription, privacy: .public)"
            )
            self.configure(with: paywalls)
        } catch {
            logger.error("PurchaseManager: Failed to load paywalls - \(error.localizedDescription)")
            self.paywall = nil
            self.products = []
            self.tokenPaywall = nil
            self.tokenProducts = []
            self.tokenPurchaseError = "Token packs not available. Please check your connection and try again."
            self.purchaseState = .error("Subscription options not available. Please check your connection and try again.")
            self.purchaseError = "Subscription options not available. Please check your connection and try again."
        }
    }

    private func configure(with paywalls: [BillingPaywall]) {
        let receivedPaywallsDescription = self.paywallDebugDescription(paywalls)
        logger.info(
            "PurchaseManager: Configuring paywalls. received=\(receivedPaywallsDescription, privacy: .public)"
        )
        guard let paywall = paywalls.first(where: { $0.id == BillingConfig.adaptyMainPlacementID }) ?? paywalls.first else {
            logger.error("PurchaseManager: Paywall with identifier 'main' not found")
            purchaseState = .error("Subscription options not available. Please check your connection and try again.")
            purchaseError = "Subscription options not available. Please check your connection and try again."
            return
        }

        self.paywall = paywall
        self.products = paywall.products
        logger.info("PurchaseManager: Configured paywall 'main' with \(self.products.count) products")

        if self.products.isEmpty {
            logger.warning("PurchaseManager: Paywall 'main' has no products!")
            purchaseState = .error("No subscription products available. Please try again later.")
            purchaseError = "No subscription products available. Please try again later."
        } else {
            purchaseState = .ready
            purchaseError = nil
            logger.info("PurchaseManager: Products ready: \(self.products.map { $0.id }.joined(separator: ", "))")
        }

        if let tokenPaywall = paywalls.first(where: { $0.id == BillingConfig.adaptyTokensPlacementID }),
           !tokenPaywall.products.isEmpty {
            self.tokenPaywall = tokenPaywall
            self.tokenProducts = tokenPaywall.products
            self.tokenPurchaseError = nil
            let tokenProductsDescription = self.productDebugDescription(self.tokenProducts)
            logger.info(
                "PurchaseManager: Configured paywall 'tokens' with \(self.tokenProducts.count) products -> \(tokenProductsDescription, privacy: .public)"
            )
        } else {
            self.tokenPaywall = nil
            self.tokenProducts = []
            self.tokenPurchaseError = "Token packs are unavailable. Please try again later."
            logger.warning(
                "PurchaseManager: Paywall 'tokens' not found or has no products. received=\(receivedPaywallsDescription, privacy: .public)"
            )
        }
    }

    func makePurchase(product: BillingProduct, completion: @escaping(Bool, String?) -> Void) {
        guard purchaseState != .purchasing else {
            logger.warning("PurchaseManager: Purchase already in progress, ignoring duplicate request")
            completion(false, "Purchase already in progress")
            return
        }

        guard paywall != nil || tokenPaywall != nil else {
            logger.error("PurchaseManager: Cannot purchase - paywalls not loaded")
            let errorMsg = "Products are not loaded. Please try again."
            purchaseError = errorMsg
            completion(false, errorMsg)
            return
        }

        guard allAvailableProducts.contains(where: { $0.id == product.id }) else {
            logger.error("PurchaseManager: Product \(product.id) not found in available products")
            let errorMsg = "Selected product is not available"
            purchaseError = errorMsg
            completion(false, errorMsg)
            return
        }

        logger.info("PurchaseManager: Starting purchase for product \(product.id)")
        purchaseState = .purchasing
        purchaseError = nil

        Task { @MainActor in
            let result = await billingProvider.purchase(product: product)
            await refreshSubscriptionStatusFromProvider()

            if result.success {
                logger.info("PurchaseManager: Purchase successful for product \(product.id)")
                if product.kind != .subscription,
                   let purchasedTokens = tokenAmount(from: product.id) {
                    let optimisticBalance = max(0, availableGenerations) + purchasedTokens
                    availableGenerations = optimisticBalance
                    logger.info(
                        "PurchaseManager: Applied local token credit \(purchasedTokens) for product \(product.id)"
                    )

                    if let syncedBalance = await syncPurchasedTokensWithBackendIfNeeded(
                        expectedMinimumTokens: optimisticBalance
                    ) {
                        availableGenerations = max(optimisticBalance, syncedBalance)
                        logger.info(
                            "PurchaseManager: Synced token balance from backend after purchase. local=\(optimisticBalance), backend=\(syncedBalance)"
                        )
                    } else {
                        logger.warning(
                            "PurchaseManager: Backend token sync did not return a balance after purchase. Keeping local balance=\(optimisticBalance)"
                        )
                    }
                } else if product.kind != .subscription {
                    logger.warning(
                        "PurchaseManager: Token product purchased but token amount could not be parsed from product id \(product.id)"
                    )
                }
                self.purchaseState = .ready
                self.purchaseError = nil
                self.isShowedPaywall = !self.isSubscribed && self.isOnboardingFinished
                completion(true, nil)
            } else {
                logger.error("PurchaseManager: Purchase failed for product \(product.id)")
                let errorMsg = result.errorMessage ?? "Purchase was not completed. Please try again."
                self.purchaseState = .ready
                self.purchaseError = errorMsg
                completion(false, errorMsg)
            }
        }
    }

    func restorePurchase(completion: @escaping(Bool) -> Void) {
        logger.info("PurchaseManager: Starting restore purchases")
        Task { @MainActor in
            let result = await billingProvider.restorePurchases()
            await refreshSubscriptionStatusFromProvider()

            if result.hasActiveSubscription {
                self.logger.info("PurchaseManager: Restore successful - active subscription found")
                self.failRestoreText = nil
                completion(true)
                return
            }

            self.logger.warning("PurchaseManager: Nothing to restore")
            self.failRestoreText = result.errorMessage ?? "Nothing to restore"
            completion(false)
        }
    }

    func restoreAny() async -> Bool {
        await withCheckedContinuation { continuation in
            restorePurchase { success in
                continuation.resume(returning: success)
            }
        }
    }

    func refreshSubscriptionStatusFromProvider() async {
        let hasAccess = await billingProvider.hasPremiumAccess()
        self.isSubscribed = hasAccess
        self.activeSubscriptionPlanTitle = await resolvedActiveSubscriptionPlanTitle(
            hasAccess: hasAccess
        )
    }

    func updateAvailableGenerations(_ value: Int) {
        availableGenerations = max(0, value)
    }

    func updateServicePrices(_ pricesData: ServicePricesData?) {
        servicePricesByKey = pricesData?.pricesByKey ?? [:]
        klingModelPrices = pricesData?.klingPrice ?? []
    }

    @discardableResult
    func resolveUnifiedUserID() -> String {
        let resolvedUserID = AppUserIdentityConfiguration.resolvedUserID()
        if userId != resolvedUserID {
            userId = resolvedUserID
        }
        return resolvedUserID
    }

    func trackCurrentPaywallShown(placementID: String? = nil) {
        let resolvedPlacementID = placementID ?? BillingConfig.adaptyMainPlacementID
        logger.info("PurchaseManager: Tracking paywall shown for placement \(resolvedPlacementID, privacy: .public)")
        billingProvider.trackPaywallShown(paywallForPlacement(id: resolvedPlacementID))
    }

    func trackCurrentPaywallClosed(placementID: String? = nil) {
        let resolvedPlacementID = placementID ?? BillingConfig.adaptyMainPlacementID
        logger.info("PurchaseManager: Tracking paywall closed for placement \(resolvedPlacementID, privacy: .public)")
        billingProvider.trackPaywallClosed(paywallForPlacement(id: resolvedPlacementID))
    }

    func debugLogTokenPaywallState(context: String) {
        let tokenPaywallID = self.tokenPaywall?.id ?? "nil"
        let tokenProductsDescription = self.productDebugDescription(self.tokenProducts)
        let tokenPurchaseErrorText = self.tokenPurchaseError ?? "nil"
        let isTokensReady = self.isTokensReady

        logger.info(
            "PurchaseManager[\(context, privacy: .public)]: tokenPaywall=\(tokenPaywallID, privacy: .public), tokenProducts=\(tokenProductsDescription, privacy: .public), tokenPurchaseError=\(tokenPurchaseErrorText, privacy: .public), isTokensReady=\(isTokensReady)"
        )
    }
}

private extension PurchaseManager {
    static func makeBackendService() -> MiniMaxBackendService {
        let config = APIConfig(
            baseURL: URL(string: MiniMaxBackendDefaults.baseURLString)!,
            bearerToken: MiniMaxBackendDefaults.bearerToken
        )

        return MiniMaxBackendServiceImpl(
            config: config,
            http: URLSessionHTTPClient()
        )
    }

    var allAvailableProducts: [BillingProduct] {
        products + tokenProducts
    }

    func paywallForPlacement(id: String) -> BillingPaywall? {
        if id == BillingConfig.adaptyTokensPlacementID {
            return tokenPaywall
        }
        if id == BillingConfig.adaptyMainPlacementID {
            return paywall
        }
        return paywall
    }

    func resolvedActiveSubscriptionPlanTitle(hasAccess: Bool) async -> String? {
        guard hasAccess else { return nil }

        do {
            let profile = try await Adapty.getProfile()
            let key = BillingConfig.adaptyAccessLevelKey

            guard let accessLevel = profile.accessLevels[key], accessLevel.isActive else {
                return "Premium Plan"
            }

            return displayPlanTitle(for: accessLevel.vendorProductId)
        } catch {
            return activeSubscriptionPlanTitle ?? "Premium Plan"
        }
    }

    func displayPlanTitle(for productID: String) -> String {
        let normalizedID = productID.lowercased()

        if normalizedID.contains("year") || normalizedID.contains("annual") {
            return "Yearly Plan"
        }

        if normalizedID.contains("month") {
            return "Monthly Plan"
        }

        if normalizedID.contains("week") {
            return "Weekly Plan"
        }

        return "Premium Plan"
    }

    func paywallDebugDescription(_ paywalls: [BillingPaywall]) -> String {
        guard !paywalls.isEmpty else { return "[]" }
        let items = paywalls.map { paywall in
            "\(paywall.id){\(productDebugDescription(paywall.products))}"
        }
        return "[\(items.joined(separator: ", "))]"
    }

    func productDebugDescription(_ products: [BillingProduct]) -> String {
        guard !products.isEmpty else { return "[]" }
        let items = products.map { product in
            "\(product.id)=\(product.localizedPrice)"
        }
        return "[\(items.joined(separator: ", "))]"
    }

    func tokenAmount(from productID: String) -> Int? {
        let parts = productID.split { !$0.isNumber }
        guard let firstNumericChunk = parts.first else {
            return nil
        }
        return Int(firstNumericChunk)
    }

    func syncPurchasedTokensWithBackendIfNeeded(expectedMinimumTokens: Int) async -> Int? {
        let resolvedUserID = resolveUnifiedUserID()
        guard !resolvedUserID.isEmpty else {
            logger.error("PurchaseManager: Unable to sync tokens — resolved userId is empty")
            return nil
        }

        do {
            try await backendService.collectTokens(userId: resolvedUserID)
            logger.info(
                "PurchaseManager: collectTokens request sent for userId \(resolvedUserID, privacy: .public)"
            )
        } catch {
            logger.error(
                "PurchaseManager: collectTokens failed for userId \(resolvedUserID, privacy: .public) - \(error.localizedDescription, privacy: .public)"
            )
        }

        let maxAttempts = 6
        for attempt in 1...maxAttempts {
            do {
                let profile = try await backendService.fetchProfile(userId: resolvedUserID)
                let backendBalance = max(0, profile.availableGenerations)

                if backendBalance >= expectedMinimumTokens || attempt == maxAttempts {
                    logger.info(
                        "PurchaseManager: Backend token balance fetched on attempt \(attempt). expectedMin=\(expectedMinimumTokens), backend=\(backendBalance)"
                    )
                    return backendBalance
                }
            } catch {
                logger.error(
                    "PurchaseManager: Failed to fetch profile during post-purchase sync (attempt \(attempt)) - \(error.localizedDescription, privacy: .public)"
                )
                if attempt == maxAttempts {
                    return nil
                }
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        return nil
    }
}

extension PurchaseManager {
    enum GenerationPriceMode: Hashable {
        case template
        case generate(GenerateType)
    }

    private var generationModeToPriceKey: [GenerationPriceMode: String] {
        [
            .template: "effect",
            .generate(.textToPhoto): "txt2img",
            .generate(.editPhoto): "tools",
            .generate(.animatePhoto): "animation"
        ]
    }

    var generationPriceByMode: [GenerationPriceMode: Int] {
        var result: [GenerationPriceMode: Int] = [:]
        for (mode, key) in generationModeToPriceKey {
            result[mode] = servicePricesByKey[key] ?? 0
        }
        return result
    }

    var templateGenerationPrice: Int {
        generationPriceByMode[.template] ?? 0
    }

    func generationPrice(for type: GenerateType) -> Int {
        generationPriceByMode[.generate(type)] ?? 0
    }
}
