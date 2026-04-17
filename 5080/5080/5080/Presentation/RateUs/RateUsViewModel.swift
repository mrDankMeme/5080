import Combine
import Foundation

@MainActor
final class RateUsViewModel: ObservableObject {
    @Published private(set) var mailComposerPayload: MailComposerPayload?
    @Published private(set) var isReviewRequested = false

    let navigationTitle = "Rate Us"
    let titleText = "Enjoying your experience?"
    let primaryButtonTitle = "Rate Us"
    let secondaryButtonTitle = "Maybe Later"
    let appStoreURL: URL
    let descriptionText: String

    private let supportMailBuilder: SupportMailComposerBuilding
    private let purchaseManager: PurchaseManager
    private let rateUsScheduler: RateUsScheduler

    init(
        supportMailBuilder: SupportMailComposerBuilding,
        purchaseManager: PurchaseManager,
        rateUsScheduler: RateUsScheduler,
        bundle: Bundle,
        appStoreURL: URL
    ) {
        self.supportMailBuilder = supportMailBuilder
        self.purchaseManager = purchaseManager
        self.rateUsScheduler = rateUsScheduler
        self.appStoreURL = appStoreURL
        self.descriptionText = """
        If you enjoy using \(Self.resolveAppName(bundle: bundle)), would you mind taking a moment to rate it? It won't take more than a minute.
        """
    }

    convenience init() {
        self.init(
            supportMailBuilder: DefaultSupportMailComposerBuilder(
                bundle: .main,
                supportEmail: AppExternalResources.supportEmail
            ),
            purchaseManager: PurchaseManager.shared,
            rateUsScheduler: RateUsScheduler(),
            bundle: .main,
            appStoreURL: AppExternalResources.appStoreURL
        )
    }

    static var fallback: RateUsViewModel {
        RateUsViewModel()
    }

    func handleRateTap() {
        rateUsScheduler.markReviewSubmitted()
        isReviewRequested = true
    }

    func completeReviewRequest() {
        isReviewRequested = false
    }

    func handleMaybeLaterTap() {
        mailComposerPayload = supportMailBuilder.makePayload(
            context: .rateUsMaybeLater,
            metadata: SupportMailMetadata(
                userID: purchaseManager.userId,
                availableTokens: purchaseManager.availableGenerations,
                activePlanTitle: purchaseManager.activeSubscriptionPlanTitle
            )
        )
    }

    func dismissMailComposer() {
        mailComposerPayload = nil
    }
}

private extension RateUsViewModel {
    static func resolveAppName(bundle: Bundle) -> String {
        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let displayName, !displayName.isEmpty {
            return displayName
        }

        let bundleName = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let bundleName, !bundleName.isEmpty {
            return bundleName
        }

        return "5080"
    }
}
