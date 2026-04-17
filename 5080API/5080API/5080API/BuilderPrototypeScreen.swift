import SwiftUI

private enum BuilderPane: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case preview = "Preview"

    var id: String { rawValue }
}

struct BuilderPrototypeScreen: View {
    @StateObject private var viewModel = BuilderViewModel()
    @State private var selectedPane: BuilderPane = .chat
    @Environment(\.openURL) private var openURL

    private let topSky = Color(red: 167 / 255, green: 226 / 255, blue: 248 / 255)
    private let warmCream = Color(red: 254 / 255, green: 241 / 255, blue: 219 / 255)
    private let softCard = Color(red: 241 / 255, green: 251 / 255, blue: 255 / 255)
    private let accentOrange = Color(red: 1.0, green: 108 / 255, blue: 24 / 255)
    private let previewGray = Color(red: 234 / 255, green: 234 / 255, blue: 236 / 255)

    var body: some View {
        ZStack {
            backgroundView
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                if selectedPane == .chat {
                    chatPane
                } else {
                    previewPane
                }
            }
        }
        .onChange(of: viewModel.previewURL) { _, newValue in
            guard newValue != nil else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                selectedPane = .preview
            }
        }
        .sheet(item: $viewModel.shareSheetPayload, onDismiss: viewModel.dismissShareSheet) { payload in
            ActivityView(items: payload.items, subject: payload.subject)
        }
    }

    private var backgroundView: some View {
        VStack(spacing: 0) {
            topSky
                .frame(maxWidth: .infinity)
                .frame(height: selectedPane == .chat ? nil : 190)

            if selectedPane == .chat {
                LinearGradient(
                    colors: [topSky, Color.white, warmCream],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                previewGray
            }
        }
    }

    private var topBar: some View {
        VStack(spacing: 20) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        if selectedPane == .preview {
                            selectedPane = .chat
                        } else {
                            viewModel.resetFlow()
                        }
                    }
                } label: {
                    Circle()
                        .fill(.white.opacity(0.9))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.black.opacity(0.85))
                        }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isBusy)

                Spacer()

                BuilderSegmentedControl(selectedPane: $selectedPane, accentOrange: accentOrange)
                    .frame(width: 220)

                Spacer()

                Circle()
                    .fill(.white.opacity(0.001))
                    .frame(width: 56, height: 56)
            }
            .padding(.horizontal, 28)
        }
        .padding(.top, 20)
        .padding(.bottom, 18)
    }

    private var chatPane: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    statusCard

                    if viewModel.hasPrompt {
                        promptBubble
                    }

                    if viewModel.hasPreview {
                        liveProjectCard
                    } else if viewModel.hasQuestions {
                        ForEach(viewModel.questions) { question in
                            questionCard(question: question)
                        }

                        generateButton
                    } else {
                        emptyStateCard
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }

            composerBar
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if viewModel.isBusy {
                    ProgressView()
                        .tint(accentOrange)
                }

                Text(viewModel.statusLine)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.82))
            }

            Text(viewModel.detailLine)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.black.opacity(0.62))

            HStack(spacing: 10) {
                infoPill(title: "project", value: viewModel.projectSlug ?? "-")
                infoPill(title: "status", value: viewModel.projectStatus)
            }

            Text(viewModel.latestStreamText)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.58))
                .lineLimit(3)
        }
        .padding(18)
        .background(softCard.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        }
    }

    private var promptBubble: some View {
        Text(viewModel.promptText)
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .lineSpacing(5)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(accentOrange)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 34)
            .padding(.bottom, 4)
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How it works")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.82))

            Text("1. Type a short site idea below and tap the plane.")
            Text("2. Wait for the real clarify questions from the backend.")
            Text("3. Pick answers and tap Generate Site.")
            Text("4. After preview loads, switch back to Chat to send edits.")
        }
        .font(.system(size: 17, weight: .medium, design: .rounded))
        .foregroundStyle(.black.opacity(0.74))
        .padding(18)
        .background(softCard.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        }
    }

    private var liveProjectCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Site is live")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.82))

            Text("Preview is already generated. Switch between Chat and Preview, and use the composer below to send edit instructions.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.black.opacity(0.74))

            if !viewModel.briefDescription.isEmpty {
                Text(viewModel.briefDescription)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.black.opacity(0.62))
                    .lineLimit(4)
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.sharePreviewLink()
                } label: {
                    Label("Share Preview", systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(accentOrange)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSharePreview)

                Button {
                    Task { await viewModel.exportSourceFiles() }
                } label: {
                    Label("Export Source", systemImage: "folder.badge.gearshape")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.78))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.8))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canExportSource)
            }
        }
        .padding(18)
        .background(softCard.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        }
    }

    private var generateButton: some View {
        Button {
            Task { await viewModel.generateSite() }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isBusy {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.headline)
                }

                Text("Generate Site")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(viewModel.canGenerate ? accentOrange : accentOrange.opacity(0.45))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canGenerate)
        .padding(.top, 2)
    }

    private func questionCard(question: BuilderQuestion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(question.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.82))

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    Button {
                        viewModel.updateSelection(questionID: question.id, selectedIndex: index)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            selectionIndicator(isSelected: question.selectedIndex == index)
                                .padding(.top, 2)

                            Text(option)
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundStyle(.black.opacity(0.78))
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(softCard.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        }
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        Circle()
            .stroke(isSelected ? accentOrange : .black.opacity(0.2), lineWidth: 2)
            .frame(width: 18, height: 18)
            .overlay {
                if isSelected {
                    Circle()
                        .fill(accentOrange)
                        .frame(width: 8, height: 8)
                }
            }
    }

    private var composerBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(softCard)
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "paperclip")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.black.opacity(0.8))
                }

            TextField(viewModel.sendPlaceholder, text: $viewModel.composerText)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .padding(.horizontal, 18)
                .frame(height: 60)
                .background(.white.opacity(0.92))
                .clipShape(Capsule())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)

            Button {
                Task { await viewModel.submitComposer() }
            } label: {
                Circle()
                    .fill(Color(red: 252 / 255, green: 168 / 255, blue: 110 / 255))
                    .frame(width: 60, height: 60)
                    .overlay {
                        if viewModel.isBusy {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isBusy || viewModel.composerText.trimmed.isEmpty)
            .accessibilityLabel(viewModel.sendButtonAccessibilityLabel)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(warmCream.opacity(0.85))
    }

    private var previewPane: some View {
        ZStack(alignment: .bottomTrailing) {
            if let previewURL = viewModel.previewURL {
                SitePreviewWebView(url: previewURL, reloadKey: viewModel.previewReloadKey)
            } else {
                previewGray
                    .overlay(alignment: .center) {
                        VStack(spacing: 12) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.55))

                            Text("Preview will appear here after `Generate Site` finishes.")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.black.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            Text(viewModel.statusLine)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.black.opacity(0.45))
                        }
                    }
            }

            if let previewURL = viewModel.previewURL {
                VStack(spacing: 12) {
                    Button {
                        viewModel.sharePreviewLink()
                    } label: {
                        Circle()
                            .fill(softCard)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.black.opacity(0.78))
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canSharePreview)

                    Button {
                        openURL(previewURL)
                    } label: {
                        Circle()
                            .fill(softCard)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: "safari")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.black.opacity(0.78))
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 34)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.black.opacity(0.45))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.black.opacity(0.8))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct BuilderSegmentedControl: View {
    @Binding var selectedPane: BuilderPane
    let accentOrange: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BuilderPane.allCases) { pane in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selectedPane = pane
                    }
                } label: {
                    Text(pane.rawValue)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(selectedPane == pane ? .white : .black.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            if selectedPane == pane {
                                Capsule()
                                    .fill(accentOrange)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.white.opacity(0.92))
        .clipShape(Capsule())
    }
}

#Preview {
    BuilderPrototypeScreen()
}
