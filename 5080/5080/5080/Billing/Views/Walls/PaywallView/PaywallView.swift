import SwiftUI
import UIKit

struct PaywallView: View {

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    private let onClose: (() -> Void)?

    @State private var activeSheet: PaywallSheet?
    @State private var pickedProd: BillingProduct?
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = "Error"
    @State private var alertMessage: String = ""
    @State private var closeAfterAlert: Bool = false
    @State private var isRestoring: Bool = false
    @State private var suppressErrorAlertFromRestore: Bool = false
    @State private var suppressAutoCloseOnSubscribeFromRestore: Bool = false
    @State private var isCloseVisible: Bool = false

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    private var termsURL: URL? {
        AppExternalResources.termsOfUseURL
    }

    private var privacyURL: URL? {
        AppExternalResources.privacyPolicyURL
    }

    private var weeklyProductForComparison: BillingProduct? {
        productsForLayout.first(where: isWeeklyProduct)
    }

    private var productsForLayout: [BillingProduct] {
        let all = purchaseManager.products
        guard !all.isEmpty else { return [] }

        let annual = all.first(where: { $0.id == BillingConfig.adaptyAnnualProductID })
        let weekly = all.first(where: { $0.id == BillingConfig.adaptyWeeklyProductID })

        var ordered: [BillingProduct] = []
        if let annual {
            ordered.append(annual)
        }
        if let weekly, weekly.id != annual?.id {
            ordered.append(weekly)
        }

        if !ordered.isEmpty {
            return ordered
        }

        let fallbackAnnual = all.first(where: isAnnualProduct)
        let fallbackWeekly = all.first(where: isWeeklyProduct)

        if let fallbackAnnual {
            ordered.append(fallbackAnnual)
        }
        if let fallbackWeekly, fallbackWeekly.id != fallbackAnnual?.id {
            ordered.append(fallbackWeekly)
        }

        return ordered.isEmpty ? all.paywallSortedProducts() : ordered
    }

    var body: some View {
        GeometryReader { geo in
            let closeTopInset = closeButtonTopInset(safeTop: geo.safeAreaInsets.top)
            ZStack(alignment: .topTrailing) {
                backgroundView(geo: geo)
                bottomCard(geo: geo)
                closeButton(topInset: closeTopInset)
            }
            .overlay {
                if purchaseManager.isLoading {
                    PaywallLoadingOverlayView()
                }
            }
            .onAppear {
                applyWindowInterfaceStyle(.light)
                pickDefaultProductIfNeeded()
                scheduleCloseButtonAppearance()

                if purchaseManager.purchaseError != nil || purchaseManager.failRestoreText != nil {
                    presentErrorAlertFromManagerState()
                }
            }
            .onDisappear {
                applyWindowInterfaceStyle(.dark)
            }
            .onChange(of: purchaseManager.products) { _, _ in
                pickDefaultProductIfNeeded()
            }
            .onChange(of: purchaseManager.failRestoreText != nil) { _, newValue in
                guard !suppressErrorAlertFromRestore else { return }
                if newValue {
                    presentErrorAlertFromManagerState()
                }
            }
            .onChange(of: purchaseManager.purchaseError != nil) { _, newValue in
                guard !suppressErrorAlertFromRestore else { return }
                if newValue {
                    presentErrorAlertFromManagerState()
                }
            }
            .onChange(of: purchaseManager.isSubscribed) { _, newValue in
                guard newValue else { return }
                guard !suppressAutoCloseOnSubscribeFromRestore else { return }
                close(reason: "isSubscribed_onChange")
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    purchaseManager.failRestoreText = nil
                    purchaseManager.purchaseError = nil

                    let shouldClose = closeAfterAlert && purchaseManager.isSubscribed
                    closeAfterAlert = false
                    suppressAutoCloseOnSubscribeFromRestore = false

                    if shouldClose {
                        close(reason: "restore_success_alert_ok")
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .safari(let url):
                    SafariView(url: url)
                }
            }
        }
        .ignoresSafeArea(.all)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func backgroundView(geo: GeometryProxy) -> some View {
        let layoutType = DeviceLayout.type
        let backgroundLift = paywallBackgroundImageLift(for: layoutType)

        ZStack {
            Image("paywall_pic")
                .resizable()
                .scaledToFill()
                .frame(
                    width: geo.size.width,
                    height: geo.size.height,
                    alignment: .top
                )
                .offset(y: -backgroundLift)
                .clipped()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.28),
                    Color.white.opacity(0.95)
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.50),
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }

