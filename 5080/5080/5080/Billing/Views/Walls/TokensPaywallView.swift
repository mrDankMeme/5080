import SwiftUI
import UIKit

struct TokensPaywallView: View {
    private enum TokensPaywallSheet: Identifiable {
        case safari(URL)

        var id: String {
            switch self {
            case .safari(let url):
                return url.absoluteString
            }
        }
    }

    private struct TokensPaywallAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private enum TokensPaywallAssets {
        static let heroImageName = "token_paywall_hero"
        static let heroBackgroundImageName = "Onboarding.Background"
    }

    fileprivate enum TokensPaywallLayout {
        static let productRowHeight: CGFloat = 72.scale
        static let bottomContentTopOffset: CGFloat = -48.scale
        static let titleToProducts: CGFloat = 18.scale
        static let contentSpacerMin: CGFloat = 4.scale
        static let continueTopSpacing: CGFloat = 10.scale
        static let footerTopSpacing: CGFloat = 10.scale
        static let compactLayoutBottomContentLift: CGFloat = 120
        static let compactLayoutHeroLift: CGFloat = 220
    }

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var onDismiss: (() -> Void)? = nil

    @State private var selectedProductId: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var activeSheet: TokensPaywallSheet?
    @State private var alertModel: TokensPaywallAlert?
    @State private var isCloseVisible = false
    @State private var closeButtonTask: Task<Void, Never>?

    private var selectedProduct: BillingProduct? {
        sortedTokenProducts.first(where: { $0.id == selectedProductId })
    }

    private var sortedTokenProducts: [BillingProduct] {
        purchaseManager.tokenProducts.sorted { lhs, rhs in
            let lhsAmount = tokenAmount(from: lhs.id) ?? 0
            let rhsAmount = tokenAmount(from: rhs.id) ?? 0

            if lhsAmount != rhsAmount {
                return lhsAmount > rhsAmount
            }

            return lhs.price > rhs.price
        }
    }

    private var topSellingProductID: String? {
        sortedTokenProducts.first?.id
    }

    private var canPurchase: Bool {
        !isPurchasing && selectedProduct != nil && purchaseManager.isTokensReady
    }

    private var canDismissPaywall: Bool {
        !isPurchasing && !isRestoring
    }

    private var termsURL: URL? {
        AppExternalResources.termsOfUseURL
    }

    private var privacyURL: URL? {
        AppExternalResources.privacyPolicyURL
    }

    private var contentHorizontalPadding: CGFloat {
        switch DeviceLayout.type {
        case .iPad:
            return 28.scale
        case .unknown:
            return 20.scale
        case .smallStatusBar, .notch, .dynamicIsland:
            return 16.scale
        }
    }

    private var closeButtonDelayNanoseconds: UInt64 {
        5_000_000_000
    }

    private var usesCompactPadTokenLayout: Bool {
        switch DeviceLayout.type {
        case .iPad, .unknown, .smallStatusBar:
            return true
        case .notch, .dynamicIsland:
            return false
        }
    }

    private var bottomContentTopOffset: CGFloat {
        TokensPaywallLayout.bottomContentTopOffset
            - (usesCompactPadTokenLayout ? TokensPaywallLayout.compactLayoutBottomContentLift : 0)
    }

    private var heroContentVerticalOffset: CGFloat {
        usesCompactPadTokenLayout ? -TokensPaywallLayout.compactLayoutHeroLift : 0
    }

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = contentColumnWidth(containerWidth: geometry.size.width)

