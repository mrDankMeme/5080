import SwiftUI

struct PaywallPlanRowView: View {
    let isPicked: Bool

    let planTitle: String
    let planSubtitle: String
    let planPriceText: String
    let badgeText: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
                selectionBullet

                VStack(alignment: .leading, spacing: 4.scale) {
                    Text(planTitle)
                        .font(Tokens.Font.semibold17)
                        .foregroundStyle(titleStyle)
                        .lineLimit(1)

                    Text(planSubtitle)
                        .font(Tokens.Font.medium14)
                        .foregroundStyle(subtitleStyle)
                        .lineLimit(1)
                }

                Spacer(minLength: 12.scale)

                Text(planPriceText)
                    .font(Tokens.Font.semibold17)
                    .foregroundStyle(titleStyle)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16.scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: PaywallLayout.productRowHeight)

            if let badgeText {
                Text(badgeText)
                    .font(Tokens.Font.medium13)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10.scale)
                    .frame(height: 26.scale)
                    .background(
                        Capsule()
                            .fill(Tokens.Color.paywallSelectedOptionStroke)
                    )
                    .offset(x: -12.scale, y: -13.scale)
            }
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
            return AnyShapeStyle(Tokens.Color.paywallSelectedOptionFill)
        } else {
            return AnyShapeStyle(Tokens.Color.paywallOptionFill)
        }
    }

    private var strokeStyle: AnyShapeStyle {
        isPicked
        ? AnyShapeStyle(Tokens.Color.paywallSelectedOptionStroke)
        : AnyShapeStyle(Tokens.Color.paywallOptionStroke)
    }

    private var strokeLineWidth: CGFloat {
        isPicked ? 2.scale : 1.scale
    }

    private var titleStyle: AnyShapeStyle {
        AnyShapeStyle(Tokens.Color.paywallPrimaryText)
    }

    private var subtitleStyle: AnyShapeStyle {
        AnyShapeStyle(Tokens.Color.paywallSecondaryText)
    }

    private var selectionBullet: some View {
        ZStack {
            if isPicked {
                Circle()
                    .fill(Tokens.Color.paywallSelectedOptionStroke)
                    .frame(width: 24.scale, height: 24.scale)

                Circle()
                    .fill(Color.white)
                    .frame(width: 8.scale, height: 8.scale)
            } else {
                Circle()
                    .stroke(Tokens.Color.paywallPrimaryText.opacity(0.15), lineWidth: 1.5.scale)
                    .frame(width: 24.scale, height: 24.scale)
            }
        }
        .frame(width: 24.scale, height: 24.scale)
    }
}
