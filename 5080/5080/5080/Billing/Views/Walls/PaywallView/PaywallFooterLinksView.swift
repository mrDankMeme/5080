
import SwiftUI

struct PaywallFooterLinksView: View {

    let termsTitle: String
    let restoreTitle: String
    let privacyTitle: String

    let onTerms: () -> Void
    let onRestore: () -> Void
    let onPrivacy: () -> Void

    var body: some View {
        HStack(spacing: 8.scale) {
            footerButton(title: termsTitle, action: onTerms)
            footerSeparator
            footerButton(title: restoreTitle, action: onRestore)
            footerSeparator
            footerButton(title: privacyTitle, action: onPrivacy)
        }
        .frame(maxWidth: .infinity)
    }
}

private extension PaywallFooterLinksView {
    func footerButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Tokens.Font.paywallFooter13)
                .foregroundStyle(Tokens.Color.paywallTertiaryText)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
    }

    var footerSeparator: some View {
        Text("|")
            .font(Tokens.Font.paywallFooter13)
            .foregroundStyle(Tokens.Color.paywallTertiaryText)
    }
}
