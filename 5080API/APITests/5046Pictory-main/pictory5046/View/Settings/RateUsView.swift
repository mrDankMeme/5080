import MessageUI
import StoreKit
import SwiftUI

struct RateUsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var showSafari = false
    @State private var safariURL: URL?
    @State private var showMail = false
    
    private var supportEmail: String { "manteroimalo627@gmail.com" }

    private var mailSubject: String {
        "App Feedback"
    }

    private var mailBody: String {
        """
        Hi, I would like to share some feedback:
        
        App version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
        Device: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        
        Feedback:
        """
    }
    
    var body: some View {
        ZStack {
            Color.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 32) {
                    Image("rateus")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 192, height: 158)
                    
                    VStack(spacing: 16) {
                        Text("Do you like our app?")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Please rate our app so we can improve it for you and make it even cooler")
                            .font(.footnote)
                            .foregroundColor(Color.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 10) {
                    MainButton(title: "Rate App", isLargeButton: true, cost: nil) {
                        openWriteReview()
                    }
                    
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showMail = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text("Send Feedback")
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 40)
                                    .fill(Color(hex: "##252525").opacity(0.55))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 40)
                                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08)))
            .padding()
        }
        .background(Color.primaryBackground)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showSafari, onDismiss: {
            dismiss()
        }) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showMail, onDismiss: {
            dismiss()
        }) {
            MailView(
                subject: mailSubject,
                body: mailBody,
                toRecipients: [supportEmail]
            )
        }
    }
    
    private func openWriteReview() {
        let appID = "6760009343"
        
        if let url = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") {
            safariURL = url
            showSafari = true
        }
    }
}

#Preview {
    RateUsView()
}