            VStack(spacing: 0.scale) {
                heroSection(width: columnWidth)
                    .overlay(alignment: .topTrailing) {
                        closeButton
                            .padding(.top, geometry.safeAreaInsets.top + 8.scale)
                            .padding(.trailing, 10.scale)
                    }
                    .padding(.horizontal, contentHorizontalPadding)
                    .ignoresSafeArea(edges: .top)
                    .frame(maxWidth: .infinity)

                bottomContent(width: columnWidth)
                    .padding(.top, bottomContentTopOffset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Tokens.Color.surfaceWhite.ignoresSafeArea())
            .preferredColorScheme(.light)
        }
        .interactiveDismissDisabled(isPurchasing || isRestoring)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .safari(let url):
                SafariView(url: url)
            }
        }
        .alert(item: $alertModel) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            purchaseManager.debugLogTokenPaywallState(context: "TokensPaywallView.onAppear.beforeTrack")
            purchaseManager.trackCurrentPaywallShown(placementID: BillingConfig.adaptyTokensPlacementID)
            preselectIfNeeded()
            errorMessage = purchaseManager.tokenPurchaseError
            scheduleCloseButtonAppearance()
            purchaseManager.debugLogTokenPaywallState(context: "TokensPaywallView.onAppear.afterPreselect")
        }
        .onChange(of: purchaseManager.tokenProducts) { _, _ in
            preselectIfNeeded()
            purchaseManager.debugLogTokenPaywallState(context: "TokensPaywallView.tokenProductsChanged")
        }
        .onChange(of: purchaseManager.tokenPurchaseError) { _, newValue in
            errorMessage = newValue
            purchaseManager.debugLogTokenPaywallState(context: "TokensPaywallView.tokenErrorChanged")
        }
        .onChange(of: selectedProductId) { _, newValue in
            purchaseManager.debugLogTokenPaywallState(
                context: "TokensPaywallView.selectedProductChanged:\(newValue ?? "nil")"
            )
        }
        .onDisappear {
            closeButtonTask?.cancel()
            purchaseManager.debugLogTokenPaywallState(context: "TokensPaywallView.onDisappear")
            purchaseManager.trackCurrentPaywallClosed(placementID: BillingConfig.adaptyTokensPlacementID)
        }
    }

    private var closeButton: some View {
        Button {
            dismissPaywall()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13.scale, weight: .semibold))
                .foregroundStyle(Tokens.Color.paywallPrimaryText)
                .frame(width: 32.scale, height: 32.scale)
                .background(
                    Circle()
                        .fill(Tokens.Color.surfaceWhite.opacity(0.94))
                )
        }
        .buttonStyle(.plain)
        .disabled(!canDismissPaywall || !isCloseVisible)
        .opacity((canDismissPaywall && isCloseVisible) ? 1.0 : 0.0)
        .accessibilityLabel("Close")
    }

    private func bottomContent(width: CGFloat) -> some View {
        VStack(spacing: 0.scale) {
            Text("Get More Tokens to Keep Building")
                .font(Tokens.Font.paywallTitle20)
                .foregroundStyle(Tokens.Color.paywallPrimaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8.scale)

            tokenProductsSection
                .padding(.top, TokensPaywallLayout.titleToProducts)

            if let errorMessage,
               !sortedTokenProducts.isEmpty || errorMessage != purchaseManager.tokenPurchaseError {
                Text(errorMessage)
                    .font(Tokens.Font.regular13)
                    .foregroundStyle(Tokens.Color.destructive)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12.scale)
                    .padding(.horizontal, 4.scale)
            }

            Spacer(minLength: TokensPaywallLayout.contentSpacerMin)

            bottomActions
        }
        .frame(width: width)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, contentHorizontalPadding)
        .padding(.bottom, bottomSectionInset)
    }

    @ViewBuilder
    private var tokenProductsSection: some View {
        if sortedTokenProducts.isEmpty {
            VStack(spacing: 12.scale) {
                if purchaseManager.tokenPurchaseError == nil {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Tokens.Color.onboardingContinueButton)
                }

                Text(purchaseManager.tokenPurchaseError ?? "Loading token packs...")
                    .font(Tokens.Font.regular16)
                    .foregroundStyle(Tokens.Color.paywallSecondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220.scale)
        } else {
            VStack(spacing: PaywallLayout.productsSpacing) {
                ForEach(sortedTokenProducts) { product in
                    tokenRow(product)
                }
            }
        }
    }

    private func tokenRow(_ product: BillingProduct) -> some View {
        let isSelected = selectedProductId == product.id

        return Button {
            selectedProductId = product.id
            errorMessage = nil
        } label: {
            TokenPaywallRowView(
                isSelected: isSelected,
                isTopSelling: product.id == topSellingProductID,
                title: buildsTitle(for: product),
                subtitle: pricePerSiteText(for: product),
                priceText: product.localizedPrice
            )
        }
        .buttonStyle(.plain)
    }

    private var cancelAnytimeView: some View {
        HStack(spacing: 6.scale) {
            Image(systemName: "arrow.clockwise")
                .font(Tokens.Font.regular14)

            Text("Cancel Anytime")
                .font(Tokens.Font.regular14)
        }
        .foregroundStyle(Tokens.Color.paywallTertiaryText)
        .frame(maxWidth: .infinity)
    }

    private var bottomActions: some View {
        VStack(spacing: 0.scale) {
            cancelAnytimeView

            PaywallContinueButton(
                title: isPurchasing ? "Processing..." : "Continue",
                isEnabled: canPurchase,
                onTap: continuePurchase
            )
            .padding(.top, TokensPaywallLayout.continueTopSpacing)

            PaywallFooterLinksView(
                termsTitle: "Terms of Use",
                restoreTitle: isRestoring ? "Restoring..." : "Restore",
                privacyTitle: "Privacy Policy",
                onTerms: {
                    if let termsURL {
                        activeSheet = .safari(termsURL)
                    }
                },
                onRestore: restorePurchases,
                onPrivacy: {
                    if let privacyURL {
                        activeSheet = .safari(privacyURL)
                    }
                }
            )
            .padding(.top, TokensPaywallLayout.footerTopSpacing)
        }
    }

    private func heroSection(width: CGFloat) -> some View {
        let heroHeight = width * (276.0 / 402.0)

        return ZStack {
            ZStack {
                if UIImage(named: TokensPaywallAssets.heroImageName) != nil {
                    Image(TokensPaywallAssets.heroImageName)
                        .resizable()
                        .scaledToFill()
                } else {
                    heroBackground
                    heroPlaceholderContent
                }
            }
            .offset(y: heroContentVerticalOffset)
        }
        .frame(width: width, height: heroHeight)
        .clipShape(RoundedRectangle(cornerRadius: 26.scale, style: .continuous))
    }

    @ViewBuilder
    private var heroBackground: some View {
        if UIImage(named: TokensPaywallAssets.heroBackgroundImageName) != nil {
            Image(TokensPaywallAssets.heroBackgroundImageName)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [
                    Color(hex: "DDF5F8") ?? Tokens.Color.paywallOptionFill,
                    Color(hex: "F6F1EA") ?? Tokens.Color.surfaceWhite
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var heroPlaceholderContent: some View {
        RoundedRectangle(cornerRadius: 22.scale, style: .continuous)
            .fill(Tokens.Color.surfaceWhite.opacity(0.58))
            .overlay(
                RoundedRectangle(cornerRadius: 22.scale, style: .continuous)
                    .strokeBorder(
                        Tokens.Color.paywallSelectedOptionStroke.opacity(0.28),
                        style: StrokeStyle(
                            lineWidth: 1.5.scale,
                            dash: [8.scale, 6.scale]
                        )
                    )
            )
            .padding(.horizontal, 16.scale)
            .padding(.vertical, 14.scale)
            .overlay {
                VStack(spacing: 10.scale) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 28.scale, weight: .medium))
                        .foregroundStyle(Tokens.Color.paywallSelectedOptionStroke)

                    Text("Token Paywall Hero")
                        .font(Tokens.Font.semibold17)
                        .foregroundStyle(Tokens.Color.paywallPrimaryText)

                    Text("Placeholder for 402 x 276 image")
                        .font(Tokens.Font.medium14)
                        .foregroundStyle(Tokens.Color.paywallSecondaryText)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20.scale)
            }
    }

    private func preselectIfNeeded() {
        guard selectedProduct == nil else { return }
        selectedProductId = topSellingProductID ?? sortedTokenProducts.first?.id
    }

    private func buildsTitle(for product: BillingProduct) -> String {
        guard let amount = tokenAmount(from: product.id) else {
            return "Token Pack"
        }

        return "\(formattedAmount(amount)) Builds"
    }

    private func pricePerSiteText(for product: BillingProduct) -> String {
        guard let amount = tokenAmount(from: product.id), amount > 0 else {
            return ""
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.roundingMode = .halfUp
        formatter.currencyCode = product.currencyCode ?? "USD"

        if let regionCode = product.priceRegionCode, !regionCode.isEmpty {
            formatter.locale = Locale(identifier: "en_\(regionCode)")
        } else {
            formatter.locale = Locale(identifier: "en_US")
        }

        let pricePerSite = NSDecimalNumber(decimal: product.price).doubleValue / Double(amount)
        formatter.minimumFractionDigits = pricePerSite >= 0.1 ? 1 : 2
        formatter.maximumFractionDigits = 2

        let formattedPrice = formatter.string(from: NSNumber(value: pricePerSite))
            ?? String(format: "$%.2f", pricePerSite)

        return "\(formattedPrice) / site"
    }

    private func formattedAmount(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    private func tokenAmount(from id: String) -> Int? {
        let parts = id.split { !$0.isNumber }
        guard let firstNumericChunk = parts.first else { return nil }
        return Int(firstNumericChunk)
    }

    private func contentColumnWidth(containerWidth: CGFloat) -> CGFloat {
        let availableWidth = max(0.scale, containerWidth - (contentHorizontalPadding * 2))
        return min(availableWidth, 402.scale)
    }

    private var bottomSectionInset: CGFloat {
        switch DeviceLayout.type {
        case .smallStatusBar:
            return 12.scale
        case .iPad:
            return 20.scale
        case .unknown:
            return 16.scale
        case .notch, .dynamicIsland:
            return 10.scale
        }
    }

    private func scheduleCloseButtonAppearance() {
        closeButtonTask?.cancel()
        isCloseVisible = false

        closeButtonTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: closeButtonDelayNanoseconds)
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.25)) {
                isCloseVisible = true
            }
        }
    }

    private func continuePurchase() {
        guard let selectedProduct else {
            errorMessage = "Select a token pack first"
            return
        }

        isPurchasing = true
        errorMessage = nil

        purchaseManager.makePurchase(product: selectedProduct) { success, error in
            isPurchasing = false
            if success {
                dismissPaywall()
            } else {
                errorMessage = error ?? "Purchase failed"
            }
        }
    }

    private func restorePurchases() {
        guard !isRestoring else { return }

        isRestoring = true

        Task {
            let restored = await purchaseManager.restoreAny()
            await MainActor.run {
                isRestoring = false
                alertModel = TokensPaywallAlert(
                    title: restored ? "Restored" : "Restore Failed",
                    message: restored
                        ? "Your purchases have been restored."
                        : (purchaseManager.failRestoreText ?? "Nothing to restore.")
                )
            }
        }
    }

    private func dismissPaywall() {
        guard canDismissPaywall else { return }
        completeClose()
    }

    private func completeClose() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

