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
        ZStack {
            Image("paywall_pic")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
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

    @ViewBuilder
    private func bottomCard(geo: GeometryProxy) -> some View {
        let safeBottom = geo.safeAreaInsets.bottom
        let cardHeight = paywallCardHeight(for: geo, safeBottom: safeBottom)
        let annualProduct = productsForLayout.first(where: isAnnualProduct)
        let weeklyProduct = productsForLayout.first(where: isWeeklyProduct)

        VStack(spacing: 0) {
            Text("Unlock Full AI Power")
                .font(Tokens.Font.outfitBold28)
                .kerning(-0.28.scale)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: "141414") ?? .black)
                .lineSpacing(4.scale)
                .padding(.top, 24.scale)
                .padding(.horizontal, 20.scale)

            Text("Create unlimited AI videos, voices, and transcriptions, or proceed with limits.")
                .font(Tokens.Font.regular16)
                .kerning(0.16.scale)
                .foregroundStyle(Color(hex: "141414")?.opacity(0.86) ?? .black.opacity(0.86))
                .multilineTextAlignment(.center)
                .lineSpacing(DeviceLayout.isPad ? 4.scale : 8.scale)
                .lineLimit(DeviceLayout.isPad ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .padding(.top, 12.scale)
                .padding(.horizontal, DeviceLayout.isPad ? 40.scale : 24.scale)

            VStack(spacing: 4.scale) {
                if purchaseManager.purchaseState == .loading || productsForLayout.isEmpty {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Tokens.Color.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: (68.scale * 2) + 4.scale)
                } else {
                    if let annualProduct {
                        PaywallPlanOptionRow(
                            title: "Annual",
                            subtitle: annualPerWeekText(for: annualProduct),
                            priceText: "\(annualProduct.localizedPrice) / year",
                            isSelected: pickedProd?.id == annualProduct.id,
                            showsPopularBadge: true,
                            isEnabled: !purchaseManager.isLoading,
                            onTap: {
                                pickedProd = annualProduct
                            }
                        )
                    }

                    if let weeklyProduct {
                        PaywallPlanOptionRow(
                            title: "Weekly",
                            subtitle: nil,
                            priceText: "\(weeklyProduct.localizedPrice) / week",
                            isSelected: pickedProd?.id == weeklyProduct.id,
                            showsPopularBadge: false,
                            isEnabled: !purchaseManager.isLoading,
                            onTap: {
                                pickedProd = weeklyProduct
                            }
                        )
                    }
                }
            }
            .padding(.top, 24.scale)
            .padding(.horizontal, 16.scale)

            Text("Cancel Anytime")
                .font(Tokens.Font.medium14)
                .kerning(0.16.scale)
                .foregroundStyle(Color(hex: "141414")?.opacity(0.6) ?? Color.black.opacity(0.6))
                .padding(.top, 16.scale)

            Button {
                guard let product = pickedProd else { return }
                purchaseManager.makePurchase(product: product) { success, _ in
                    if success {
                        close(reason: "purchase_success_callback")
                    }
                }
            } label: {
                Text("Continue")
                    .font(Tokens.Font.semibold17)
                    .kerning(-0.17.scale)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52.scale)
                    .background(
                        RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                            .fill(Tokens.Color.accent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(pickedProd == nil || purchaseManager.isLoading || !purchaseManager.isReady)
            .opacity((pickedProd == nil || purchaseManager.isLoading || !purchaseManager.isReady) ? 0.6 : 1.0)
            .padding(.horizontal, 16.scale)
            .padding(.top, 16.scale)

            HStack(spacing: 32.scale) {
                Button("Privacy Policy") {
                    if let privacyURL {
                        openSafari(privacyURL)
                    }
                }
                .disabled(privacyURL == nil)

                Button("Restore") {
                    Task { await restoreTapped() }
                }

                Button("Terms of Use") {
                    if let termsURL {
                        openSafari(termsURL)
                    }
                }
                .disabled(termsURL == nil)
            }
            .buttonStyle(.plain)
            .font(Tokens.Font.regular13)
            .kerning(0.13.scale)
            .foregroundStyle(Color(hex: "141414")?.opacity(0.6) ?? Color.black.opacity(0.6))
            .padding(.top, 8.scale)

            Spacer(minLength: footerBottomSpacing(safeBottom: safeBottom))
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight, alignment: .top)
        .background(
            TopRoundedCornersShape(radius: 32.scale)
                .fill(Color.white)
        )
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

    private func footerBottomSpacing(safeBottom: CGFloat) -> CGFloat {
        switch DeviceLayout.type {
        case .smallStatusBar:
            return 16.scale
        case .iPad:
            return max(20.scale, safeBottom)
        case .unknown:
            return max(16.scale, safeBottom)
        case .notch, .dynamicIsland:
            return max(10.scale, safeBottom - 4.scale)
        }
    }

    private func paywallCardHeight(for geo: GeometryProxy, safeBottom: CGFloat) -> CGFloat {
        let baseHeight: CGFloat

        switch DeviceLayout.type {
        case .smallStatusBar:
            baseHeight = 410.scale
        case .notch, .dynamicIsland:
            baseHeight = 450.scale
        case .iPad:
            baseHeight = 436.scale
        case .unknown:
            baseHeight = 460.scale
        }

        let raw = baseHeight + safeBottom
        let minHeight = DeviceLayout.isPad ? 432.scale : (DeviceLayout.isSmallStatusBarPhone ? 410.scale : 420.scale)
        let maxHeight = max(360.scale, geo.size.height - (DeviceLayout.isPad ? 120.scale : 96.scale))

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

    private func annualPerWeekText(for annualProduct: BillingProduct) -> String {
        if let localizedPricePerWeek = annualProduct.localizedPricePerWeek, !localizedPricePerWeek.isEmpty {
            let lower = localizedPricePerWeek.lowercased()
            if lower.contains("week") || lower.contains("нед") {
                return localizedPricePerWeek
            }
            return "\(localizedPricePerWeek) / week"
        }

        let annualDecimal = NSDecimalNumber(decimal: annualProduct.price)
        let perWeek = annualDecimal.dividing(by: NSDecimalNumber(value: 52))

        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let weeklyPrice = formatter.string(from: perWeek) ?? annualProduct.localizedPrice
        return "\(weeklyPrice) / week"
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

private struct TopRoundedCornersShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

private struct PaywallPlanOptionRow: View {
    let title: String
    let subtitle: String?
    let priceText: String
    let isSelected: Bool
    let showsPopularBadge: Bool
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 40.scale, style: .continuous)
                    .fill(isSelected ? Tokens.Color.accentSoft : (Color(hex: "F2F2F4") ?? Color.gray.opacity(0.12)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 40.scale, style: .continuous)
                            .stroke(Tokens.Color.accent, lineWidth: isSelected ? 1.5.scale : 0)
                    )

                HStack(spacing: 12.scale) {
                    selectionBullet
                        .padding(.leading, 16.scale)

                    VStack(alignment: .leading, spacing: 4.scale) {
                        Text(title)
                            .font(Tokens.Font.outfitSemibold16)
                            .kerning(-0.16.scale)
                            .foregroundStyle(Color(hex: "141414") ?? .black)
                            .lineLimit(1)

                        if let subtitle {
                            Text(subtitle)
                                .font(Tokens.Font.medium14)
                                .kerning(-0.14.scale)
                                .foregroundStyle(Color(hex: "14141499") ?? Color.black.opacity(0.6))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 12.scale)

                    Text(priceText)
                        .font(Tokens.Font.outfitSemibold18)
                        .kerning(-0.18.scale)
                        .foregroundStyle(Color(hex: "141414") ?? .black)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .padding(.trailing, 16.scale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showsPopularBadge {
                    Text("Popular")
                        .font(Tokens.Font.medium14)
                        .kerning(-0.14.scale)
                        .foregroundStyle(.white)
                        .frame(width: 75.scale, height: 22.scale)
                        .background(
                            Capsule()
                                .fill(Tokens.Color.accent)
                                .overlay(
                                    Capsule()
                                        .stroke(Tokens.Color.accent, lineWidth: 1.5.scale)
                                )
                        )
                        .offset(x: -16.scale, y: -11.scale)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68.scale)
            .contentShape(RoundedRectangle(cornerRadius: 40.scale, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var selectionBullet: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Tokens.Color.accent)
                    .frame(width: 24.scale, height: 24.scale)

                Circle()
                    .fill(Color.white)
                    .frame(width: 8.scale, height: 8.scale)
            } else {
                Circle()
                    .stroke(Color(hex: "C4C4C7") ?? Color.gray.opacity(0.6), lineWidth: 2.scale)
                    .frame(width: 24.scale, height: 24.scale)
            }
        }
        .frame(width: 24.scale, height: 24.scale)
    }
}
