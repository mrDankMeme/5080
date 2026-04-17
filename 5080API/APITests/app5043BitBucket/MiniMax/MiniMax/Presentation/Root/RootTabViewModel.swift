import Combine
import CoreGraphics
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

        return purchaseManager.availableGenerations < max(1, requiredTokens) ? .tokens : nil
    }
}

@MainActor
final class RootTabViewModel: ObservableObject {
    @Published var selectedTab: RootTabItem = .home
    @Published private(set) var isModeSheetPresented = false
    @Published private(set) var isModeSheetVisible = false
    @Published private(set) var modeSheetDragOffset: CGFloat = 0.scale
    @Published private(set) var isTextToVideoFlowPresented = false
    @Published private(set) var isAnimateImageFlowPresented = false
    @Published private(set) var isFrameToVideoFlowPresented = false
    @Published private(set) var isVoiceGenFlowPresented = false
    @Published private(set) var isTranscribeFlowPresented = false
    @Published private(set) var isAIImageFlowPresented = false
    @Published private(set) var isSubscriptionPaywallPresented = false
    @Published private(set) var isTokensPaywallPresented = false

    let homeViewModel: RootHomeSceneViewModel
    let historyViewModel: RootHistorySceneViewModel
    let settingsViewModel: RootSettingsSceneViewModel

    private let billingAccessResolver: BillingAccessResolving
    private(set) var textToVideoLaunchPrompt: String?
    private(set) var animateImageLaunchPrompt: String?
    private(set) var frameToVideoLaunchPrompt: String?
    private(set) var aiImageLaunchPrompt: String?

    init(
        homeViewModel: RootHomeSceneViewModel,
        historyViewModel: RootHistorySceneViewModel,
        settingsViewModel: RootSettingsSceneViewModel,
        billingAccessResolver: BillingAccessResolving
    ) {
        self.homeViewModel = homeViewModel
        self.historyViewModel = historyViewModel
        self.settingsViewModel = settingsViewModel
        self.billingAccessResolver = billingAccessResolver

        self.historyViewModel.configureCallbacks(
            onCreateNew: { [weak self] in
                guard let self else { return }
                self.selectedTab = .home
                self.prepareModeSheetPresentation()
            },
            onRetryFlow: { [weak self] flowKind in
                guard let self else { return }
                self.selectedTab = .home
                self.presentFlow(for: flowKind)
            }
        )

        self.homeViewModel.configureCallbacks(
            onSelectLaunch: { [weak self] request in
                self?.presentHomeLaunch(request)
            },
            onOpenTokensPaywall: { [weak self] in
                self?.presentBillingPaywallForHeaderTap()
            }
        )
    }

    static var fallback: RootTabViewModel {
        RootTabViewModel(
            homeViewModel: RootHomeSceneViewModel(),
            historyViewModel: RootHistorySceneViewModel(historyRepository: InMemoryHistoryRepository()),
            settingsViewModel: RootSettingsSceneViewModel(),
            billingAccessResolver: DefaultBillingAccessResolver(
                purchaseManager: PurchaseManager.shared
            )
        )
    }

    func prepareModeSheetPresentation() {
        if selectedTab != .home {
            selectedTab = .home
        }
        modeSheetDragOffset = 0.scale
        isModeSheetPresented = true
        isModeSheetVisible = false
    }

    func completeModeSheetPresentation() {
        guard isModeSheetPresented else { return }
        isModeSheetVisible = true
    }

    func beginModeSheetDismissal() {
        guard isModeSheetPresented else { return }
        modeSheetDragOffset = 0.scale
        isModeSheetVisible = false
    }

    func completeModeSheetDismissal() {
        modeSheetDragOffset = 0.scale
        isModeSheetVisible = false
        isModeSheetPresented = false
    }

    func updateModeSheetDrag(translationHeight: CGFloat) {
        guard isModeSheetVisible else { return }
        modeSheetDragOffset = max(0.scale, translationHeight)
    }

    func resetModeSheetDrag() {
        modeSheetDragOffset = 0.scale
    }

    func shouldDismissModeSheet(for translationHeight: CGFloat) -> Bool {
        translationHeight > 120.scale
    }

    func presentTextToVideoFlow(prompt: String? = nil) {
        textToVideoLaunchPrompt = sanitizedPrompt(prompt)
        isTextToVideoFlowPresented = true
    }

    func dismissTextToVideoFlow() {
        isTextToVideoFlowPresented = false
        textToVideoLaunchPrompt = nil
    }

    func presentAnimateImageFlow(prompt: String? = nil) {
        animateImageLaunchPrompt = sanitizedPrompt(prompt)
        isAnimateImageFlowPresented = true
    }

    func dismissAnimateImageFlow() {
        isAnimateImageFlowPresented = false
        animateImageLaunchPrompt = nil
    }

    func presentFrameToVideoFlow(prompt: String? = nil) {
        frameToVideoLaunchPrompt = sanitizedPrompt(prompt)
        isFrameToVideoFlowPresented = true
    }

    func dismissFrameToVideoFlow() {
        isFrameToVideoFlowPresented = false
        frameToVideoLaunchPrompt = nil
    }

    func presentVoiceGenFlow() {
        isVoiceGenFlowPresented = true
    }

    func dismissVoiceGenFlow() {
        isVoiceGenFlowPresented = false
    }

    func presentTranscribeFlow() {
        isTranscribeFlowPresented = true
    }

    func dismissTranscribeFlow() {
        isTranscribeFlowPresented = false
    }

    func presentAIImageFlow(prompt: String? = nil) {
        aiImageLaunchPrompt = sanitizedPrompt(prompt)
        isAIImageFlowPresented = true
    }

    func dismissAIImageFlow() {
        isAIImageFlowPresented = false
        aiImageLaunchPrompt = nil
    }

    func presentTokensPaywall() {
        isSubscriptionPaywallPresented = false
        isTokensPaywallPresented = true
    }

    func dismissTokensPaywall() {
        isTokensPaywallPresented = false
    }

    func presentSubscriptionPaywall() {
        isTokensPaywallPresented = false
        isSubscriptionPaywallPresented = true
    }

    func dismissSubscriptionPaywall() {
        isSubscriptionPaywallPresented = false
    }

    private func presentFlow(for kind: HistoryFlowKind) {
        switch kind {
        case .textToVideo:
            presentTextToVideoFlow()
        case .animateImage:
            presentAnimateImageFlow()
        case .frameToVideo:
            presentFrameToVideoFlow()
        case .voiceGen:
            presentVoiceGenFlow()
        case .transcribe:
            presentTranscribeFlow()
        case .aiImage:
            presentAIImageFlow()
        }
    }

    private func presentHomeLaunch(_ request: RootHomeLaunchRequest) {
        selectedTab = .home

        switch request.mode {
        case .textToVideo:
            presentTextToVideoFlow(prompt: request.prompt)
        case .frameToVideo:
            presentFrameToVideoFlow(prompt: request.prompt)
        case .animateImage:
            presentAnimateImageFlow(prompt: request.prompt)
        case .aiImage:
            presentAIImageFlow(prompt: request.prompt)
        }
    }

    private func sanitizedPrompt(_ prompt: String?) -> String? {
        guard let prompt else { return nil }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPrompt.isEmpty ? nil : trimmedPrompt
    }

    private func presentBillingPaywallForHeaderTap() {
        switch billingAccessResolver.destinationForHeaderTap() {
        case .subscription:
            presentSubscriptionPaywall()
        case .tokens:
            presentTokensPaywall()
        }
    }
}
