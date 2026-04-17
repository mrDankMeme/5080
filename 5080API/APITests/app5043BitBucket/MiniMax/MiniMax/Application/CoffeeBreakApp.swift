import SwiftUI
import Swinject
import Adapty
import AdaptyLogger

@main
struct MiniMaxApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private let assembler = AppAssembler.make()
    private var resolver: Resolver { assembler.resolver }

    @StateObject private var purchaseManager: PurchaseManager

    init() {
        let manager = MainActor.assumeIsolated { PurchaseManager.shared }
        _purchaseManager = StateObject(wrappedValue: manager)

        Task {
            do {
                let customerUserID = await MainActor.run { manager.userId }
                let configuration = AdaptyConfiguration
                    .builder(withAPIKey: BillingConfig.adaptyAPIKey)
                    .with(customerUserId: customerUserID)
                    .with(observerMode: false)
                    .with(logLevel: .error)
                    .build()

                try await Adapty.activate(with: configuration)

                if let profileId = try? await Adapty.getProfile().profileId,
                   !profileId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await MainActor.run {
                        manager.userId = profileId
                    }
                }

                await manager.loadPaywalls()
                await manager.refreshSubscriptionStatusFromProvider()
            } catch {
#if DEBUG
                print("[Adapty] activation failed: \(error.localizedDescription)")
#endif
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppFlowView()
                .dismissKeyboardOnTap()
                .environment(\.resolver, resolver)
                .environmentObject(purchaseManager)
                .environment(\.dynamicTypeSize, .medium)
                .task {
                    await syncScheduledNotificationsIfNeeded()
                    await recoverPendingHistoryIfNeeded()
                }
                .onChange(of: scenePhase) { _, newValue in
                    guard newValue == .active else { return }

                    Task {
                        await syncScheduledNotificationsIfNeeded()
                        await recoverPendingHistoryIfNeeded()
                    }
                }
        }
    }

    private func syncScheduledNotificationsIfNeeded() async {
        guard let scheduler = resolver.resolve(OnboardingNotificationsScheduling.self) else { return }
        await scheduler.syncScheduledWeeklyPromptsIfNeeded()
    }

    private func recoverPendingHistoryIfNeeded() async {
        guard let runner = resolver.resolve(PendingHistoryRecoveryRunner.self) else { return }
        await runner.recoverPendingItemsIfNeeded()
    }
}
