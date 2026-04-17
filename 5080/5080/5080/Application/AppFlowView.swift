import SwiftUI
import Swinject
import Combine

struct AppFlowView: View {
    @Environment(\.resolver) private var resolver

    var body: some View {
        AppFlowContentView(
            viewModel: resolver.resolve(AppFlowViewModel.self) ?? .fallback,
            onboardingViewModel: resolver.resolve(OnboardingViewModel.self) ?? .fallback
        )
    }
}

private struct AppFlowContentView: View {
    @Environment(\.resolver) private var resolver
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @AppStorage("OnBoardEnd") private var isOnboardingFinished: Bool = false
    @AppStorage("InitialPaywallCompleted") private var isInitialPaywallCompleted: Bool = false

    @StateObject private var viewModel: AppFlowViewModel
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @State private var isLoaderFinished = false

    init(
        viewModel: AppFlowViewModel,
        onboardingViewModel: OnboardingViewModel
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _onboardingViewModel = StateObject(wrappedValue: onboardingViewModel)
    }

    private var isBillingReady: Bool {
        purchaseManager.purchaseState != .loading
    }

    private var shouldShowInitialPaywall: Bool {
        isOnboardingFinished && !isInitialPaywallCompleted && !purchaseManager.isSubscribed
    }

    var body: some View {
        Group {
            if !isLoaderFinished || !isBillingReady {
                LoaderView {
                    isLoaderFinished = true
                }
            } else if !isOnboardingFinished {
                OnboardingView(vm: onboardingViewModel) {
                    isOnboardingFinished = true
                    isInitialPaywallCompleted = true
                }
            } else if shouldShowInitialPaywall {
                PaywallView {
                    isInitialPaywallCompleted = true
                }
            } else {
                RootTabView(
                    viewModel: resolver.resolve(RootTabViewModel.self)!
                )
            }
        }
        .preferredColorScheme(isOnboardingFinished ? .light : nil)
        .onChange(of: purchaseManager.isSubscribed) { _, isSubscribed in
            if isSubscribed {
                isInitialPaywallCompleted = true
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

@MainActor
final class AppFlowViewModel: ObservableObject {
    private var didPrepareState = false

    init(purchaseManager: PurchaseManager) {}

    static var fallback: AppFlowViewModel {
        AppFlowViewModel(purchaseManager: PurchaseManager.shared)
    }

    func onAppear() {
        guard !didPrepareState else { return }
        didPrepareState = true
    }
}
