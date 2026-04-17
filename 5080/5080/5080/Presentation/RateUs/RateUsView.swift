import StoreKit
import SwiftUI
import UIKit

struct RateUsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @ObservedObject var viewModel: RateUsViewModel

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0.scale) {
                RateUsHeaderView(title: viewModel.navigationTitle) {
                    dismiss()
                }
                .padding(.horizontal, 16.scale)
                .padding(.top, 16.scale)

                Spacer(minLength: 40.scale)

                VStack(spacing: 32.scale) {
                    Image("rateus_hand")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 158.scale, height: 227.scale)

                    VStack(spacing: 12.scale) {
                        Text(viewModel.titleText)
                            .font(Tokens.Font.outfitSemibold18)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .kerning(-0.18.scale)
                            .multilineTextAlignment(.center)

                        Text(viewModel.descriptionText)
                            .font(Tokens.Font.regular16)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .kerning(0.16.scale)
                            .lineSpacing(8.scale)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32.scale)

                Spacer(minLength: 0.scale)

                VStack(spacing: 20.scale) {
                    Button {
                        viewModel.handleRateTap()
                    } label: {
                        Text(viewModel.primaryButtonTitle)
                            .font(Tokens.Font.semibold16)
                            .foregroundStyle(Tokens.Color.surfaceWhite)
                            .kerning(-0.16.scale)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56.scale)
                            .background(Tokens.Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 18.scale, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.handleMaybeLaterTap()
                    } label: {
                        Text(viewModel.secondaryButtonTitle)
                            .font(Tokens.Font.semibold16)
                            .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.6))
                            .kerning(-0.16.scale)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32.scale)
                .padding(.bottom, max(8.scale, (proxy.safeAreaInsets.bottom + 8.scale) / 3))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background(Tokens.Color.surfaceWhite.ignoresSafeArea())
        }
        .sheet(
            item: Binding(
                get: { viewModel.mailComposerPayload },
                set: { payload in
                    if payload == nil {
                        viewModel.dismissMailComposer()
                        dismiss()
                    }
                }
            )
        ) { payload in
            MailComposerView(payload: payload)
        }
        .onChange(of: viewModel.isReviewRequested) { _, isRequested in
            guard isRequested else { return }
            requestReview()
            viewModel.completeReviewRequest()
            dismiss()
        }
    }
}

private extension RateUsView {
    func requestReview() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            openURL(viewModel.appStoreURL)
            return
        }

        AppStore.requestReview(in: windowScene)
    }
}
