import SwiftUI

struct TokensPaywallView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject private var apiManager: APIManager
    @Environment(\.dismiss) var dismiss

    @State private var isLoading: Bool = false
    @State private var pickedProd: BillingProduct?
    @State private var showCloseButton: Bool = false
    @State private var showPurchaseError: Bool = false
    @State private var purchaseErrorMessage: String = ""
    @State private var showSafari = false
    @State private var safariURL: URL? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack(alignment: .top) {
                Image("tokensImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: .infinity, alignment: .top)

                VStack(spacing: 0) {
                    featurePart
                    footerBlock
                }

                closeButton
                    .opacity(showCloseButton ? 1 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                if isLoading {
                    ZStack {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.white)
                            .scaleEffect(2)
                    }
                }
            }
        }
        .animation(.snappy, value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: purchaseManager.tokenProducts)
        .alert("Purchase Error", isPresented: $showPurchaseError) {
            Button("OK", role: .cancel) {
                purchaseErrorMessage = ""
            }
        } message: {
            Text(purchaseErrorMessage)
        }
        .onAppear {
            purchaseManager.trackCurrentPaywallShown(placementID: BillingConfig.adaptyTokensPlacementID)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    showCloseButton = true
                }
            }
        }
        .onDisappear {
            purchaseManager.trackCurrentPaywallClosed(placementID: BillingConfig.adaptyTokensPlacementID)
        }
    }

    var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.6))
                .frame(width: 24, height: 24)
                .padding(6)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    var featurePart: some View {
        VStack(spacing: 16) {
            Text("Get More Tokens")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)

            productsPart
        }
        .padding(.top, 62)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    var footerBlock: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")

                Text(" Cancel anytime")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.4))
            .frame(height: 40)

            MainButton(title: "Continue", isLargeButton: true, cost: nil) {
                guard let pickedProd = pickedProd else {
                    purchaseErrorMessage = "Please select a subscription plan"
                    showPurchaseError = true
                    return
                }
                guard purchaseManager.isReady else {
                    purchaseErrorMessage = purchaseManager.purchaseError ?? "Subscription options are not ready. Please try again."
                    showPurchaseError = true
                    return
                }
                isLoading = true
                purchaseManager.makePurchase(product: pickedProd, completion: { success, errorMessage in
                    isLoading = false
                    if success {
                        dismiss()
                        
                        Task {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            await apiManager.fetchProfile()
                        }
                    } else {
                        purchaseErrorMessage = errorMessage ?? "Purchase failed. Please try again."
                        showPurchaseError = true
                    }
                })
            }
            .disabled(pickedProd == nil || !purchaseManager.isReady || purchaseManager.isLoading)

            links
        }
        .padding(.horizontal, 16)
        .background(
            UnevenRoundedRectangle(cornerRadii: .init(
                topLeading: 16,
                bottomLeading: 0,
                bottomTrailing: 0,
                topTrailing: 16
            )).fill(Color.primaryBackground)
                .ignoresSafeArea(edges: [.bottom])
        )
    }

    var productsPart: some View {
        VStack(spacing: 12) {
            if purchaseManager.purchaseState == .loading {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.white)
                        .scaleEffect(1.5)

                    if let error = purchaseManager.tokenPurchaseError {
                        Text(error)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 32)
            } else if purchaseManager.tokenProducts.isEmpty {
                Text(purchaseManager.tokenPurchaseError ?? "Token packs are unavailable. Please try again later.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 32)
            } else {
                ForEach(purchaseManager.tokenProducts) { product in
                    Button {
                        pickedProd = product
                    } label: {
                        productCard(prod: product, isPicked: pickedProd == product)
                    }
                    .onAppear {
                        if pickedProd == nil || (pickedProd?.price ?? 0) < product.price {
                            pickedProd = product
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var bestOfferProductID: String? {
        purchaseManager.tokenProducts.max(by: { $0.price < $1.price })?.id
    }

    private func tokensTitle(for product: BillingProduct) -> String {
        let firstPart = product.id.split(separator: "_").first ?? ""
        if let amount = Int(firstPart) {
            return "\(amount) Tokens"
        }
        return product.id.replacingOccurrences(of: "_", with: " ")
    }

    func productCard(prod: BillingProduct, isPicked: Bool) -> some View {
        return HStack(spacing: 8) {
            Image(isPicked ? "selected" : "unselected")

            Text(tokensTitle(for: prod))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(prod.localizedPrice)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#252525")).opacity(0.55))
        .overlay(content: {
            if isPicked {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FD9958"),
                                Color(hex: "#E149A0"),
                                Color(hex: "#AB4BC3"),
                                Color(hex: "#6851EA")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .shadow(
                        color: Color(hex: "##BF72FF"),
                        radius: 5
                    )
            }
        })
        .animation(.snappy(duration: 0.2), value: isPicked)
        .overlay(alignment: .topTrailing) {
            if prod.id == bestOfferProductID {
                Text("BEST PRICE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "#292929"))
                    .padding(6)
                    .frame(width: 80, height: 12)
                    .background(
                        UnevenRoundedRectangle(cornerRadii: .init(
                            topLeading: 0,
                            bottomLeading: 10,
                            bottomTrailing: 0,
                            topTrailing: 10
                        )).fill(Color(hex: "#FD9858"))
                    )
            }
        }
        .animation(.interpolatingSpring(duration: 0.2), value: isPicked)
    }

    var links: some View {
        HStack(spacing: 8) {
            Button {
                if let url = URL(string: LinksEnum.privacy.link) {
                    safariURL = url
                    showSafari = true
                }
            } label: {
                linkButton(title: "Privacy Policy", alignment: .leading)
            }

            Spacer()

            Button {
                isLoading = true

                purchaseManager.restorePurchase { isSuccess in
                    if isSuccess {
                        dismiss()
                    }
                    isLoading = false
                }
            } label: {
                linkButton(title: "Restore Purchase")
            }

            Spacer()

            Button {
                if let url = URL(string: LinksEnum.terms.link) {
                    safariURL = url
                    showSafari = true
                }
            } label: {
                linkButton(title: "Terms of Use", alignment: .trailing)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func linkButton(title: LocalizedStringKey, alignment: Alignment = .center) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(Color.white.opacity(0.4))
            .frame(alignment: alignment)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
    }
}

#Preview {
    TokensPaywallView()
        .environmentObject(PurchaseManager.shared)
}
