 

import SwiftUI

struct PlanRow: View {
    let product: BillingProduct
    let isSelected: Bool

    private var displayName: String {
        let t = product.timeString.lowercased()
        if t.contains("week") { return "Weekly" }
        if t.contains("month") { return "Monthly" }
        if t.contains("year") { return "Yearly" }
        return product.timeString.capitalized
    }

    private var badge: String? {
        product.timeString.lowercased().contains("year") ? "Best value" : nil
    }

    private var priceText: String {
        product.localizedPrice
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4.scale) {
                Text(displayName)
                    .font(Tokens.Font.bold15)
                    .foregroundStyle(isSelected ? Tokens.Color.accent : Tokens.Color.textPrimary)

                Text(badge ?? " ")
                    .font(Tokens.Font.regular13)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }

            Spacer(minLength: 0)

            Rectangle()
                .fill(Color.gray.opacity(0.35))
                .frame(width: 1.scale, height: 28.scale)
                .padding(.horizontal, Tokens.Spacing.x12)

            Text(priceText)
                .font(Tokens.Font.bold15)
                .foregroundStyle(isSelected ? Tokens.Color.accent : Tokens.Color.textPrimary)
        }
        .padding(.horizontal, Tokens.Spacing.x16)
    }
}
