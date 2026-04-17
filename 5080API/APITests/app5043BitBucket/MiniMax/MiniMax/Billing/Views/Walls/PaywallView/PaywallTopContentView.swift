
import SwiftUI

struct PaywallTopContentView: View {

    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityHidden(true)
    }
}
