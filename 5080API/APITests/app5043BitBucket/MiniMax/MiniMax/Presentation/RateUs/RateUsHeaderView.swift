import SwiftUI
import UIKit

struct RateUsHeaderView: View {
    let title: String
    let onTapBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(Tokens.Font.semibold18)
                .foregroundStyle(Tokens.Color.inkPrimary)
                .kerning(-0.18.scale)
                .lineLimit(1)

            HStack {
                Button(action: onTapBack) {
                    headerBackIcon
                        .frame(width: 40.scale, height: 40.scale)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0.scale)
            }
        }
        .frame(height: 40.scale)
    }

    private var headerBackIcon: some View {
        Group {
            if let image = UIImage(named: "ttv_back_40") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Circle()
                    .fill(Tokens.Color.cardSoftBackground)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16.scale, weight: .semibold))
                            .foregroundStyle(Tokens.Color.inkPrimary)
                    )
            }
        }
    }
}
