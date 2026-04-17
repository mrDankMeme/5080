import Combine
import OSLog
import SwiftUI

@MainActor
final class PurchaseManager: ObservableObject {
    private let billingProvider: BillingProvider = AdaptyBillingProvider()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Pictory5046", category: "PurchaseManager")

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

    static let shared = PurchaseManager()

    private init() {
        logger.info("PurchaseManager: Initializing billing manager")
        self.purchaseState = .loading
        self.userId = billingProvider.userID()
        self.isSubscribed = billingProvider.hasPremiumAccessSync()
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
            logger.info("PurchaseManager: Fetched \(paywalls.count) paywalls")
            configure(with: paywalls)
        } catch {
            logger.error("PurchaseManager: Failed to load paywalls - \(error.localizedDescription)")
            paywall = nil
            products = []
            tokenPaywall = nil
            tokenProducts = []
            tokenPurchaseError = "Token packs not available. Please check your connection and try again."
            purchaseState = .error("Subscription options not available. Please check your connection and try again.")
            purchaseError = "Subscription options not available. Please check your connection and try again."
        }
    }

    private func configure(with paywalls: [BillingPaywall]) {
        logger.info("PurchaseManager: Configuring paywalls, looking for 'main' identifier")
        guard let paywall = paywalls.first(where: { $0.id == BillingConfig.adaptyMainPlacementID }) ?? paywalls.first else {
            logger.error("PurchaseManager: Paywall with identifier 'main' not found")
            purchaseState = .error("Subscription options not available. Please check your connection and try again.")
            purchaseError = "Subscription options not available. Please check your connection and try again."
            return
        }

        self.paywall = paywall
        products = paywall.products
        logger.info("PurchaseManager: Configured paywall 'main' with \(self.products.count) products")

        if products.isEmpty {
            logger.warning("PurchaseManager: Paywall 'main' has no products!")
            purchaseState = .error("No subscription products available. Please try again later.")
            purchaseError = "No subscription products available. Please try again later."
        } else {
            purchaseState = .ready
            purchaseError = nil
            logger.info("PurchaseManager: Products ready: \(self.products.map { $0.id }.joined(separator: ", "))")
        }

        if let tokenPaywall = paywalls.first(where: { $0.id == BillingConfig.adaptyTokensPlacementID }),
           !tokenPaywall.products.isEmpty
        {
            self.tokenPaywall = tokenPaywall
            tokenProducts = tokenPaywall.products
            tokenPurchaseError = nil
            logger.info("PurchaseManager: Configured paywall 'tokens' with \(self.tokenProducts.count) products")
        } else {
            tokenPaywall = nil
            tokenProducts = []
            tokenPurchaseError = "Token packs are unavailable. Please try again later."
            logger.warning("PurchaseManager: Paywall 'tokens' not found or has no products")
        }
    }

    func makePurchase(product: BillingProduct, completion: @escaping (Bool, String?) -> Void) {
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

    func restorePurchase(completion: @escaping (Bool) -> Void) {
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

    func refreshSubscriptionStatusFromProvider() async {
        let hasAccess = await billingProvider.hasPremiumAccess()
        isSubscribed = hasAccess
    }

    func updateAvailableGenerations(_ value: Int) {
        availableGenerations = max(0, value)
    }

    func updateServicePrices(_ pricesData: ServicePricesData?) {
        servicePricesByKey = pricesData?.pricesByKey ?? [:]
        klingModelPrices = pricesData?.klingPrice ?? []
    }

    func spendGenerations(_ value: Int) {
        guard value > 0 else { return }
        availableGenerations = max(0, availableGenerations - value)
    }

    func trackCurrentPaywallShown(placementID: String = BillingConfig.adaptyMainPlacementID) {
        billingProvider.trackPaywallShown(paywallForPlacement(id: placementID))
    }

    func trackCurrentPaywallClosed(placementID: String = BillingConfig.adaptyMainPlacementID) {
        billingProvider.trackPaywallClosed(paywallForPlacement(id: placementID))
    }
}

private extension PurchaseManager {
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
}

extension PurchaseManager {
    enum GenerationPriceMode: Hashable {
        case template
        case enhance
        case generate(GenerateType)
    }

    private var generationModeToPriceKey: [GenerationPriceMode: String] {
        [
            .template: "effect",
            .enhance: "upscale",
            .generate(.textToImage): "txt2img",
            .generate(.imageToImage): "tools",
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

    var enhanceGenerationPrice: Int {
        generationPriceByMode[.enhance] ?? 0
    }

    func generationPrice(for type: GenerateType) -> Int {
        generationPriceByMode[.generate(type)] ?? 0
    }

    private var generationModeToKlingModel: [GenerationPriceMode: String] {
        [
            .generate(.textToVideo): "kling21master_txt2video",
            .generate(.frameVideo): "kling21master_img2video"
        ]
    }

    var generationVideoPriceByMode: [GenerationPriceMode: Int] {
        var result: [GenerationPriceMode: Int] = [:]
        for (mode, model) in generationModeToKlingModel {
            let price = klingModelPrices
                .first { $0.model == model }?
                .seconds
                .first { $0.duration == 5 }?
                .price ?? 0

            result[mode] = price
        }
        return result
    }

    func generationVideoPrice(for type: GenerateType) -> Int {
        generationVideoPriceByMode[.generate(type)] ?? 0
    }
}
