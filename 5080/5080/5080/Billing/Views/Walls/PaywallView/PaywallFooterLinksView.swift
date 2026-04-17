
import SwiftUI

struct PaywallFooterLinksView: View {

    let termsTitle: String
    let restoreTitle: String
    let privacyTitle: String

    let termsURL: URL?
    let privacyURL: URL?
    let openURL: OpenURLAction

    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 8.scale) {
            Button(termsTitle) {
                if let termsURL { openURL(termsURL) }
            }
            .disabled(termsURL == nil)

            Text("•")
                .foregroundStyle(Tokens.Color.textThirdcondary.opacity(0.6))

            Button(restoreTitle) {
                onRestore()
            }

            Text("•")
                .foregroundStyle(Tokens.Color.textThirdcondary.opacity(0.6))

            Button(privacyTitle) {
                if let privacyURL { openURL(privacyURL) }
            }
            .disabled(privacyURL == nil)
        }
        .font(AppLanguage.isRussian ? Tokens.Font.regular12 : Tokens.Font.regular13)
        .foregroundStyle(Tokens.Color.textSecondary)
        .padding(.top, 6.scale)
    }
}
