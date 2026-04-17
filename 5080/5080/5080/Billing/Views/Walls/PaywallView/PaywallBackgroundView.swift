


import SwiftUI

struct PaywallBackgroundView: View {

    let isEnglishUI: Bool

    var body: some View {
        ZStack {
            Color.black

            Image(isEnglishUI ? PaywallAssets.bgEn : PaywallAssets.bgRu)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.20)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }
}
