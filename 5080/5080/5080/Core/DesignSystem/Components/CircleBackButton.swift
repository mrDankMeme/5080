

import SwiftUI

struct CircleBackButton: View {
    let action: () -> Void
    private let size: CGFloat = 40.scale

    var body: some View {
        Button(action: action) {
            ZStack {
                
                Circle()
                    .fill(Color.white)
                    .shadow(
                        color: Color.black.opacity(0.12),
                        radius: 12.scale,
                        x: 0,
                        y: 4.scale
                    )

                Image("backButton")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: size * 0.38, height: size * 0.38)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}
