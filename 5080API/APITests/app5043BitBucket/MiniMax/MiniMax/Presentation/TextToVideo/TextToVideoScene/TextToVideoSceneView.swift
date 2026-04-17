import SwiftUI
import UIKit

struct TextToVideoSceneView: View {
    @ObservedObject var viewModel: TextToVideoSceneViewModel

    let isSubscribed: Bool
    let onBack: () -> Void
    let onTapModeTitle: () -> Void
    let onTapBalanceAccessory: () -> Void
    let onGenerate: () -> Void

    private let composerMinHeight: CGFloat = 144.scale
    private let composerMaxHeight: CGFloat = 216.scale
    private let composerTextMinHeight: CGFloat = 44.scale
    private let composerTextMaxHeight: CGFloat = 116.scale

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                Tokens.Color.surfaceWhite
                    .ignoresSafeArea()

                VStack(spacing: 0.scale) {
                    header
                        .padding(.horizontal, 16.scale)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0.scale) {
                            Text("Need inspiration?")
                                .font(Tokens.Font.outfitSemibold22)
                                .foregroundStyle(Tokens.Color.inkPrimary)
                                .kerning(-0.22.scale)
                                .padding(.top, 24.scale)

                            inspirationList
                                .padding(.top, 12.scale)

                            Spacer(minLength: 220.scale)
                        }
                        .padding(.horizontal, 16.scale)
                        .padding(.bottom, 16.scale)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                composerPanel
                    .padding(.horizontal, 16.scale)
                    .padding(.bottom, 42.scale)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .overlay {
                if viewModel.isSettingsPresented {
                    TextToVideoSettingsSheetView(viewModel: viewModel) {
                        viewModel.isSettingsPresented = false
                    }
                    .zIndex(20)
                }
            }
            .alert(
                viewModel.alertTitle,
                isPresented: Binding(
                    get: { viewModel.alertMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.clearError()
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12.scale) {
            Button(action: onBack) {
                headerBackIcon
                    .frame(width: 40.scale, height: 40.scale)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0.scale)

            Button(action: onTapModeTitle) {
                HStack(spacing: 8.scale) {
                    Text("Text to Video")
                        .font(Tokens.Font.outfitSemibold16)
                        .foregroundStyle(Tokens.Color.inkPrimary)
                        .kerning(-0.16.scale)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12.scale, weight: .semibold))
                        .foregroundStyle(Tokens.Color.inkPrimary)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0.scale)

            BillingBalanceAccessoryView(
                isSubscribed: isSubscribed,
                formattedTokens: viewModel.formattedTokens,
                action: onTapBalanceAccessory
            )
        }
    }

