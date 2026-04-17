


import SwiftUI

struct PaywallLoadingOverlayView: View {

    var body: some View {
        ProgressView()
            .tint(Color.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.25))
    }
}
