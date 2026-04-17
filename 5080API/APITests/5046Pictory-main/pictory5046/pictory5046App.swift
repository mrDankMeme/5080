import Adapty
import AdaptyLogger
import SwiftData
import SwiftUI

@main
struct pictory5046App: App {
    @StateObject var purchaseManager = PurchaseManager.shared
    @StateObject var apiManager = APIManager.shared
    @AppStorage("OnBoardEnd") var onBoardEnd: Bool = false

    init() {
        Task {
            do {
                let customerUserID = PurchaseManager.shared.userId
                let configurationBuilder = AdaptyConfiguration
                    .builder(withAPIKey: BillingConfig.adaptyAPIKey)
                    .with(customerUserId: customerUserID)
                    .with(observerMode: false)

#if DEBUG
                Adapty.setLogHandler { record in
                    if record.level == .error || record.level == .warn {
                        print("[Adapty][\(record.level)] \(record.message)")
                    }
                }
                let configuration = configurationBuilder
                    .with(logLevel: .error)
                    .build()
#else
                let configuration = configurationBuilder
                    .with(logLevel: .error)
                    .build()
#endif

                try await Adapty.activate(with: configuration)
                print("[Adapty] User ID: \(PurchaseManager.shared.userId)")
                await PurchaseManager.shared.loadPaywalls()
                await PurchaseManager.shared.refreshSubscriptionStatusFromProvider()
            } catch {
                print("[Adapty] activation failed: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if purchaseManager.purchaseState == .idle || purchaseManager.purchaseState == .loading {
                    LaunchView()
                } else if !onBoardEnd {
                    OnBoardView()
                        .environmentObject(purchaseManager)
                } else {
                    MainView()
                        .modelContainer(DataManager.container)
                        .environmentObject(apiManager)
                        .environmentObject(purchaseManager)
                }
            }
            .preferredColorScheme(.dark)
            .task {
                await apiManager.authorize()
                await apiManager.fetchProfile()
                await apiManager.fetchServicePrices()
                await apiManager.fetchTemplates()
                await apiManager.fetchPhotoStyles()
            }
            .onChange(of: onBoardEnd) { oldValue, newValue in
                guard !oldValue, newValue else { return }
                Task {
                    await apiManager.completeOnboarding()
                }
            }
        }
    }
}
