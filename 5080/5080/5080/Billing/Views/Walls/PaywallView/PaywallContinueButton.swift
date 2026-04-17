
import SwiftUI

struct PaywallContinueButton: View {

    let title: String
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(Tokens.Font.semibold17)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: PaywallLayout.continueHeight)
                .background(
                    RoundedRectangle(
                        cornerRadius: Tokens.Radius.medium,
                        style: .continuous
                    )
                    .fill(Tokens.Color.accentGradient)
                )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.55)
    }
}
