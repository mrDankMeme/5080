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
}

@MainActor
final class DefaultBillingAccessResolver: BillingAccessResolving {
    private let purchaseManager: PurchaseManager

    init(purchaseManager: PurchaseManager) {
        self.purchaseManager = purchaseManager
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
    @Published private(set) var builderPresentation: BuilderPresentationContext?
    @Published private(set) var isSettingsPresented = false
    @Published private(set) var isSubscriptionPaywallPresented = false
    @Published private(set) var isTokensPaywallPresented = false

    let homeViewModel: Base44HomeSceneViewModel
    let settingsViewModel: RootSettingsSceneViewModel

    private let billingAccessResolver: BillingAccessResolving
    private let builderViewModelFactory: BuilderWorkspaceSceneViewModelFactoryProtocol

    init(
        homeViewModel: Base44HomeSceneViewModel,
        settingsViewModel: RootSettingsSceneViewModel,
        billingAccessResolver: BillingAccessResolving,
        builderViewModelFactory: BuilderWorkspaceSceneViewModelFactoryProtocol
    ) {
        self.homeViewModel = homeViewModel
        self.settingsViewModel = settingsViewModel
        self.billingAccessResolver = billingAccessResolver
        self.builderViewModelFactory = builderViewModelFactory
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
        switch billingAccessResolver.destinationForHeaderTap() {
        case .subscription:
            isSubscriptionPaywallPresented = true
            isTokensPaywallPresented = false
        case .tokens:
            isTokensPaywallPresented = true
            isSubscriptionPaywallPresented = false
        }
    }

    func openCreate() {
        guard let launch = homeViewModel.makeCreateLaunch() else {
            return
        }

        builderPresentation = BuilderPresentationContext(launch: launch)
    }

    func openProject(_ project: SiteMakerProjectSummary) {
        builderPresentation = BuilderPresentationContext(
            launch: .existing(project: project)
        )
    }

    func dismissBuilder() {
        builderPresentation = nil
    }

    func refreshProjects() async {
        await homeViewModel.refreshProjects()
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
}
