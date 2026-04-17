import SwiftUI

struct PaywallPlanRowView: View {

    let product: BillingProduct
    let isPicked: Bool

    let planTitle: String
    let planSubtitle: String
    let planPriceText: String
    let planSecondaryPriceText: String?

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: PaywallLayout.optionCorner,
                style: .continuous
            )
            .fill(backgroundStyle)
            .overlay(
                RoundedRectangle(
                    cornerRadius: PaywallLayout.optionCorner,
                    style: .continuous
                )
                .stroke(strokeStyle, lineWidth: strokeLineWidth)
            )

            HStack(spacing: 12.scale) {
                VStack(alignment: .leading, spacing: 4.scale) {
                    Text(planTitle)
                        .font(Tokens.Font.semibold17)
                        .foregroundStyle(titleStyle)
                        .lineLimit(1)

                    Text(planSubtitle)
                        .font(Tokens.Font.regular13)
                        .foregroundStyle(subtitleStyle)
                        .lineLimit(1)
                }

                Spacer(minLength: 12.scale)

                VStack(alignment: .trailing, spacing: 2.scale) {
                    Text(planPriceText)
                        .font(Tokens.Font.semibold17)
                        .foregroundStyle(titleStyle)
                        .lineLimit(1)

                    if let planSecondaryPriceText {
                        Text(planSecondaryPriceText)
                            .font(Tokens.Font.regular13)
                            .foregroundStyle(subtitleStyle)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 16.scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: PaywallLayout.productRowHeight)
        }
        .frame(maxWidth: .infinity)
        .contentShape(
            RoundedRectangle(
                cornerRadius: PaywallLayout.optionCorner,
                style: .continuous
            )
        )
    }

    // MARK: - Styles

    private var backgroundStyle: AnyShapeStyle {
        if isPicked {
            return AnyShapeStyle(Tokens.Color.accentGradient)
        } else {
            return AnyShapeStyle(Color(hex: "222E4A") ?? Color(red: 34/255, green: 46/255, blue: 74/255))
        }
    }

    private var strokeStyle: AnyShapeStyle {
        isPicked
        ? AnyShapeStyle(Color.white.opacity(0.95))
        : AnyShapeStyle(Color.black.opacity(0.15))
    }

    private var strokeLineWidth: CGFloat {
        isPicked ? 2.scale : 1.scale
    }

    private var titleStyle: AnyShapeStyle {
        isPicked
        ? AnyShapeStyle(Color.white)
        : AnyShapeStyle(Tokens.Color.textPrimary)
    }

    private var subtitleStyle: AnyShapeStyle {
        isPicked
        ? AnyShapeStyle(Color.white.opacity(0.85))
        : AnyShapeStyle(Tokens.Color.textSecondary)
    }
}
