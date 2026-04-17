import SwiftUI
import UIKit

struct VoiceGenSceneView: View {
    @ObservedObject var viewModel: VoiceGenSceneViewModel

    let isSubscribed: Bool
    let onBack: () -> Void
    let onTapModeTitle: () -> Void
    let onTapBalanceAccessory: () -> Void
    let onGenerate: () -> Void

    private let composerMinHeight: CGFloat = 122.scale
    private let composerMaxHeight: CGFloat = 180.scale
    private let composerTextMinHeight: CGFloat = 44.scale
    private let composerTextMaxHeight: CGFloat = 120.scale

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                Tokens.Color.surfaceWhite
                    .ignoresSafeArea()

                VStack(spacing: 0.scale) {
                    header
                        .padding(.horizontal, 16.scale)

                    VStack(alignment: .leading, spacing: 4.scale) {
                        Text("Start creating")
                            .font(Tokens.Font.regular14)
                            .foregroundStyle(Tokens.Color.inkPrimary)

                        Text("Create AI Voiceover")
                            .font(Tokens.Font.outfitSemibold22)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .kerning(-0.22.scale)
                    }
                    .padding(.top, 16.scale)
                    .padding(.horizontal, 16.scale)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0.scale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                composerPanel
                    .padding(.horizontal, 16.scale)
                    .padding(.bottom, 42.scale)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .overlay {
                if viewModel.isSettingsPresented {
                    VoiceGenSettingsSheetView(viewModel: viewModel) {
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
                    Text("Voice Gen")
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

    private var composerPanel: some View {
        VStack(spacing: 0.scale) {
            ZStack(alignment: .topLeading) {
                TextField("", text: $viewModel.promptText, axis: .vertical)
                    .font(Tokens.Font.regular16)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .lineLimit(1...6)
                    .padding(.top, 16.scale)
                    .padding(.horizontal, 16.scale)
                    .padding(.bottom, 4.scale)
                    .frame(height: composerCurrentTextHeight, alignment: .topLeading)

                if viewModel.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Type your script here or upload a file...")
                        .font(Tokens.Font.regular16)
                        .foregroundStyle(Tokens.Color.inkPrimary30)
                        .padding(.top, 16.scale)
                        .padding(.horizontal, 16.scale)
                        .allowsHitTesting(false)
                }
            }
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
            .padding(.top, 8.scale)
            .padding(.bottom, 16.scale)
        }
        .frame(height: composerHeight)
        .background(Tokens.Color.voiceComposerBackground)
        .clipShape(
            RoundedRectangle(cornerRadius: 32.scale, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32.scale, style: .continuous)
                .stroke(Tokens.Color.voiceComposerStroke, lineWidth: 1.scale)
        )
        .animation(.easeInOut(duration: 0.22), value: composerHeight)
    }

    private var composerHeight: CGFloat {
        let dynamicHeight = composerCurrentTextHeight + 58.scale
        return min(max(dynamicHeight, composerMinHeight), composerMaxHeight)
    }

    private var composerCurrentTextHeight: CGFloat {
        let textHeight = measuredPromptHeight(
            text: viewModel.promptText,
            font: UIFont(name: "SFProText-Regular", size: 16.scale) ?? UIFont.systemFont(ofSize: 16.scale),
            width: textMeasureWidth
        )
        return min(max(textHeight, composerTextMinHeight), composerTextMaxHeight)
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
