import Combine
import Foundation

enum BillingPaywallDestination {
    case subscription
    case tokens
}

@MainActor
protocol BillingAccessResolving: AnyObject {
    func destinationForHeaderTap() -> BillingPaywallDestination
    func destinationForGeneration(requiredTokens: Int) -> BillingPaywallDestination?
    func refreshBillingState() async
}

@MainActor
final class DefaultBillingAccessResolver: BillingAccessResolving {
    private let purchaseManager: PurchaseManager

    init(purchaseManager: PurchaseManager) {
        self.purchaseManager = purchaseManager
    }

    func refreshBillingState() async {
        await purchaseManager.refreshSubscriptionStatusFromProvider()
    }

    func destinationForHeaderTap() -> BillingPaywallDestination {
        purchaseManager.isSubscribed ? .tokens : .subscription
    }

    func destinationForGeneration(requiredTokens: Int) -> BillingPaywallDestination? {
        guard purchaseManager.isSubscribed else {
            return .subscription
        }

        return purchaseManager.availableGenerations < max(1, requiredTokens)
            ? .tokens
            : nil
    }
}

@MainActor
final class RootTabViewModel: ObservableObject {
    private enum Constants {
        static let createGenerationCost = 1
    }

    @Published private(set) var builderPresentation: BuilderPresentationContext?
    @Published private(set) var sitePreviewViewModel: SitePreviewSceneViewModel?
    @Published private(set) var isSettingsPresented = false
    @Published private(set) var isSubscriptionPaywallPresented = false
    @Published private(set) var isTokensPaywallPresented = false

    let homeViewModel: Base44HomeSceneViewModel
    let settingsViewModel: RootSettingsSceneViewModel

    private let billingAccessResolver: BillingAccessResolving
    private let builderViewModelFactory: BuilderWorkspaceSceneViewModelFactoryProtocol
    private let sitePreviewViewModelFactory: SitePreviewSceneViewModelFactoryProtocol

    init(
        homeViewModel: Base44HomeSceneViewModel,
        settingsViewModel: RootSettingsSceneViewModel,
        billingAccessResolver: BillingAccessResolving,
        builderViewModelFactory: BuilderWorkspaceSceneViewModelFactoryProtocol,
        sitePreviewViewModelFactory: SitePreviewSceneViewModelFactoryProtocol
    ) {
        self.homeViewModel = homeViewModel
        self.settingsViewModel = settingsViewModel
        self.billingAccessResolver = billingAccessResolver
        self.builderViewModelFactory = builderViewModelFactory
        self.sitePreviewViewModelFactory = sitePreviewViewModelFactory
    }

    func loadHomeIfNeeded() async {
        await homeViewModel.loadProjectsIfNeeded()
    }

    func openSettings() {
        isSettingsPresented = true
    }

    func dismissSettings() {
        isSettingsPresented = false
    }

    func openPro() {
        presentPaywall(for: billingAccessResolver.destinationForHeaderTap())
    }

    func openCreate() async {
        guard homeViewModel.canCreate else {
            return
        }

        await billingAccessResolver.refreshBillingState()
        await homeViewModel.refreshCreditsIfNeeded(force: true)

        if let paywallDestination = billingAccessResolver.destinationForGeneration(
            requiredTokens: Constants.createGenerationCost
        ) {
            #if DEBUG
            print(
                "[Base44][CreateGate] Blocked create. destination=\(String(describing: paywallDestination)), isSubscribed=\(homeViewModel.isSubscribed), credits=\(homeViewModel.availableCredits)"
            )
            #endif
            presentPaywall(for: paywallDestination)
            return
        }

        guard let launch = homeViewModel.makeCreateLaunch() else {
            return
        }

        sitePreviewViewModel = nil
        builderPresentation = BuilderPresentationContext(launch: launch)
    }

    func openProject(_ project: SiteMakerProjectSummary) {
        if homeViewModel.isProjectBusy(project.id) {
            sitePreviewViewModel = nil
            builderPresentation = BuilderPresentationContext(launch: .existing(project: project))
            return
        }

        if let previewViewModel = sitePreviewViewModelFactory.make(project: project) {
            builderPresentation = nil
            sitePreviewViewModel = previewViewModel
            return
        }

        sitePreviewViewModel = nil
        builderPresentation = BuilderPresentationContext(launch: .existing(project: project))
    }

    func dismissBuilder() {
        builderPresentation = nil
    }

    func dismissSitePreview() {
        sitePreviewViewModel = nil
    }

    func refreshProjects() async {
        await homeViewModel.refreshContent()
    }

    func makeBuilderViewModel(for launch: BuilderSceneLaunch) -> BuilderWorkspaceSceneViewModel {
        builderViewModelFactory.make(launch: launch)
    }

    func dismissSubscriptionPaywall() {
        isSubscriptionPaywallPresented = false
    }

    func dismissTokensPaywall() {
        isTokensPaywallPresented = false
    }

    private func presentPaywall(for destination: BillingPaywallDestination) {
        switch destination {
        case .subscription:
            isSubscriptionPaywallPresented = true
            isTokensPaywallPresented = false
        case .tokens:
            isTokensPaywallPresented = true
            isSubscriptionPaywallPresented = false
        }
    }
}
