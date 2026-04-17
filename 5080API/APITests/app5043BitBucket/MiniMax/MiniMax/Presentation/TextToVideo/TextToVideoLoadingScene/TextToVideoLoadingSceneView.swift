import SwiftUI
import UIKit

struct TextToVideoLoadingSceneView: View {
    @ObservedObject var viewModel: TextToVideoLoadingSceneViewModel
    let onBack: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top

            ZStack {
                Tokens.Color.surfaceWhite
                    .ignoresSafeArea()

                VStack(spacing: 20.scale) {
                    TextToVideoLoadingSpinnerView()
                        .frame(width: 128.scale, height: 128.scale)

                    VStack(spacing: 8.scale) {
                        Text(viewModel.heading)
                            .font(Tokens.Font.outfitSemibold22)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .multilineTextAlignment(.center)
                            .kerning(-0.22.scale)

                        Text(viewModel.subtitle)
                            .font(Tokens.Font.regular16)
                            .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: 2.scale)

                VStack(spacing: 0.scale) {
                    HStack(spacing: 12.scale) {
                        Button(action: onBack) {
                            backIcon
                                .frame(width: 40.scale, height: 40.scale)
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 0.scale)

                        Text(viewModel.title)
                            .font(Tokens.Font.outfitSemibold16)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .kerning(-0.16.scale)

                        Spacer(minLength: 0.scale)

                        Color.clear
                            .frame(width: 40.scale, height: 40.scale)
                    }
                    .padding(.horizontal, 16.scale)
                    .padding(.top, max(8.scale, topInset + 8.scale))

                    Spacer(minLength: 0.scale)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }

    private var backIcon: some View {
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
                            .font(Tokens.Font.semibold16)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                    )
            }
        }
    }
}

private struct TextToVideoLoadingSpinnerView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            ForEach(0..<7) { index in
                Circle()
                    .trim(from: 0.06, to: 0.76)
                    .stroke(
                        Tokens.Color.accent.opacity(1.0 - (Double(index) * 0.11)),
                        style: StrokeStyle(lineWidth: max(1.scale, (5 - index / 2).scale), lineCap: .round)
                    )
                    .rotationEffect(.degrees(Double(index) * 27 + (isAnimating ? 360 : 0)))
                    .scaleEffect(1.0 - CGFloat(index) * 0.1)
                    .animation(
                        .linear(duration: 1.35)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.04),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}
