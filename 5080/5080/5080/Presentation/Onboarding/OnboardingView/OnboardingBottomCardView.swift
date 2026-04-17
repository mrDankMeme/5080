
import SwiftUI

struct OnboardingBottomCardView: View {
    let title: String
    let subtitle: String

    let bottomSafeInset: CGFloat

    var isPrimaryLoading: Bool = false

    let onPrimaryTap: () -> Void
    let onOpenTerms: () -> Void
    let onRestoreTap: () -> Void
    let onOpenPrivacy: () -> Void

    private var layoutType: DeviceLayoutType {
        DeviceLayout.type
    }

    private var cardMinHeight: CGFloat {
        switch layoutType {
        case .smallStatusBar:
            return 214.scale
        case .iPad:
            return 228.scale
        case .unknown:
            return 220.scale
        case .notch, .dynamicIsland:
            return 234.scale
        }
    }

    private var contentBottomPadding: CGFloat {
        switch layoutType {
        case .smallStatusBar:
            return 10.scale
        case .iPad:
            return max(12.scale, bottomSafeInset)
        case .unknown:
            return max(10.scale, bottomSafeInset)
        case .notch, .dynamicIsland:
            return max(8.scale, bottomSafeInset)
        }
    }

    private var horizontalPadding: CGFloat {
        switch layoutType {
        case .smallStatusBar:
            return 16.scale
        case .iPad:
            return 40.scale
        case .unknown:
            return 20.scale
        case .notch, .dynamicIsland:
            return 24.scale
        }
    }

    private var buttonTopPadding: CGFloat {
        switch layoutType {
        case .smallStatusBar:
            return 22.scale
        case .iPad:
            return 28.scale
        case .unknown:
            return 24.scale
        case .notch, .dynamicIsland:
            return 26.scale
        }
    }

    private var footerTopPadding: CGFloat {
        switch layoutType {
        case .smallStatusBar:
            return 16.scale
        case .iPad:
            return 18.scale
        case .unknown:
            return 16.scale
        case .notch, .dynamicIsland:
            return 18.scale
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(Tokens.Font.onboardingTitle20)
                .foregroundStyle(Tokens.Color.onboardingTitle)
                .lineSpacing(2.scale)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20.scale)
                .padding(.horizontal, horizontalPadding)

            Text(subtitle)
                .font(Tokens.Font.onboardingBody16)
                .foregroundStyle(Tokens.Color.onboardingSubtitle)
                .lineSpacing(4.scale)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16.scale)
                .padding(.horizontal, horizontalPadding)

            Button(action: onPrimaryTap) {
                ZStack {
                    Text("Continue")
                        .opacity(isPrimaryLoading ? 0 : 1)

                    if isPrimaryLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                }
                .font(Tokens.Font.onboardingButton16)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60.scale)
                .background(Tokens.Color.onboardingContinueButton)
                .cornerRadiusContinuous(24.scale)
            }
            .buttonStyle(.plain)
            .disabled(isPrimaryLoading)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, buttonTopPadding)

            HStack(spacing: 0) {
                footerButton(title: "Terms of Use", action: onOpenTerms)
                footerSeparator
                footerButton(title: "Restore", action: onRestoreTap)
                footerSeparator
                footerButton(title: "Privacy Policy", action: onOpenPrivacy)
            }
            .padding(.top, footerTopPadding)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
        }
        .padding(.bottom, contentBottomPadding)
        .frame(maxWidth: .infinity)
        .frame(minHeight: cardMinHeight, alignment: .top)
        .background(Color.clear)
    }
}

private extension OnboardingBottomCardView {
    func footerButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Tokens.Font.onboardingFooter13)
                .foregroundStyle(Tokens.Color.onboardingFooter)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
    }

    var footerSeparator: some View {
        Text("|")
            .font(Tokens.Font.onboardingFooter13)
            .foregroundStyle(Tokens.Color.onboardingFooter)
            .padding(.horizontal, 10.scale)
    }
}
