
import SwiftUI

struct PaywallCloseButton: View {

    let isDisabled: Bool
    let isHidden: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(PaywallAssets.xmark)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: PaywallLayout.closeSize, height: PaywallLayout.closeSize)
                .contentShape(Rectangle())
        }
        .padding(.top, PaywallLayout.closeEdgeInset)
        .padding(.trailing, 0) // у тебя в API сейчас так
        .disabled(isDisabled)
        .opacity(isHidden ? 0.0 : 1.0)
        .accessibilityLabel("Close")
    }
}
