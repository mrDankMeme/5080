import SwiftUI

struct BuilderWorkspaceSceneView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @StateObject private var viewModel: BuilderWorkspaceSceneViewModel
    @State private var selectedPane: BuilderPane

    init(viewModel: BuilderWorkspaceSceneViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _selectedPane = State(initialValue: .chat)
    }

    var body: some View {
        ZStack {
            backgroundView
                .ignoresSafeArea()

            VStack(spacing: 0.scale) {
                topBar

                if selectedPane == .chat {
                    chatPane
                } else {
                    previewPane
                }
            }
        }
        .task {
            await viewModel.beginIfNeeded()
            if viewModel.previewURL != nil {
                selectedPane = .preview
            }
        }
        .onChange(of: viewModel.previewURL) { _, newValue in
            guard newValue != nil else { return }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                selectedPane = .preview
            }
        }
        .sheet(item: Binding(
            get: { viewModel.shareSheetPayload },
            set: { payload in
                if payload == nil {
                    viewModel.dismissShareSheet()
                }
            }
        )) { payload in
            ShareSheet(activityItems: payload.items)
        }
    }
}

private extension BuilderWorkspaceSceneView {
    var backgroundView: some View {
        VStack(spacing: 0.scale) {
            Tokens.Color.base44SkyBlue
                .frame(maxWidth: .infinity)
                .frame(height: selectedPane == .chat ? nil : 180.scale)

            if selectedPane == .chat {
                LinearGradient(
                    colors: [
                        Tokens.Color.base44SkyBlue,
                        Tokens.Color.surfaceWhite,
                        Tokens.Color.base44WarmCream
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Tokens.Color.base44PreviewBackground
            }
        }
    }

    var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Circle()
                    .fill(
                        Tokens.Color.surfaceWhite.opacity(
                            viewModel.canDismiss ? 0.94 : 0.62
                        )
                    )
                    .frame(width: 42.scale, height: 42.scale)
                    .overlay {
                        Image(systemName: "chevron.left")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 11.scale, height: 18.scale)
                            .foregroundStyle(
                                Tokens.Color.inkPrimary.opacity(
                                    viewModel.canDismiss ? 1.0 : 0.34
                                )
                            )
                    }
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canDismiss)
            .opacity(viewModel.canDismiss ? 1.0 : 0.72)

            Spacer(minLength: 16.scale)

            BuilderWorkspaceSegmentedControl(selectedPane: $selectedPane)
                .frame(width: 200.scale)

            Spacer(minLength: 16.scale)