    private func paywallBackgroundImageLift(for layoutType: DeviceLayoutType) -> CGFloat {
        let isIpad = layoutType == .iPad || layoutType == .unknown || layoutType == .smallStatusBar
        return isIpad ? 180.scale : 0.scale
    }

    @ViewBuilder
    private func bottomCard(geo: GeometryProxy) -> some View {
        let safeBottom = geo.safeAreaInsets.bottom
        let cardHeight = paywallCardHeight(for: geo, safeBottom: safeBottom)
        PaywallBottomCardView(
            titleText: "Create Apps & Websites Just by Chatting with AI",
            cancelText: "Cancel Anytime",
            continueText: "Continue",
            footerTerms: "Terms of Use",
            footerRestore: "Restore",
            footerPrivacy: "Privacy Policy",
            products: productsForLayout,
            sortedProductsForUI: productsForLayout,
            purchaseState: purchaseManager.purchaseState,
            isReady: purchaseManager.isReady,
            isLoading: purchaseManager.isLoading,
            pickedProd: $pickedProd,
            onPick: { product in
                pickedProd = product
            },
            onOpenTerms: {
                if let termsURL {
                    openSafari(termsURL)
                }
            },
            onRestore: {
                Task { await restoreTapped() }
            },
            onOpenPrivacy: {
                if let privacyURL {
                    openSafari(privacyURL)
                }
            },
            onContinue: { product in
                purchaseManager.makePurchase(product: product) { success, _ in
                    if success {
                        close(reason: "purchase_success_callback")
                    }
                }
            },
            planTitle: { product in
                if isAnnualProduct(product) {
                    return "Yearly"
                }
                if isWeeklyProduct(product) {
                    return "Weekly"
                }
                return PaywallProductText.planTitle(for: product, isEnglishUI: true)
            },
            planSubtitle: { product in
                if isAnnualProduct(product) {
                    return "$1.5 / site"
                }
                if isWeeklyProduct(product) {
                    return "$2.6 / site"
                }
                return ""
            },
            planPriceText: { product in
                product.localizedPrice
            },
            planBadgeText: { product in
                guard isAnnualProduct(product) else { return nil }
                return PaywallProductText.savingsBadgeText(
                    for: product,
                    comparedTo: weeklyProductForComparison
                )
            },
            bottomSafeInset: safeBottom
        )
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight, alignment: .bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    @ViewBuilder
    private func closeButton(topInset: CGFloat) -> some View {
        let canShowClose = isCloseVisible && !purchaseManager.isLoading

        Button {
            close(reason: "manual_close_button")
        } label: {
            Image(systemName: "xmark")
                .font(Tokens.Font.semibold16)
                .foregroundStyle((Color(hex: "141414") ?? .black).opacity(0.3))
                .frame(width: 50.scale, height: 50.scale)
        }
        .buttonStyle(.plain)
        .disabled(!canShowClose)
        .opacity(canShowClose ? 1.0 : 0.0)
        .padding(.top, topInset + (DeviceLayout.isPad || DeviceLayout.isSmallStatusBarPhone ? 0.scale : 20.scale))
        .padding(.trailing, 16.scale)
        .accessibilityLabel("Close")
    }

    private func scheduleCloseButtonAppearance() {
        isCloseVisible = false

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                isCloseVisible = true
            }
        }
    }

    private func paywallCardHeight(for geo: GeometryProxy, safeBottom: CGFloat) -> CGFloat {
        let baseHeight: CGFloat

        switch DeviceLayout.type {
        case .smallStatusBar:
            baseHeight = 360.scale
        case .notch, .dynamicIsland:
            baseHeight = 400.scale
        case .iPad:
            baseHeight = 390.scale
        case .unknown:
            baseHeight = 408.scale
        }

        let raw = baseHeight + safeBottom
        let minHeight = DeviceLayout.isPad ? 380.scale : (DeviceLayout.isSmallStatusBarPhone ? 350.scale : 372.scale)
        let maxHeight = max(320.scale, geo.size.height - (DeviceLayout.isPad ? 132.scale : 120.scale))

        return min(max(raw, minHeight), maxHeight)
    }

    private func closeButtonTopInset(safeTop: CGFloat) -> CGFloat {
        switch DeviceLayout.type {
        case .smallStatusBar, .unknown:
            return max(16.scale, safeTop + 4.scale)
        case .notch, .dynamicIsland:
            return max(16.scale, safeTop + 6.scale)
        case .iPad:
            return max(24.scale, safeTop + 8.scale)
        }
    }

    private func pickDefaultProductIfNeeded() {
        guard !productsForLayout.isEmpty else { return }

        if let annual = productsForLayout.first(where: { $0.id == BillingConfig.adaptyAnnualProductID })
            ?? productsForLayout.first(where: isAnnualProduct) {
            pickedProd = annual
            return
        }

        if pickedProd == nil || !productsForLayout.contains(where: { $0.id == pickedProd?.id }) {
            pickedProd = productsForLayout.first
        }
    }

    private func close(reason: String) {
        _ = reason
        onClose?()
        dismiss()
    }

    private func openSafari(_ url: URL) {
        activeSheet = .safari(url)
    }

    @MainActor
    private func restoreTapped() async {
        guard !isRestoring else { return }
        isRestoring = true
        suppressErrorAlertFromRestore = true
        suppressAutoCloseOnSubscribeFromRestore = true
        defer {
            isRestoring = false
            suppressErrorAlertFromRestore = false
        }

        let ok = await purchaseManager.restoreAny()
        let isRussianUI = Locale.current.language.languageCode?.identifier == "ru"

        alertTitle = isRussianUI ? "Восстановление покупок" : "Restore Purchases"
        if ok {
            alertMessage = isRussianUI ? "Покупки успешно восстановлены" : "Purchases restored successfully"
            closeAfterAlert = true
            showAlert = true
            return
        }

        alertMessage = restoreFailureMessage(isRussianUI: isRussianUI)
        closeAfterAlert = false
        showAlert = true
    }

    @MainActor
    private func presentErrorAlertFromManagerState() {
        alertTitle = "Error"
        alertMessage = purchaseManager.purchaseError ?? purchaseManager.failRestoreText ?? "Unknown error"
        closeAfterAlert = false
        showAlert = true
    }

    @MainActor
    private func restoreFailureMessage(isRussianUI: Bool) -> String {
        let alreadyActiveSuffix = isRussianUI
        ? "Подписка уже активна и работает в приложении."
        : "Your subscription is already active and available in the app."

        let defaultNothing = isRussianUI ? "Нечего восстанавливать" : "Nothing to restore"
        let raw = (purchaseManager.failRestoreText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if purchaseManager.isSubscribed {
            if raw.isEmpty || raw.lowercased() == "nothing to restore" {
                return "\(defaultNothing). \(alreadyActiveSuffix)"
            }
            return "\(raw)\n\(alreadyActiveSuffix)"
        }

        return raw.isEmpty ? defaultNothing : raw
    }

    private func isAnnualProduct(_ product: BillingProduct) -> Bool {
        if product.id == BillingConfig.adaptyAnnualProductID {
            return true
        }

        if product.period?.unit == .year {
            return true
        }

        let id = product.id.lowercased()
        return id.contains("year") || id.contains("annual")
    }

    private func isWeeklyProduct(_ product: BillingProduct) -> Bool {
        if product.id == BillingConfig.adaptyWeeklyProductID {
            return true
        }

        if product.period?.unit == .week {
            return true
        }

        return product.id.lowercased().contains("week")
    }

    private func applyWindowInterfaceStyle(_ style: UIUserInterfaceStyle) {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        for scene in scenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

private enum PaywallSheet: Identifiable {
    case safari(URL)

    var id: String {
        switch self {
        case .safari(let url):
            return "safari_\(url.absoluteString)"
        }
    }
}
