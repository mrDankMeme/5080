import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @ObservedObject var mainViewModel: MainViewModel
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var isShareSheetShowing = false
    @State private var showPaywall = false
    @State private var showTokensPaywall = false
    @State private var showRateUs = false
    @State private var cacheSizeText = "0 MB"
    @State private var showAlert = false
    @State private var showSafari = false
    @State private var safariURL: URL? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            header
            
            main
                .padding(.top, 20)
        }
        .background(Color.primaryBackground)
        .onAppear {
            refreshCacheSize()
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $showTokensPaywall) {
            TokensPaywallView()
        }
        .fullScreenCover(isPresented: $showRateUs) {
            RateUsView()
        }
        .sheet(isPresented: $isShareSheetShowing) {
            ShareSheet(activityItems: [LinksEnum.share.link])
                .presentationDetents([.medium])
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Clear cache?"),
                message: Text("The cached files of your videos will be deleted from your phone's memory. But your download history will be retained."),
                primaryButton: .destructive(Text("Clear"), action: performClearCache),
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
    }
    
    var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .contentShape(Rectangle())
                    .padding(.leading)
            }

            Spacer()

            Text("Settings")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Spacer()

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
        .padding(.horizontal)
    }
    
    var main: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 22) {
                supportUs
                purchasesAndActions
                infoLegalPart
                appVersion
                    .padding(.top, -20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
    
    var supportUs: some View {
        VStack(alignment: .leading, spacing: 3) {
            groupTitle("Support us")
            
            VStack(alignment: .leading, spacing: 8) {
                SettingsButton(icn: "star",
                               title: "Rate app", onAction: {
                                   showRateUs = true
                               })
                SettingsButton(icn: "square.and.arrow.up",
                               title: "Share with friends", onAction: {
                                   isShareSheetShowing = true
                               })
            }
            .padding(.vertical, 5)
        }
    }
    
    var purchasesAndActions: some View {
        VStack(alignment: .leading, spacing: 3) {
            groupTitle("Purchases & Actions")
            
            VStack(alignment: .leading, spacing: 8) {
                if !purchaseManager.isSubscribed {
                    SettingsButton(icn: "sparkles",
                                   title: "Upgrade plan", onAction: {
                                       showPaywall = true
                                   })
                }
                
                SettingsButton(icn: "trash",
                               title: "Clear cache", onAction: {
                                   confirmCacheClear()
                               })
                               .overlay(alignment: .trailing) {
                                   Text(cacheSizeText)
                                       .font(.system(size: 17, weight: .regular))
                                       .foregroundStyle(Color.gray)
                                       .padding(.trailing, 52)
                               }
                SettingsButton(icn: "arrow.trianglehead.clockwise.icloud",
                               title: "Restore purchases", onAction: {
                                   purchaseManager.restorePurchase { _ in
                                   }
                               })
            }
            .padding(.vertical, 5)
        }
    }
    
    var infoLegalPart: some View {
        VStack(alignment: .leading, spacing: 3) {
            groupTitle("Info & legal")
            
            VStack(alignment: .leading, spacing: 8) {
                SettingsButton(icn: "text.bubble",
                               title: "Contact us", onAction: {
                                   if let url = URL(string: LinksEnum.support.link) {
                                       safariURL = url
                                       showSafari = true
                                   }
                               })
                SettingsButton(icn: "folder.badge.person.crop",
                               title: "Privacy Policy", onAction: {
                                   if let url = URL(string: LinksEnum.privacy.link) {
                                       safariURL = url
                                       showSafari = true
                                   }
                               })
                SettingsButton(icn: "text.document",
                               title: "Usage Policy", onAction: {
                                   if let url = URL(string: LinksEnum.terms.link) {
                                       safariURL = url
                                       showSafari = true
                                   }
                               })
            }
            .padding(.vertical, 5)
        }
    }
    
    var appVersion: some View {
        Text("App Version: " + mainViewModel.appVersion)
            .font(.footnote)
            .foregroundStyle(Color.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
    }
    
    @ViewBuilder
    private func groupTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.white.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
    }
    
    private func confirmCacheClear() {
        showAlert = true
    }
    
    private func performClearCache() {
        ImageCacheManager.shared.clearCache()
        VideoStorageManager.clearAllVideos()
        URLCache.shared.removeAllCachedResponses()
        refreshCacheSize()
    }
    
    private func refreshCacheSize() {
        let totalBytes = ImageCacheManager.shared.diskCacheSizeInBytes()
            + VideoStorageManager.totalStorageSizeInBytes()
            + Int64(URLCache.shared.currentDiskUsage)
        cacheSizeText = formatMegabytes(totalBytes)
    }
    
    private func formatMegabytes(_ bytes: Int64) -> String {
        let megabytes = Double(max(bytes, 0)) / (1024 * 1024)
        if megabytes < 0.05 { return "0 MB" }
        if megabytes >= 10 {
            return String(format: "%.0f MB", megabytes)
        }
        return String(format: "%.1f MB", megabytes)
    }
}