            Circle()
                .fill(Color.clear)
                .frame(width: 42.scale, height: 42.scale)
        }
        .padding(.horizontal, 28.scale)
        .padding(.top, 12.scale)
        .padding(.bottom, 16.scale)
    }

    var chatPane: some View {
        VStack(spacing: 0.scale) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16.scale) {
                    statusCard

                    if viewModel.hasPrompt {
                        promptBubble
                    }

                    if viewModel.hasQuestions {
                        ForEach(viewModel.questions) { question in
                            questionCard(question)
                        }

                        generateButton
                    }
                }
                .padding(.horizontal, 16.scale)
                .padding(.bottom, 24.scale)
            }

            if !viewModel.uploadedAssets.isEmpty {
                UploadedAssetsStripView(assets: viewModel.uploadedAssets)
                    .padding(.horizontal, 24.scale)
                    .padding(.bottom, 8.scale)
            }

            if !viewModel.pendingAttachments.isEmpty {
                PendingAttachmentsStripView(
                    attachments: viewModel.pendingAttachments,
                    onRemove: { attachment in
                        viewModel.removePendingAttachment(id: attachment.id)
                    }
                )
                .padding(.horizontal, 24.scale)
                .padding(.bottom, 8.scale)
            }

            composerBar
        }
    }

    var statusCard: some View {
        VStack(alignment: .leading, spacing: 10.scale) {
            HStack(spacing: 10.scale) {
                if viewModel.isBusy {
                    ProgressView()
                        .tint(Tokens.Color.base44BrandOrange)
                }

                Text(viewModel.statusLine)
                    .font(Tokens.Font.bold16)
                    .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.82))
                    .lineLimit(2)
            }

            Text(viewModel.detailLine)
                .font(Tokens.Font.medium14)
                .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.62))

            HStack(spacing: 10.scale) {
                infoPill(title: "project", value: viewModel.projectSlug ?? "-")
                infoPill(title: "status", value: viewModel.projectStatus)
            }

            Text(viewModel.latestStreamText)
                .font(Tokens.Font.regular12)
                .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.58))
                .lineLimit(3)
        }
        .padding(18.scale)
        .background(Tokens.Color.base44SoftCard.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20.scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20.scale, style: .continuous)
                .stroke(Tokens.Color.base44Border, lineWidth: 1.scale)
        }
    }

    var promptBubble: some View {
        HStack(spacing: 0.scale) {
            Spacer(minLength: 52.scale)

            Text(viewModel.promptText)
                .font(Tokens.Font.regular16)
                .foregroundStyle(Tokens.Color.surfaceWhite)
                .lineSpacing(4.scale)
                .padding(.horizontal, 18.scale)
                .padding(.vertical, 16.scale)
                .background(Tokens.Color.base44BrandOrange)
                .clipShape(RoundedRectangle(cornerRadius: 22.scale, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.bottom, 4.scale)
    }

    func questionCard(_ question: BuilderQuestionItem) -> some View {
        HStack(spacing: 0.scale) {
            VStack(alignment: .leading, spacing: 14.scale) {
                Text(question.title)
                    .font(Tokens.Font.semibold18)
                    .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.82))

                VStack(alignment: .leading, spacing: 14.scale) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        Button {
                            viewModel.updateSelection(
                                questionID: question.id,
                                selectedIndex: index
                            )
                        } label: {
                            HStack(alignment: .top, spacing: 12.scale) {
                                selectionIndicator(
                                    isSelected: question.selectedIndex == index
                                )
                                .padding(.top, 2.scale)

                                Text(option)
                                    .font(Tokens.Font.regular16)
                                    .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.78))
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18.scale)
            .background(Tokens.Color.base44SoftCard.opacity(0.97))
            .clipShape(RoundedRectangle(cornerRadius: 20.scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20.scale, style: .continuous)
                    .stroke(Tokens.Color.base44Border, lineWidth: 1.scale)
            }

            Spacer(minLength: 52.scale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func selectionIndicator(isSelected: Bool) -> some View {
        Circle()
            .stroke(
                isSelected
                    ? Tokens.Color.base44BrandOrange
                    : Tokens.Color.inkPrimary.opacity(0.20),
                lineWidth: 2.scale
            )
            .frame(width: 18.scale, height: 18.scale)
            .overlay {
                if isSelected {
                    Circle()
                        .fill(Tokens.Color.base44BrandOrange)
                        .frame(width: 8.scale, height: 8.scale)
                }
            }
    }

    var generateButton: some View {
        Button {
            Task {
                await viewModel.generateSite()
            }
        } label: {
            HStack(spacing: 10.scale) {
                if viewModel.isBusy {
                    ProgressView()
                        .tint(Tokens.Color.surfaceWhite)
                } else {
                    Image(systemName: "wand.and.stars")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16.scale, height: 16.scale)
                }

                Text("Generate")
                    .font(Tokens.Font.semibold17)
            }
            .foregroundStyle(Tokens.Color.surfaceWhite)
            .padding(.horizontal, 20.scale)
            .frame(height: 44.scale)
            .background(
                viewModel.canGenerate
                    ? Tokens.Color.base44BrandOrange
                    : Tokens.Color.base44BrandOrange.opacity(0.45)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canGenerate)
        .padding(.top, 2.scale)
    }

    var composerBar: some View {
        HStack(spacing: 12.scale) {
            BuilderAttachmentPickerButton(
                onImported: { attachments in
                    viewModel.addAttachments(attachments)
                },
                onError: { message in
                    viewModel.presentAttachmentError(message)
                }
            ) {
                Circle()
                    .fill(Tokens.Color.base44SoftCard)
                    .frame(width: 52.scale, height: 52.scale)
                    .overlay {
                        Image(systemName: "paperclip")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18.scale, height: 18.scale)
                            .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.80))
                    }
            }

            TextField(viewModel.composerPlaceholder, text: $viewModel.composerText)
                .font(Tokens.Font.medium17)
                .padding(.horizontal, 18.scale)
                .frame(height: 52.scale)
                .background(Tokens.Color.surfaceWhite.opacity(0.92))
                .clipShape(Capsule())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)

            Button {
                Task {
                    await viewModel.submitComposer()
                }
            } label: {
                Circle()
                    .fill(Tokens.Color.base44BrandOrange.opacity(0.72))
                    .frame(width: 52.scale, height: 52.scale)
                    .overlay {
                        if viewModel.isBusy {
                            ProgressView()
                                .tint(Tokens.Color.surfaceWhite)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 17.scale, height: 17.scale)
                                .foregroundStyle(Tokens.Color.surfaceWhite)
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isBusy || viewModel.composerText.trimmed.isEmpty)
        }
        .padding(.horizontal, 24.scale)
        .padding(.top, 12.scale)
        .padding(.bottom, 18.scale)
        .background(Tokens.Color.base44WarmCream.opacity(0.90))
    }

    var previewPane: some View {
        ZStack(alignment: .bottomTrailing) {
            if let previewURL = viewModel.previewURL {
                SitePreviewWebView(
                    url: previewURL,
                    reloadKey: viewModel.previewReloadKey
                )
            } else {
                Tokens.Color.base44PreviewBackground
                    .overlay {
                        VStack(spacing: 12.scale) {
                            Image(systemName: "wand.and.stars")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28.scale, height: 28.scale)
                                .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.55))

                            Text("Preview will appear here after Generate finishes.")
                                .font(Tokens.Font.medium16)
                                .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.60))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32.scale)

                            Text(viewModel.statusLine)
                                .font(Tokens.Font.regular13)
                                .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.45))
                        }
                    }
            }

            if let previewURL = viewModel.previewURL {
                Button {
                    openURL(previewURL)
                } label: {
                    Circle()
                        .fill(Tokens.Color.base44SoftCard)
                        .frame(width: 52.scale, height: 52.scale)
                        .overlay {
                            Image(systemName: "safari")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18.scale, height: 18.scale)
                                .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.78))
                        }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20.scale)
                .padding(.bottom, 26.scale)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2.scale) {
            Text(title.uppercased())
                .font(Tokens.Font.semibold11)
                .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.45))

            Text(value)
                .font(Tokens.Font.semibold13)
                .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.80))
                .lineLimit(1)
        }
        .padding(.horizontal, 10.scale)
        .padding(.vertical, 8.scale)
        .background(Tokens.Color.surfaceWhite.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 10.scale, style: .continuous))
    }
}
