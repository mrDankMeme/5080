import SwiftUI
import Swinject
import Adapty
import AdaptyLogger

@main
struct App5080: App {
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
                let customerUserID = AppUserIdentityConfiguration.resolvedUserID()
                await MainActor.run {
                    manager.userId = customerUserID
                }

                #if DEBUG
                print("[Adapty] activating with customerUserId=\(customerUserID)")
                #endif

                let configuration = AdaptyConfiguration
                    .builder(withAPIKey: BillingConfig.adaptyAPIKey)
                    .with(customerUserId: customerUserID)
                    .with(observerMode: false)
                    .with(logLevel: .error)
                    .build()

                try await Adapty.activate(with: configuration)

                if let profile = try? await Adapty.getProfile(),
                   let resolvedCustomerUserID = AppUserIdentityConfiguration.synchronizePersistedUserID(
                    profile.customerUserId ?? customerUserID
                   ) {
                    await MainActor.run {
                        manager.userId = resolvedCustomerUserID
                    }

                    #if DEBUG
                    print("[Adapty] raw profileId after activation=\(profile.profileId)")
                    print("[Adapty] raw customerUserId after activation=\(profile.customerUserId ?? "nil")")
                    print("[Adapty] synced app userId after activation=\(resolvedCustomerUserID)")
                    #endif
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

enum AppUserIdentityConfiguration {
    static let sharedUserIDKey = "backend_shared_user_id"
    static let adaptyFallbackUserIDKey = "adapty_fallback_user_id"

    #if DEBUG
    private static let fixedDebugUserID = "455a9a9c-cf05-41a9-ac7e-93c3fee6dc5c"
    #endif

    static func resolvedUserID(
        userDefaults: UserDefaults = .standard,
        keychain: KeychainManager = .shared
    ) -> String {
        #if DEBUG
        persist(userID: fixedDebugUserID, userDefaults: userDefaults, keychain: keychain)
        return fixedDebugUserID
        #else
        if let keychainUserID = validatedUserID(
            from: keychain.loadString(forKey: sharedUserIDKey)
        ) {
            persist(userID: keychainUserID, userDefaults: userDefaults, keychain: keychain)
            return keychainUserID
        }

        if let sharedUserID = validatedUserID(from: userDefaults.string(forKey: sharedUserIDKey)) {
            persist(userID: sharedUserID, userDefaults: userDefaults, keychain: keychain)
            return sharedUserID
        }

        if let adaptyUserID = validatedUserID(from: userDefaults.string(forKey: adaptyFallbackUserIDKey)) {
            persist(userID: adaptyUserID, userDefaults: userDefaults, keychain: keychain)
            return adaptyUserID
        }

        let generatedUserID = UUID().uuidString.lowercased()
        persist(userID: generatedUserID, userDefaults: userDefaults, keychain: keychain)
        return generatedUserID
        #endif
    }

    @discardableResult
    static func synchronizePersistedUserID(
        _ userID: String,
        userDefaults: UserDefaults = .standard,
        keychain: KeychainManager = .shared
    ) -> String? {
        guard let normalizedUserID = validatedUserID(from: userID) else {
            return nil
        }

        #if DEBUG
        persist(userID: fixedDebugUserID, userDefaults: userDefaults, keychain: keychain)
        return fixedDebugUserID
        #else
        persist(userID: normalizedUserID, userDefaults: userDefaults, keychain: keychain)
        return normalizedUserID
        #endif
    }

    static func isUsingFixedDebugUserID(_ userID: String) -> Bool {
        #if DEBUG
        return validatedUserID(from: userID) == fixedDebugUserID
        #else
        return false
        #endif
    }
}

private extension AppUserIdentityConfiguration {
    static func persist(
        userID: String,
        userDefaults: UserDefaults,
        keychain: KeychainManager
    ) {
        userDefaults.set(userID, forKey: sharedUserIDKey)
        userDefaults.set(userID, forKey: adaptyFallbackUserIDKey)
        keychain.save(userID, forKey: sharedUserIDKey)
    }

    static func validatedUserID(from rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let cleanedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard UUID(uuidString: cleanedValue) != nil else {
            return nil
        }

        return cleanedValue
    }
}
