import AppTrackingTransparency
import StoreKit
import SwiftUI

struct OnBoardView: View {
    @State private var currentPage: Int = 0
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.requestReview) private var requestReview
    @State var showPaywall = false
    @State private var showSafari = false
    @State private var safariURL: URL? = nil
    @State private var isLoading: Bool = false
    @State private var showPurchaseError: Bool = false
    @State private var purchaseErrorMessage: String = ""
    @AppStorage("OnBoardEnd") var onBoardEnd: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if currentPage < 4 {
                    Color.primaryBackground.ignoresSafeArea()
                        .overlay(alignment: .top) {
                            OnBoardCards(currentPage: currentPage)
                        }
                    
                    VStack(spacing: 0) {
                        Spacer()
                        footer
                            .padding(.top, 64)
                            .background(
                                LinearGradient(stops: [.init(color: Color.primaryBackground.opacity(0), location: 0), .init(color: Color.primaryBackground, location: 0.4)], startPoint: .top, endPoint: .bottom)
                            )
                    }
                    .opacity(currentPage < 4 ? 1 : 0)
                    .offset(x: currentPage < 4 ? 0 : -UIScreen.main.bounds.width)
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
            .navigationDestination(isPresented: $showPaywall) {
                PaywallView()
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    requestTrackingPermission()
                }
            }
            .sheet(isPresented: $showSafari) {
                if let url = safariURL {
                    SafariView(url: url)
                }
            }
            .alert("Purchase Error", isPresented: $showPurchaseError) {
                Button("OK", role: .cancel) {
                    purchaseErrorMessage = ""
                }
            } message: {
                Text(purchaseErrorMessage)
            }
        }
    }
    
    var footer: some View {
        VStack(spacing: 24) {
            OnBoardText(currentPage: currentPage)
            
            continueButton
        }
        .padding(.bottom, 8)
        .padding(.horizontal, 16)
    }
    
    var continueButton: some View {
        VStack(spacing: 8) {
            MainButton(title: "Continue", isLargeButton: true, cost: nil) {
                withAnimation {
                    if currentPage == 2 {
                        requestReview()
                    }
                    if currentPage >= 3 {
                        currentPage = 4
                    } else {
                        currentPage += 1
                    }
                    
                    if currentPage == 4 {
                        showPaywall = true
                    }
                }
            }
            
            links
        }
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
    
    func requestTrackingPermission() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("User allowed tracking.")
                case .denied:
                    print("User denied permission.")
                case .restricted:
                    print("Tracking is restricted.")
                case .notDetermined:
                    print("Permission has not been requested.")
                @unknown default:
                    print("Unknown status.")
                }
            }
        } else {
            print("App Tracking Transparency is not available on this iOS version.")
        }
    }
}

#Preview {
    OnBoardView()
        .environmentObject(PurchaseManager.shared)
}

struct OnBoardText: View {
    var currentPage: Int
        
    var body: some View {
        ZStack(alignment: .bottom) {
            textPage(
                title: "Plenty of templates to spark your ideas"
            )
            .offset(x: CGFloat(0 - currentPage) * UIScreen.main.bounds.width)
            
            textPage(
                title: "Lots of templates for ideas"
            )
            .offset(x: CGFloat(1 - currentPage) * UIScreen.main.bounds.width)
            
            textPage(
                title: "Make any of your dreams come true"
            )
            .offset(x: CGFloat(2 - currentPage) * UIScreen.main.bounds.width)
            
            textPage(
                title: "Rate our app in the AppStore"
            )
            .offset(x: CGFloat(3 - currentPage) * UIScreen.main.bounds.width)
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func textPage(title: String) -> some View {
        Text(title)
            .font(.instrumentSans(34))
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.center)
            .padding()
    }
}

struct OnBoardCards: View {
    var currentPage: Int
    
    var body: some View {
        ZStack(alignment: .top) {
            imageCard(image: "onboard1")
                .offset(x: CGFloat(0 - currentPage) * UIScreen.main.bounds.width)
            
            imageCard(image: "onboard2")
                .offset(x: CGFloat(1 - currentPage) * UIScreen.main.bounds.width)
            
            imageCard(image: "onboard3")
                .offset(x: CGFloat(2 - currentPage) * UIScreen.main.bounds.width)
            
            imageCard(image: "onboard4")
                .offset(x: CGFloat(3 - currentPage) * UIScreen.main.bounds.width)
        }
    }
    
    @ViewBuilder
    private func imageCard(image: String) -> some View {
        ZStack {
            Image(image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    Color.primaryBackground.opacity(0),
                    Color.primaryBackground
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
