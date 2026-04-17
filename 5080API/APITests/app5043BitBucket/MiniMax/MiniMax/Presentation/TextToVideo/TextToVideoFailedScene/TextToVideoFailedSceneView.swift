import SwiftUI
import UIKit

struct TextToVideoFailedSceneView: View {
    @ObservedObject var viewModel: TextToVideoFailedSceneViewModel

    let onBack: () -> Void
    let onTryAgain: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom

            VStack(spacing: 0.scale) {
                header(topInset: topInset)

                Spacer(minLength: 0.scale)

                VStack(spacing: 16.scale) {
                    GenerationFailedIconView()
                        .frame(width: 64.scale, height: 64.scale)

                    Text(viewModel.heading)
                        .font(Tokens.Font.outfitSemibold18)
                        .foregroundStyle(Tokens.Color.inkPrimary)
                        .kerning(-0.18.scale)

                    Text(viewModel.subtitle)
                        .font(Tokens.Font.regular14)
                        .foregroundStyle(Tokens.Color.inkPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2.scale)
                        .frame(maxWidth: 320.scale)
                }
                .padding(.horizontal, 16.scale)

                Spacer(minLength: 0.scale)

                Button(action: onTryAgain) {
                    Text(viewModel.actionTitle)
                        .font(Tokens.Font.semibold16)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52.scale)
                        .background(
                            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                                .fill(Tokens.Color.accent)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16.scale)
                .padding(.bottom, max(16.scale, bottomInset + 8.scale))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Color.surfaceWhite)
            .ignoresSafeArea()
        }
    }

    private func header(topInset: CGFloat) -> some View {
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
                            .font(.system(size: 16.scale, weight: .semibold))
                            .foregroundStyle(Tokens.Color.inkPrimary)
                    )
            }
        }
    }
}

private struct GenerationFailedIconView: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Tokens.Color.accent, lineWidth: 3.scale)

            HStack(spacing: 10.scale) {
                Circle()
                    .fill(Tokens.Color.accent)
                    .frame(width: 6.scale, height: 6.scale)

                Circle()
                    .fill(Tokens.Color.accent)
                    .frame(width: 6.scale, height: 6.scale)
            }
            .offset(y: -8.scale)

            SadMouthShape()
                .stroke(Tokens.Color.accent, style: StrokeStyle(lineWidth: 3.scale, lineCap: .round))
                .frame(width: 18.scale, height: 8.scale)
                .offset(y: 10.scale)
        }
    }
}

private struct SadMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return path
    }
}
