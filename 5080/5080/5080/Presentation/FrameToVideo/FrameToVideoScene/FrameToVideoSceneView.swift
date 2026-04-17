import SwiftUI
import PhotosUI
import UIKit

struct FrameToVideoSceneView: View {
    @ObservedObject var viewModel: FrameToVideoSceneViewModel

    let isSubscribed: Bool
    let onBack: () -> Void
    let onTapModeTitle: () -> Void
    let onTapBalanceAccessory: () -> Void
    let onGenerate: () -> Void

    @State private var startPickerItem: PhotosPickerItem?
    @State private var endPickerItem: PhotosPickerItem?
    @FocusState private var isPromptFocused: Bool

    private let minComposerHeight: CGFloat = 252.scale
    private let composerScaleFactor: CGFloat = 1.8
    private let promptReferenceHeight: CGFloat = 44.scale

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

                        Text("Bring your first slide")
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
            .onChange(of: startPickerItem) { _, newValue in
                handleFrameSelection(newValue, target: .start)
            }
            .onChange(of: endPickerItem) { _, newValue in
                handleFrameSelection(newValue, target: .end)
            }
            .overlay {
                if viewModel.isCompressingFrames {
                    compressionOverlay
                }
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
                    Text("Frame to Video")
                        .font(Tokens.Font.outfitSemibold16)
                        .foregroundStyle(Tokens.Color.inkPrimary)
                        .kerning(-0.16.scale)

                    Image(systemName: "chevron.down")
                        .font(Tokens.Font.medium12)
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
            HStack(spacing: 8.scale) {
                framePickerCard(
                    kind: .start,
                    title: "Start Frame",
                    selection: $startPickerItem,
                    image: startPreviewImage
                )
                .frame(width: 96.scale, height: 72.scale)

                connectorIcon
                    .frame(width: 24.scale, height: 24.scale)
                    .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.55))

                framePickerCard(
                    kind: .end,
                    title: "End Frame",
                    selection: $endPickerItem,
                    image: endPreviewImage
                )
                .frame(width: 96.scale, height: 72.scale)

                Spacer(minLength: 0.scale)
            }
            .frame(height: 72.scale)
            .padding(.horizontal, 16.scale)
            .padding(.top, 16.scale)
            .zIndex(0)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.promptText)
                    .font(Tokens.Font.regular16)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, -5.scale)
                    .padding(.vertical, -8.scale)
                    .frame(height: composerCurrentTextHeight, alignment: .topLeading)
                    .focused($isPromptFocused)

                if viewModel.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("What do you want to see? E.g., Cinematic drone shot...")
                        .font(Tokens.Font.regular16)
                        .foregroundStyle(Tokens.Color.inkPrimary30)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 16.scale)
            .padding(.top, 24.scale)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture {
                isPromptFocused = true
            }
            .zIndex(1)

            Spacer(minLength: 0.scale)

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

    private var composerMaxHeight: CGFloat {
        minComposerHeight * composerScaleFactor
    }

    private var composerHeight: CGFloat {
        let expansion = max(0.scale, composerCurrentTextHeight - promptReferenceHeight)
        return min(minComposerHeight + expansion, composerMaxHeight)
    }

    private var composerCurrentTextHeight: CGFloat {
        let measured = measuredPromptHeight(
            text: viewModel.promptText,
            font: promptUIFont,
            width: textMeasureWidth
        )
        return min(max(measured, promptReferenceHeight), minComposerHeight)
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

    private var startPreviewImage: UIImage? {
        guard let data = viewModel.startFrameData else {
            return nil
        }
        return UIImage(data: data)
    }

    private var endPreviewImage: UIImage? {
        guard let data = viewModel.endFrameData else {
            return nil
        }
        return UIImage(data: data)
    }

    private func framePickerCard(
        kind: FrameKind,
        title: String,
        selection: Binding<PhotosPickerItem?>,
        image: UIImage?
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            PhotosPicker(selection: selection, matching: .images) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96.scale, height: 72.scale)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                            )
                    } else {
                        VStack(spacing: 8.scale) {
                            plusIcon
                                .frame(width: 24.scale, height: 24.scale)
                                .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.6))

                            Text(title)
                                .font(Tokens.Font.regular14)
                                .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.6))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                                .fill(Tokens.Color.cardSoftBackground)
                        )
                    }
                }
            }
            .frame(width: 96.scale, height: 72.scale)
            .contentShape(
                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
            )
            .buttonStyle(.plain)

            if image != nil {
                Button {
                    if kind == .start {
                        viewModel.removeStartFrame()
                        startPickerItem = nil
                    } else {
                        viewModel.removeEndFrame()
                        endPickerItem = nil
                    }
                } label: {
                    removeIcon
                        .frame(width: 24.scale, height: 24.scale)
                }
                .buttonStyle(.plain)
                .padding(.top, 4.scale)
                .padding(.trailing, 4.scale)
            }
        }
        .frame(width: 96.scale, height: 72.scale)
        .clipShape(
            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
        )
    }

    private var plusIcon: some View {
        Group {
            if let image = UIImage(named: "ftv_plus_24") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "plus")
                    .resizable()
                    .scaledToFit()
                    .padding(3.scale)
            }
        }
    }

    private var connectorIcon: some View {
        Group {
            if let image = UIImage(named: "ftv_connector_24") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "arrow.left.and.right")
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    private var removeIcon: some View {
        Group {
            if let image = UIImage(named: "ftv_remove_24") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Circle()
                    .fill(Tokens.Color.surfaceWhite)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(Tokens.Font.medium12)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                    )
            }
        }
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
                            .font(Tokens.Font.semibold16)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                    )
            }
        }
    }

    private var compressionOverlay: some View {
        ZStack {
            Color.black
                .opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 12.scale) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Tokens.Color.accent)
                    .scaleEffect(1.1)

                Text("Compressing frames")
                    .font(Tokens.Font.semibold17)
                    .foregroundStyle(Tokens.Color.inkPrimary)

                Text("Please wait a moment")
                    .font(Tokens.Font.regular14)
                    .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.75))
            }
            .padding(.horizontal, 20.scale)
            .padding(.vertical, 18.scale)
            .background(
                RoundedRectangle(cornerRadius: 20.scale, style: .continuous)
                    .fill(Tokens.Color.surfaceWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20.scale, style: .continuous)
                    .stroke(Tokens.Color.strokeSoft, lineWidth: 1.scale)
            )
            .shadow(color: Tokens.Color.inkPrimary.opacity(0.08), radius: 18.scale, x: 0.scale, y: 6.scale)
        }
        .transition(.opacity)
    }

    private func handleFrameSelection(_ item: PhotosPickerItem?, target: FrameKind) {
        guard let item else {
            return
        }

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      UIImage(data: data) != nil else {
                    await MainActor.run {
                        viewModel.showError("Unable to read the selected image")
                    }
                    return
                }

                switch target {
                case .start:
                    await viewModel.prepareStartFrameData(data)
                case .end:
                    await viewModel.prepareEndFrameData(data)
                }
            } catch {
                await MainActor.run {
                    viewModel.showError(error.localizedDescription)
                }
            }
        }
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
}

private enum FrameKind {
    case start
    case end
}
