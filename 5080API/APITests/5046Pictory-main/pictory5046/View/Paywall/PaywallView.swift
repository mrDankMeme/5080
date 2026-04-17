import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject private var apiManager: APIManager
    @Environment(\.dismiss) var dismiss

    @State private var isLoading: Bool = false
    @State private var pickedProd: BillingProduct?
    @State private var showPurchaseError: Bool = false
    @State private var purchaseErrorMessage: String = ""
    @State private var showSafari = false
    @State private var safariURL: URL? = nil
    @AppStorage("OnBoardEnd") var onBoardEnd: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack(alignment: .top) {
                Image("paywallImage")

                VStack(spacing: 0) {
                    featurePart
                    footerBlock
                }

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
        .animation(.easeInOut(duration: 0.2), value: purchaseManager.products)
        .alert("Purchase Error", isPresented: $showPurchaseError) {
            Button("OK", role: .cancel) {
                purchaseErrorMessage = ""
            }
        } message: {
            Text(purchaseErrorMessage)
        }
        .onAppear {
            purchaseManager.trackCurrentPaywallShown()
        }
        .onDisappear {
            purchaseManager.trackCurrentPaywallClosed()
        }
        .onChange(of: purchaseManager.isSubscribed) { _, isSubscribed in
            if isSubscribed {
                if !onBoardEnd {
                    onBoardEnd = true
                }
                dismiss()
            }
        }
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
        .navigationBarBackButtonHidden()
    }

    var featurePart: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Create Without Limits")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 0) {
                    featureLine(icon: "sparkles1", title: "All Photo Edit Tools")
                    featureLine(icon: "sparkles2", title: "Unlimited generation")
                    featureLine(icon: "sparkles3", title: "Access to all functions")
                }

                HStack(spacing: 0) {
                    Text("Get full access or ")
                        .font(.subheadline)
                        .foregroundStyle(Color.white)

                    Button {
                        if !onBoardEnd {
                            onBoardEnd = true
                        }
                        dismiss()
                    } label: {
                        Text("proceed with limits")
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: "#767676"))
                    }
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#252525")).opacity(0.55))
            .padding(.horizontal)

            productsPart
        }
        .padding(.top, 62)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private func featureLine(icon: String, title: String) -> some View {
        HStack(spacing: 4) {
            Image(icon)

            Text(title)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
                        if !onBoardEnd {
                            onBoardEnd = true
                        }
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
            if purchaseManager.purchaseState == .loading || purchaseManager.products.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.white)
                        .scaleEffect(1.5)

                    if let error = purchaseManager.purchaseError {
                        Text(error)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 32)
            } else {
                ForEach(purchaseManager.products.sorted { $0.price > $1.price }, id: \.id) { product in
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

    private func savePercent(againstWeekly weekProduct: BillingProduct, current: BillingProduct) -> Double {
        let weeksInCurrent = weeksInPeriod(periodTitle: current.periodTitle ?? "")
        guard weeksInCurrent > 1 else { return 0 }
        let weekPrice = NSDecimalNumber(decimal: weekProduct.price).doubleValue
        let currentPrice = NSDecimalNumber(decimal: current.price).doubleValue
        guard weekPrice > 0 else { return 0 }
        let equivalentIfWeekly = weekPrice * Double(weeksInCurrent)
        guard equivalentIfWeekly > currentPrice else { return 0 }
        return (equivalentIfWeekly - currentPrice) / equivalentIfWeekly * 100
    }

    private func weeksInPeriod(periodTitle: String) -> Double {
        switch periodTitle.lowercased() {
        case "week": return 1
        case "month": return 30.0 / 7.0
        case "year": return 365.0 / 7.0
        default: return 1
        }
    }

    func productCard(prod: BillingProduct, isPicked: Bool) -> some View {
        let timeString = prod.periodTitle ?? "month"

        return HStack(spacing: 8) {
            Image(isPicked ? "selected" : "unselected")

            Text(timeString.capitalizingFirstLetter() + "ly")
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
            if timeString.lowercased() != "week",
               let weekProduct = purchaseManager.products.first(where: { ($0.periodTitle ?? "").lowercased() == "week" })
            {
                let savePercent = savePercent(againstWeekly: weekProduct, current: prod)
                if savePercent > 0 && savePercent < 100 {
                    Text("SAVE \(Int(savePercent.rounded()))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#292929"))
                        .padding(6)
                        .frame(width: 75, height: 12)
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
                        if !onBoardEnd {
                            onBoardEnd = true
                        }
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
    PaywallView()
        .environmentObject(PurchaseManager.shared)
}
