import SwiftUI
import Swinject
import Combine
import Adapty

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
                RootTabView()
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
    private let authorizeUserUseCase: AuthorizeUserUseCase
    private let setFreeGenerationsUseCase: SetFreeGenerationsUseCase
    private let addGenerationsUseCase: AddGenerationsUseCase
    private let fetchProfileUseCase: FetchProfileUseCase
    private let purchaseManager: PurchaseManager

    private var startupTask: Task<Void, Never>?
    private var didRunStartupTopUp = false

    init(
        authorizeUserUseCase: AuthorizeUserUseCase,
        setFreeGenerationsUseCase: SetFreeGenerationsUseCase,
        addGenerationsUseCase: AddGenerationsUseCase,
        fetchProfileUseCase: FetchProfileUseCase,
        purchaseManager: PurchaseManager
    ) {
        self.authorizeUserUseCase = authorizeUserUseCase
        self.setFreeGenerationsUseCase = setFreeGenerationsUseCase
        self.addGenerationsUseCase = addGenerationsUseCase
        self.fetchProfileUseCase = fetchProfileUseCase
        self.purchaseManager = purchaseManager
    }

    deinit {
        startupTask?.cancel()
    }

    static var fallback: AppFlowViewModel {
        AppFlowViewModel(
            authorizeUserUseCase: AppFlowFallbackAuthorizeUserUseCase(),
            setFreeGenerationsUseCase: AppFlowFallbackSetFreeGenerationsUseCase(),
            addGenerationsUseCase: AppFlowFallbackAddGenerationsUseCase(),
            fetchProfileUseCase: AppFlowFallbackFetchProfileUseCase(),
            purchaseManager: PurchaseManager.shared
        )
    }

    func onAppear() {
        guard !didRunStartupTopUp else { return }
        didRunStartupTopUp = true

        startupTask = Task { [weak self] in
            await self?.runStartupTopUp()
        }
    }

    private func runStartupTopUp() async {
        let userId = await resolvedUserID()
        let didAuthorize = await authorizeAndSyncBalance(userId: userId) != nil
        if didAuthorize {
            await performDebugStartupTopUpIfNeeded(userId: userId)
        }
        await syncBalanceFromProfile(userId: userId)
    }

    private func resolvedUserID() async -> String {
        if let adaptyProfileId = await fetchAdaptyProfileIDWithRetry() {
            purchaseManager.userId = adaptyProfileId
            return adaptyProfileId
        }

        let fromBilling = purchaseManager.userId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fromBilling.isEmpty {
            return fromBilling
        }

        let key = "backend_shared_user_id"
        let defaults = UserDefaults.standard

        if let existing = defaults.string(forKey: key),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            purchaseManager.userId = existing
            return existing
        }

        let generated = UUID().uuidString
        defaults.set(generated, forKey: key)
        purchaseManager.userId = generated
        return generated
    }

    private func authorizeAndSyncBalance(userId: String) async -> BackendAuthData? {
        do {
            let auth = try await authorizeUserUseCase.execute(userId: userId, gender: "m")
            purchaseManager.updateAvailableGenerations(auth.availableGenerations)
            return auth
        } catch {
            return nil
        }
    }

    private func syncBalanceFromProfile(userId: String) async {
        if let profile = try? await fetchProfileUseCase.execute(userId: userId) {
            purchaseManager.updateAvailableGenerations(profile.availableGenerations)
        }
    }

    private func prepareDebugTariffProductID(userId: String) async -> Int? {
        do {
            try await setFreeGenerationsUseCase.execute(userId: userId)
        } catch {
            // User may not exist yet; continue with authorize/profile refresh below.
        }

        if let auth = await authorizeAndSyncBalance(userId: userId),
           let tariffId = auth.statTariffId,
           tariffId > 0 {
            return tariffId
        }

        if let profile = try? await fetchProfileUseCase.execute(userId: userId) {
            purchaseManager.updateAvailableGenerations(profile.availableGenerations)
            if let tariffId = profile.statTariffId, tariffId > 0 {
                return tariffId
            }
        }

        return nil
    }

    private func performDebugStartupTopUpIfNeeded(userId: String) async {
        #if DEBUG
        guard let productId = await prepareDebugTariffProductID(userId: userId) else { return }

        for _ in 0..<3 {
            guard !Task.isCancelled else { return }

            do {
                try await addGenerationsUseCase.execute(userId: userId, productId: productId)
            } catch {
                continue
            }
        }
        #endif
    }

    private func fetchAdaptyProfileIDWithRetry() async -> String? {
        let maxAttempts = 6
        for attempt in 0..<maxAttempts {
            guard !Task.isCancelled else { return nil }

            if let id = await fetchAdaptyProfileID() {
                return id
            }

            guard attempt < maxAttempts - 1 else { break }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return nil
    }

    private func fetchAdaptyProfileID() async -> String? {
        do {
            let profile = try await Adapty.getProfile()
            let id = profile.profileId.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? nil : id
        } catch {
            return nil
        }
    }
}

private struct AppFlowFallbackAuthorizeUserUseCase: AuthorizeUserUseCase {
    func execute(userId: String, gender: String) async throws -> BackendAuthData {
        BackendAuthData(
            userId: userId,
            availableGenerations: 0,
            isActivePlan: false
        )
    }
}

private struct AppFlowFallbackSetFreeGenerationsUseCase: SetFreeGenerationsUseCase {
    func execute(userId: String) async throws {}
}

private struct AppFlowFallbackAddGenerationsUseCase: AddGenerationsUseCase {
    func execute(userId: String, productId: Int) async throws {}
}

private struct AppFlowFallbackFetchProfileUseCase: FetchProfileUseCase {
    func execute(userId: String) async throws -> BackendProfileData {
        BackendProfileData(
            userId: userId,
            availableGenerations: 0,
            isActivePlan: false
        )
    }
}