    private var inspirationList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8.scale) {
                ForEach(viewModel.inspirationCards) { card in
                    Button {
                        viewModel.applyInspiration(card)
                    } label: {
                        VStack(spacing: 0.scale) {
                            inspirationImage(for: card.imageAssetName)
                                .frame(width: 140.scale, height: 140.scale)
                                .clipped()

                            VStack(alignment: .leading, spacing: 4.scale) {
                                Text(card.title)
                                    .font(Tokens.Font.semibold16)
                                    .foregroundStyle(Tokens.Color.inkPrimary)
                                    .lineLimit(1)

                                Text(card.prompt)
                                    .font(Tokens.Font.regular14)
                                    .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.8))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.horizontal, 10.scale)
                            .padding(.vertical, 8.scale)
                            .frame(height: 82.scale, alignment: .topLeading)
                            .background(Tokens.Color.cardSoftBackground)
                        }
                        .frame(width: 140.scale, height: 222.scale)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                                .strokeBorder(
                                    viewModel.selectedInspirationID == card.id ? Tokens.Color.accent : Color.clear,
                                    lineWidth: viewModel.selectedInspirationID == card.id ? 1.5.scale : 0.scale
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.trailing, 16.scale)
        }
    }

    private var composerPanel: some View {
        VStack(spacing: 12.scale) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.promptText)
                    .font(Tokens.Font.regular16)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, -5.scale)
                    .padding(.vertical, -8.scale)
                    .frame(height: composerCurrentTextHeight, alignment: .topLeading)

                if viewModel.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("What do you want to see? E.g., Cinematic drone shot...")
                        .font(Tokens.Font.regular16)
                        .foregroundStyle(Tokens.Color.inkPrimary30)
                        .padding(.top, 16.scale)
                        .padding(.leading, 16.scale)
                        .padding(.trailing, 16.scale)
                        .allowsHitTesting(false)
                }
            }
            .padding(.top, 16.scale)
            .padding(.horizontal, 16.scale)
            .padding(.bottom, 4.scale)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            HStack(spacing: 8.scale) {
                smallComposerButton(assetName: "ttv_settings_20", fallbackSystemName: "slider.horizontal.3") {
                    viewModel.isSettingsPresented = true
                }

                Button(action: onGenerate) {
                    HStack(spacing: 8.scale) {
                        Text("Generate")
                            .font(Tokens.Font.semibold16)
                            .foregroundStyle(Color.white)

                        Image("Loader.Icon")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 20.scale, height: 20.scale)
                            .foregroundStyle(Color.white)

                        Text("\(viewModel.generateCost)")
                            .font(Tokens.Font.semibold16)
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44.scale)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Tokens.Color.accent.opacity(viewModel.isGenerateEnabled ? 1.0 : 0.5))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isGenerateEnabled)
            }
            .padding(.horizontal, 16.scale)
            .padding(.top, 24.scale)
            .padding(.bottom, 16.scale)
        }
        .frame(height: composerHeight)
        .background(Tokens.Color.surfaceWhite)
        .clipShape(
            RoundedRectangle(cornerRadius: 32.scale, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32.scale, style: .continuous)
                .stroke(Tokens.Color.strokeSoft, lineWidth: 1.scale)
        )
        .animation(.easeInOut(duration: 0.22), value: composerHeight)
    }

    private var composerHeight: CGFloat {
        let dynamicHeight = composerCurrentTextHeight + 100.scale
        return min(max(dynamicHeight, composerMinHeight), composerMaxHeight)
    }

    private var composerCurrentTextHeight: CGFloat {
        let textHeight = measuredPromptHeight(
            text: viewModel.promptText,
            font: promptUIFont,
            width: textMeasureWidth
        )
        return min(max(textHeight, composerTextMinHeight), composerTextMaxHeight)
    }

    private var promptUIFont: UIFont {
        UIFont(name: "SFProText-Regular", size: 16.scale)
            ?? UIFont.systemFont(ofSize: 16.scale, weight: .regular)
    }

    private var textMeasureWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let containerWidth = max(0.scale, screenWidth - 32.scale)
        return max(0.scale, containerWidth - 32.scale)
    }

    private func measuredPromptHeight(
        text: String,
        font: UIFont,
        width: CGFloat
    ) -> CGFloat {
        let sourceText: String = {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? " " : text
        }()

        let rect = (sourceText as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.height)
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

    private func inspirationImage(for assetName: String) -> some View {
        Group {
            if let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Tokens.Color.cardSoftBackground
                    Image(systemName: "photo")
                        .font(.system(size: 28.scale, weight: .regular))
                        .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.25))
                }
            }
        }
    }

    @ViewBuilder
    private func smallComposerButton(
        assetName: String,
        fallbackSystemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Tokens.Color.surfaceWhite)

                Circle()
                    .stroke(Tokens.Color.strokeSoft, lineWidth: 1.scale)

                if let image = UIImage(named: assetName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20.scale, height: 20.scale)
                } else {
                    Image(systemName: fallbackSystemName)
                        .font(.system(size: 18.scale, weight: .medium))
                        .foregroundStyle(Tokens.Color.inkPrimary)
                }
            }
            .frame(width: 44.scale, height: 44.scale)
        }
        .buttonStyle(.plain)
    }
}
