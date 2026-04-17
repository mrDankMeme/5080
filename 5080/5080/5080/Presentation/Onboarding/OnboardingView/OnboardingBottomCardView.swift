
import SwiftUI
import UIKit

struct OnboardingBottomCardView: View {
    let title: String
    let subtitle: String
    let currentIndex: Int
    let pageCount: Int

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
            return 228.scale
        case .iPad:
            return 240.scale
        case .unknown:
            return 244.scale
        case .notch, .dynamicIsland:
            return 254.scale
        }
    }

    private var topIndicatorPadding: CGFloat {
        switch layoutType {
        case .smallStatusBar:
            return 12.scale
        case .iPad:
            return 18.scale
        case .unknown:
            return 14.scale
        case .notch, .dynamicIsland:
            return 16.scale
        }
    }

    private var contentBottomPadding: CGFloat {
        switch layoutType {
        case .smallStatusBar:
            return 16.scale
        case .iPad:
            return max(20.scale, bottomSafeInset)
        case .unknown:
            return max(16.scale, bottomSafeInset)
        case .notch, .dynamicIsland:
            return max(12.scale, bottomSafeInset)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4.scale) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(Tokens.Color.accent.opacity(index <= currentIndex ? 1.0 : 0.2))
                        .frame(width: 24.scale, height: 4.scale)
                }
            }
            .padding(.top, topIndicatorPadding)

            Text(title)
                .font(Tokens.Font.outfitBold28)
                .kerning(-0.28.scale)
                .foregroundStyle(Color(hex: "141414") ?? .black)
                .lineSpacing(4.scale)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16.scale)

            Text(subtitle)
                .font(Tokens.Font.regular16)
                .kerning(0.16.scale)
                .foregroundStyle(Color(hex: "141414")?.opacity(0.86) ?? Color.black.opacity(0.86))
                .lineSpacing(8.scale)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12.scale)
                .padding(.horizontal, 16.scale)

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
                .font(Tokens.Font.semibold17)
                .kerning(-0.17.scale)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52.scale)
                .background(Tokens.Color.accent)
                .cornerRadiusContinuous(16.scale)
            }
            .buttonStyle(.plain)
            .disabled(isPrimaryLoading)
            .padding(.horizontal, 16.scale)
            .padding(.top, 16.scale)

            HStack(spacing: 32.scale) {
                Button(action: onOpenPrivacy) {
                    Text("Privacy Policy")
                }
                Button(action: onRestoreTap) {
                    Text("Restore")
                }
                Button(action: onOpenTerms) {
                    Text("Terms of Use")
                }
            }
            .font(Tokens.Font.regular13)
            .kerning(0.13.scale)
            .foregroundStyle(Color(hex: "14141499") ?? Color.black.opacity(0.6))
            .padding(.top, layoutType == .smallStatusBar ? 6.scale : 8.scale)
            .buttonStyle(.plain)
        }
        .padding(.bottom, contentBottomPadding)
        .frame(maxWidth: .infinity)
        .frame(minHeight: cardMinHeight, alignment: .top)
        .background(Color.white)
        .clipShape(
            TopRoundedCornersShape(radius: 32.scale)
        )
    }
}

private struct TopRoundedCornersShape: Shape {
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
