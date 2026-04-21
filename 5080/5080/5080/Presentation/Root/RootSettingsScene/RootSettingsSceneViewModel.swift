import Combine
import Foundation
import UIKit

@MainActor
final class RootSettingsSceneViewModel: ObservableObject {
    enum RowID: String, Identifiable {
        case premium
        case restorePurchases
        case pushNotifications
        case support
        case termsOfUse
        case privacyPolicy
        case rateUs
        case shareWithFriends

        var id: String { rawValue }
    }

    enum RowStyle {
        case accent
        case neutral
    }

    enum RowAccessory {
        case chevron
        case toggle(isOn: Bool)
    }

    struct RowModel: Identifiable {
        let id: RowID
        let title: String
        let assetIconName: String?
        let systemIconName: String?
        let style: RowStyle
        let accessory: RowAccessory
        let isEnabled: Bool
    }

    struct SectionModel: Identifiable {
        let id: String
        let rows: [RowModel]
    }

    struct WebDestination: Identifiable {
        let id = UUID()
        let url: URL
    }

    struct AlertModel: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @Published private(set) var isReady = true
    @Published private var isPushNotificationsEnabled: Bool
    @Published private(set) var applicationVersionText: String
    @Published private(set) var isSubscribed: Bool
    @Published private(set) var activePlanTitle: String?
    @Published private(set) var presentedWebDestination: WebDestination?
    @Published private(set) var mailComposerPayload: MailComposerPayload?
    @Published private(set) var isSharePresented = false
    @Published private(set) var shareItems: [Any] = []
    @Published private(set) var alertModel: AlertModel?
    @Published private(set) var isPremiumPaywallPresented = false
    @Published private(set) var isRateUsPresented = false
    @Published private(set) var isRestoringPurchases = false
    @Published private(set) var isPushNotificationsUpdating = false

    private let purchaseManager: PurchaseManager
    private let userDefaults: UserDefaults
    private let notificationsScheduler: OnboardingNotificationsScheduling
    private let supportURL: URL
    private let privacyURL: URL
    private let termsURL: URL
    private let supportMailBuilder: SupportMailComposerBuilding
    private let shareMessage: String
    private var cancellables = Set<AnyCancellable>()

    private static let pushNotificationsKey = "root_settings_push_notifications_enabled"

    init(
        purchaseManager: PurchaseManager,
        userDefaults: UserDefaults,
        bundle: Bundle,
        supportMailBuilder: SupportMailComposerBuilding,
        notificationsScheduler: OnboardingNotificationsScheduling = NoopOnboardingNotificationsScheduler()
    ) {
        self.purchaseManager = purchaseManager
        self.userDefaults = userDefaults
        self.notificationsScheduler = notificationsScheduler
        self.isPushNotificationsEnabled = userDefaults.bool(forKey: Self.pushNotificationsKey)
        self.applicationVersionText = Self.makeApplicationVersionText(bundle: bundle)
        self.isSubscribed = purchaseManager.isSubscribed
        self.activePlanTitle = purchaseManager.activeSubscriptionPlanTitle
        self.supportURL = AppExternalResources.supportFormURL
        self.privacyURL = AppExternalResources.privacyPolicyURL
        self.termsURL = AppExternalResources.termsOfUseURL
        self.supportMailBuilder = supportMailBuilder
        self.shareMessage = Self.makeShareMessage(bundle: bundle, appStoreURL: AppExternalResources.appStoreURL)
        bindPurchaseManager()
    }

    convenience init() {
        self.init(
            purchaseManager: PurchaseManager.shared,
            userDefaults: .standard,
            bundle: .main,
            supportMailBuilder: DefaultSupportMailComposerBuilder(
                bundle: .main,
                supportEmail: AppExternalResources.supportEmail
            ),
            notificationsScheduler: NoopOnboardingNotificationsScheduler()
        )
    }

    var sections: [SectionModel] {
        [
            SectionModel(
                id: "premium",
                rows: [
                    RowModel(
                        id: .premium,
                        title: premiumRowTitle,
                        assetIconName: "premium",
                        systemIconName: nil,
                        style: .accent,
                        accessory: .chevron,
                        isEnabled: true
                    ),
                    RowModel(
                        id: .restorePurchases,
                        title: "Restore Purchases",
                        assetIconName: "restore",
                        systemIconName: nil,
                        style: .neutral,
                        accessory: .chevron,
                        isEnabled: !isRestoringPurchases
                    )
                ]
            ),
            SectionModel(
                id: "notifications",
                rows: [
                    RowModel(
                        id: .pushNotifications,
                        title: "Push Notifications",
                        assetIconName: nil,
                        systemIconName: "bell",
                        style: .neutral,
                        accessory: .toggle(isOn: isPushNotificationsEnabled),
                        isEnabled: !isPushNotificationsUpdating
                    )
                ]
            ),
            SectionModel(
                id: "documents",
                rows: [
                    RowModel(
                        id: .support,
                        title: "Support",
                        assetIconName: "support",
                        systemIconName: nil,
                        style: .neutral,
                        accessory: .chevron,
                        isEnabled: true
                    ),
                    RowModel(
                        id: .termsOfUse,
                        title: "Terms of Use",
                        assetIconName: "termsOfUse",
                        systemIconName: nil,
                        style: .neutral,
                        accessory: .chevron,
                        isEnabled: true
                    ),
                    RowModel(
                        id: .privacyPolicy,
                        title: "Privacy Policy",
                        assetIconName: "privacyPolicy",
                        systemIconName: nil,
                        style: .neutral,
                        accessory: .chevron,
                        isEnabled: true
                    )
                ]
            ),
            SectionModel(
                id: "feedback",
                rows: [
                    RowModel(
                        id: .rateUs,
                        title: "Rate Us",
                        assetIconName: "rateUs",
                        systemIconName: nil,
                        style: .neutral,
                        accessory: .chevron,
                        isEnabled: true
                    ),
                    RowModel(
                        id: .shareWithFriends,
                        title: "Share with Friends",
                        assetIconName: "shareWithFriends",
                        systemIconName: nil,
                        style: .neutral,
                        accessory: .chevron,
                        isEnabled: true
                    )
                ]
            )
        ]
    }

