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

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var onDismiss: (() -> Void)? = nil

    @State private var selectedProductId: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var activeSheet: TokensPaywallSheet?
    @State private var alertModel: TokensPaywallAlert?
    @State private var isOverlayVisible = false
    @State private var isSheetVisible = false
    @State private var sheetDragOffset: CGFloat = 0.scale
    @State private var isClosing = false

    private var selectedProduct: BillingProduct? {
        sortedTokenProducts.first(where: { $0.id == selectedProductId })
    }

    private var sortedTokenProducts: [BillingProduct] {
        purchaseManager.tokenProducts.sorted { lhs, rhs in
            let lhsAmount = tokenAmount(from: lhs.id) ?? .max
            let rhsAmount = tokenAmount(from: rhs.id) ?? .max

            if lhsAmount != rhsAmount {
                return lhsAmount < rhsAmount
            }

            return lhs.price < rhs.price
        }
    }

    private var canPurchase: Bool {
        !isPurchasing && selectedProduct != nil && purchaseManager.isTokensReady
    }

    private var termsURL: URL? {
        AppExternalResources.termsOfUseURL
    }

    private var privacyURL: URL? {
        AppExternalResources.privacyPolicyURL
    }

    var body: some View {
        GeometryReader { geometry in
            let sheetHeight = sheetHeight(
                availableHeight: geometry.size.height,
                safeBottom: geometry.safeAreaInsets.bottom
            )
            let hiddenOffset = sheetHeight

            ZStack(alignment: .bottom) {
                Color.black
                    .opacity(isOverlayVisible ? 0.5 : 0.0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard canDismissSheet else { return }
                        dismissSheet()
                    }

                paywallCard(
                    safeBottom: geometry.safeAreaInsets.bottom,
                    cardHeight: sheetHeight
                )
                    .offset(y: (isSheetVisible ? 0.scale : hiddenOffset) + sheetDragOffset)
                    .gesture(sheetDragGesture)
            }
            .ignoresSafeArea()
            .preferredColorScheme(.light)
        }
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
            purchaseManager.debugLogTokenPaywallState(context: "TokensPaywallView.onAppear.afterPreselect")

            presentSheet()
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
            purchaseManager.debugLogTokenPaywallState(context: "TokensPaywallView.onDisappear")
            purchaseManager.trackCurrentPaywallClosed(placementID: BillingConfig.adaptyTokensPlacementID)
        }
    }

    private func paywallCard(safeBottom: CGFloat, cardHeight: CGFloat) -> some View {
        VStack(spacing: 0.scale) {
            Capsule()
                .fill(Tokens.Color.modeSheetPill)
                .frame(width: 40.scale, height: 5.scale)
                .padding(.top, 8.scale)

            Text("Get Sparks")
                .font(Tokens.Font.outfitSemibold22)
                .foregroundStyle(Tokens.Color.inkPrimary)
                .kerning(-0.22.scale)
                .padding(.top, 19.scale)

            tokenProductsSection
                .padding(.top, 16.scale)
                .padding(.horizontal, 16.scale)

            if let errorMessage,
               !sortedTokenProducts.isEmpty || errorMessage != purchaseManager.tokenPurchaseError {
                Text(errorMessage)
                    .font(Tokens.Font.regular13)
                    .foregroundStyle(Tokens.Color.destructive)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12.scale)
                    .padding(.horizontal, 20.scale)
            }

            Button {
                continuePurchase()
            }
            label: {
                Text(isPurchasing ? "Processing..." : "Continue")
                    .font(Tokens.Font.semibold17)
                    .foregroundStyle(Tokens.Color.surfaceWhite)
                    .kerning(-0.17.scale)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52.scale)
                    .background(
                        RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                            .fill(Tokens.Color.accent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canPurchase)
            .opacity(canPurchase ? 1.0 : 0.55)
            .padding(.top, 16.scale)
            .padding(.horizontal, 16.scale)

            footerLinks
                .padding(.top, 8.scale)

            Spacer(minLength: footerBottomSpacing(safeBottom: safeBottom))
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: cardHeight, alignment: .top)
        .background(
            Tokens.Color.surfaceWhite
        )
        .clipShape(
            TokensPaywallTopRoundedCornersShape(radius: 32.scale)
        )
    }

    @ViewBuilder
    private var tokenProductsSection: some View {
        if sortedTokenProducts.isEmpty {
            VStack(spacing: 12.scale) {
                if purchaseManager.tokenPurchaseError == nil {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Tokens.Color.accent)
                }

                Text(purchaseManager.tokenPurchaseError ?? "Loading token packs...")
                    .font(Tokens.Font.regular16)
                    .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180.scale)
        } else {
            VStack(spacing: 12.scale) {
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
            HStack(spacing: 12.scale) {
                tokenRowIcon
                    .frame(width: 18.scale, height: 18.scale)

                Text(tokenTitle(from: product.id))
                    .font(Tokens.Font.outfitSemibold18)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .kerning(-0.17.scale)
                    .lineLimit(1)

                Spacer(minLength: 12.scale)

                Text(product.localizedPrice)
                    .font(Tokens.Font.semibold17)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .kerning(-0.17.scale)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16.scale)
            .frame(maxWidth: .infinity)
            .frame(height: 53.scale)
            .background(
                RoundedRectangle(cornerRadius: 40.scale, style: .continuous)
                    .fill(isSelected ? Tokens.Color.surfaceWhite : Tokens.Color.cardSoftBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 40.scale, style: .continuous)
                    .stroke(
                        isSelected ? Tokens.Color.accent : Color.clear,
                        lineWidth: 2.scale
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var footerLinks: some View {
        HStack(spacing: 32.scale) {
            footerButton("Privacy Policy") {
                if let privacyURL {
                    activeSheet = .safari(privacyURL)
                }
            }

            footerButton(isRestoring ? "Restoring..." : "Restore") {
                restorePurchases()
            }
            .disabled(isRestoring)

            footerButton("Terms of Use") {
                if let termsURL {
                    activeSheet = .safari(termsURL)
                }
            }
        }
        .buttonStyle(.plain)
        .font(Tokens.Font.regular13)
        .kerning(0.13.scale)
        .foregroundStyle(Color(hex: "141414")?.opacity(0.6) ?? Color.black.opacity(0.6))
        .frame(maxWidth: .infinity)
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
        }
    }

    private var tokenRowIcon: some View {
        Group {
            if let image = UIImage(named: "Loader.Icon") {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Tokens.Color.accent)
            } else {
                Image(systemName: "sparkles")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Tokens.Color.accent)
            }
        }
    }

    private func preselectIfNeeded() {
        if selectedProduct == nil {
            selectedProductId = sortedTokenProducts.first?.id
        }
    }

    private func tokenTitle(from id: String) -> String {
        guard let tokenValue = tokenAmount(from: id) else {
            return "Token pack"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0

        return formatter.string(from: NSNumber(value: tokenValue)) ?? "\(tokenValue)"
    }

    private func tokenAmount(from id: String) -> Int? {
        let parts = id.split { !$0.isNumber }
        guard let firstNumericChunk = parts.first else { return nil }
        return Int(firstNumericChunk)
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

    private func sheetHeight(availableHeight: CGFloat, safeBottom: CGFloat) -> CGFloat {
        let baseHeight: CGFloat

        switch DeviceLayout.type {
        case .smallStatusBar:
            baseHeight = 424.scale
        case .iPad:
            baseHeight = 492.scale
        case .unknown:
            baseHeight = 450.scale
        case .notch, .dynamicIsland:
            baseHeight = 482.scale
        }

        let minHeight = DeviceLayout.isPad ? 430.scale : 400.scale
        let maxHeight = max(380.scale, availableHeight - (DeviceLayout.isPad ? 110.scale : 80.scale))

        return min(max(baseHeight + safeBottom, minHeight), maxHeight)
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
                dismissSheet()
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

    private var canDismissSheet: Bool {
        !isPurchasing && !isRestoring && !isClosing
    }

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 4.scale, coordinateSpace: .global)
            .onChanged { value in
                guard canDismissSheet else { return }
                sheetDragOffset = max(0.scale, value.translation.height)
            }
            .onEnded { value in
                guard canDismissSheet else {
                    sheetDragOffset = 0.scale
                    return
                }

                let shouldDismiss = value.translation.height > 120.scale || value.predictedEndTranslation.height > 180.scale
                guard shouldDismiss else {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        sheetDragOffset = 0.scale
                    }
                    return
                }

                dismissSheet()
            }
    }

    private func presentSheet() {
        withAnimation(.easeOut(duration: 0.14)) {
            isOverlayVisible = true
        }

        withAnimation(.spring(response: 0.26, dampingFraction: 0.92)) {
            isSheetVisible = true
        }
    }

    private func dismissSheet() {
        guard !isClosing else { return }

        isClosing = true

        withAnimation(.easeOut(duration: 0.16)) {
            isOverlayVisible = false
        }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            isSheetVisible = false
            sheetDragOffset = 0.scale
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 240_000_000)
            completeClose()
        }
    }

    private func completeClose() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

private struct TokensPaywallTopRoundedCornersShape: Shape {
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
