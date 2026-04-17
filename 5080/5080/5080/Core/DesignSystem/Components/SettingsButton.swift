

import SwiftUI

struct SettingsButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14.scale, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14.scale, style: .continuous)
                            .stroke(Color.black.opacity(0.10), lineWidth: 1.scale)
                    )
                    .shadow(
                        color: Color.black.opacity(0.06),
                        radius: 6.scale,
                        x: 0,
                        y: 2.scale
                    )

                Image("Settings")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 24.scale, height: 24.scale)
                    .foregroundColor(.black)
            }
            .frame(width: 48.scale, height: 48.scale)
        }
        .buttonStyle(.plain)
    }
}