    func handleTap(_ rowID: RowID) {
        switch rowID {
        case .premium:
            isPremiumPaywallPresented = true

        case .restorePurchases:
            restorePurchases()

        case .pushNotifications:
            togglePushNotifications()

        case .support:
            presentedWebDestination = WebDestination(url: supportURL)

        case .termsOfUse:
            presentedWebDestination = WebDestination(url: termsURL)

        case .privacyPolicy:
            presentedWebDestination = WebDestination(url: privacyURL)

        case .rateUs:
            isRateUsPresented = true

        case .shareWithFriends:
            shareItems = [shareMessage]
            isSharePresented = true
        }
    }

    func dismissPresentedWebDestination() {
        presentedWebDestination = nil
    }

    func dismissMailComposer() {
        mailComposerPayload = nil
    }

    func dismissShareSheet() {
        isSharePresented = false
        shareItems = []
    }

    func dismissAlert() {
        alertModel = nil
    }

    func dismissPremiumPaywall() {
        isPremiumPaywallPresented = false
    }

    func dismissRateUs() {
        isRateUsPresented = false
    }

    func refreshPushNotificationsState() {
        guard !isPushNotificationsUpdating else { return }
        isPushNotificationsUpdating = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isPushNotificationsUpdating = false }

            let isEnabled = await notificationsScheduler.notificationsEnabled()
            isPushNotificationsEnabled = isEnabled
            userDefaults.set(isEnabled, forKey: Self.pushNotificationsKey)
        }
    }

    private func restorePurchases() {
        guard !isRestoringPurchases else { return }
        isRestoringPurchases = true

        Task { @MainActor [weak self] in
            guard let self else { return }

            let isRestored = await purchaseManager.restoreAny()
            isRestoringPurchases = false

            if isRestored {
                alertModel = AlertModel(
                    title: "Purchases Restored",
                    message: "Your premium access has been restored."
                )
                return
            }

            alertModel = AlertModel(
                title: "Restore Failed",
                message: purchaseManager.failRestoreText ?? "Nothing to restore."
            )
        }
    }

    private static func makeApplicationVersionText(bundle: Bundle) -> String {
        let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedVersion = (version?.isEmpty == false ? version : nil) ?? "Unknown"
        return "Application version: \(resolvedVersion)"
    }

    private static func makeShareMessage(bundle: Bundle, appStoreURL: URL) -> String {
        let appName = ((bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? ((bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines))
                .flatMap { $0.isEmpty ? nil : $0 }
            ?? "Zentium Labs"

        return "I'm using \(appName) to build live websites with AI. \(appStoreURL.absoluteString)"
    }

    private var premiumRowTitle: String {
        guard isSubscribed else { return "Go Premium" }
        return activePlanTitle ?? "Premium Plan"
    }

    private func bindPurchaseManager() {
        purchaseManager.$isSubscribed
            .combineLatest(purchaseManager.$activeSubscriptionPlanTitle)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSubscribed, activePlanTitle in
                self?.isSubscribed = isSubscribed
                self?.activePlanTitle = activePlanTitle
            }
            .store(in: &cancellables)
    }

    private func togglePushNotifications() {
        guard !isPushNotificationsUpdating else { return }
        isPushNotificationsUpdating = true

        let shouldEnable = !isPushNotificationsEnabled

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isPushNotificationsUpdating = false }

            if shouldEnable {
                let result = await notificationsScheduler.setWeeklyPromptsEnabled(true)

                switch result {
                case .enabled:
                    isPushNotificationsEnabled = true
                    userDefaults.set(true, forKey: Self.pushNotificationsKey)

                case .disabled:
                    isPushNotificationsEnabled = false
                    userDefaults.set(false, forKey: Self.pushNotificationsKey)

                case .requiresSystemSettings:
                    isPushNotificationsEnabled = false
                    userDefaults.set(false, forKey: Self.pushNotificationsKey)
                    openSystemNotificationSettings()
                }

                return
            }

            _ = await notificationsScheduler.setWeeklyPromptsEnabled(false)
            isPushNotificationsEnabled = false
            userDefaults.set(false, forKey: Self.pushNotificationsKey)
        }
    }

    private func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            alertModel = AlertModel(
                title: "Notifications Disabled",
                message: "Open iPhone Settings and allow notifications for this app."
            )
            return
        }

        UIApplication.shared.open(url) { [weak self] success in
            guard !success else { return }

            Task { @MainActor in
                self?.alertModel = AlertModel(
                    title: "Notifications Disabled",
                    message: "Open iPhone Settings and allow notifications for this app."
                )
            }
        }
    }

    private func makeSupportMailMetadata() -> SupportMailMetadata {
        SupportMailMetadata(
            userID: purchaseManager.userId,
            availableTokens: purchaseManager.availableGenerations,
            activePlanTitle: purchaseManager.activeSubscriptionPlanTitle
        )
    }
}