private struct TokenPaywallRowView: View {
    let isSelected: Bool
    let isTopSelling: Bool
    let title: String
    let subtitle: String
    let priceText: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(
                cornerRadius: PaywallLayout.optionCorner,
                style: .continuous
            )
            .fill(isSelected ? Tokens.Color.paywallSelectedOptionFill : Tokens.Color.paywallOptionFill)
            .overlay(
                RoundedRectangle(
                    cornerRadius: PaywallLayout.optionCorner,
                    style: .continuous
                )
                .stroke(
                    isSelected ? Tokens.Color.paywallSelectedOptionStroke : Tokens.Color.paywallOptionStroke,
                    lineWidth: isSelected ? 2.scale : 1.scale
                )
            )

            HStack(spacing: 12.scale) {
                selectionBullet

                VStack(alignment: .leading, spacing: 4.scale) {
                    Text(title)
                        .font(Tokens.Font.semibold17)
                        .foregroundStyle(Tokens.Color.paywallPrimaryText)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(Tokens.Font.medium14)
                        .foregroundStyle(Tokens.Color.paywallPrimaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 12.scale)

                Text(priceText)
                    .font(Tokens.Font.semibold17)
                    .foregroundStyle(Tokens.Color.paywallPrimaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16.scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: TokensPaywallView.TokensPaywallLayout.productRowHeight)

            if isTopSelling {
                Text("TOP SELLING")
                    .font(Tokens.Font.medium12)
                    .foregroundStyle(Tokens.Color.surfaceWhite)
                    .frame(width: 95.scale, height: 21.scale)
                    .background(
                        Capsule()
                            .fill(Tokens.Color.paywallSelectedOptionStroke)
                    )
                    .offset(x: -12.scale, y: -10.scale)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(
            RoundedRectangle(
                cornerRadius: PaywallLayout.optionCorner,
                style: .continuous
            )
        )
    }

    private var selectionBullet: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Tokens.Color.paywallSelectedOptionStroke)
                    .frame(width: 24.scale, height: 24.scale)

                Circle()
                    .fill(Tokens.Color.surfaceWhite)
                    .frame(width: 8.scale, height: 8.scale)
            } else {
                Circle()
                    .stroke(Tokens.Color.paywallPrimaryText.opacity(0.15), lineWidth: 1.5.scale)
                    .frame(width: 24.scale, height: 24.scale)
            }
        }
        .frame(width: 24.scale, height: 24.scale)
    }
}
