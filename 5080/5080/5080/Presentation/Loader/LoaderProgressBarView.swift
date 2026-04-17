

import SwiftUI

struct LoaderProgressBarView: View {

    let progress: CGFloat

    private let size = CGSize(width: 302.scale, height: 16.scale)

    private var clamped: CGFloat {
        max(0, min(1, progress))
    }

    private var fillGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "#6A4FF1") ?? Tokens.Color.accent,
                Color(hex: "#9B8AF6") ?? Tokens.Color.accent,
                Color(hex: "#C9C0FA") ?? Tokens.Color.accent
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        ZStack(alignment: .leading) {

            Capsule(style: .continuous)
                .fill(Tokens.Color.accent.opacity(0.13))
                .frame(width: size.width, height: size.height)

            Capsule(style: .continuous)
                .fill(fillGradient)
                .frame(width: size.width * clamped, height: size.height)
        }
        .frame(width: size.width, height: size.height)
    }
}
