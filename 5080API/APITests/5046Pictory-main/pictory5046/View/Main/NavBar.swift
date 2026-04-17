import SwiftUI

struct NavBar: View {
    @ObservedObject var mainViewModel: MainViewModel
    
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    @State private var showPaywall: Bool = false
    @State private var showTokensPaywall: Bool = false
    @State private var showSettings: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                Text(mainViewModel.selectedTab.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                HStack(spacing: 10) {
                    Button {
                        showSettings = true
                    } label: {
                        Image("settings")
                            .frame(width: 32, height: 32)
                    }
                    
                    Button {
                        if !purchaseManager.isSubscribed {
                            showPaywall = true
                        } else {
                            showTokensPaywall = true
                        }
                    } label: {
                        HStack {
                            if !purchaseManager.isSubscribed {
                                Text("PRO")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                
                                Image("sparkles")
                                    .frame(height: 32)
                            } else {
                                Image("rhombus.fill")
                                    .frame(height: 32)
                                
                                Text("\(purchaseManager.availableGenerations)")
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 40).fill(
                            LinearGradient(colors: [Color(hex: "#D447AB"), Color(hex: "#7650E3")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                    }
                }
            }
        }
        .background(Color.primaryBackground)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $showTokensPaywall) {
            TokensPaywallView()
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView(mainViewModel: mainViewModel)
        }
    }
}


