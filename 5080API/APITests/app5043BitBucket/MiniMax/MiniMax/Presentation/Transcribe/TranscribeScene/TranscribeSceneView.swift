import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct TranscribeSceneView: View {
    @ObservedObject var viewModel: TranscribeSceneViewModel

    let isSubscribed: Bool
    let onBack: () -> Void
    let onTapModeTitle: () -> Void
    let onTapBalanceAccessory: () -> Void
    let onTranscribe: () -> Void

    @State private var isUploadOptionsPresented = false
    @State private var isAudioImporterPresented = false
    @State private var isVideoPickerPresented = false
    @State private var videoPickerItem: PhotosPickerItem?

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

                        Text("Turn Audio to Text")
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
                    TranscribeSettingsSheetView(viewModel: viewModel) {
                        viewModel.isSettingsPresented = false
                    }
                    .zIndex(20)
                }
            }
            .overlay {
                if viewModel.isPreparingSelection {
                    ZStack {
                        Tokens.Color.modeSheetOverlay
                            .ignoresSafeArea()

                        VStack(spacing: 12.scale) {
                            ProgressView()
                                .tint(Tokens.Color.accent)
                                .scaleEffect(1.2)

                            Text("Preparing file...")
                                .font(Tokens.Font.semibold16)
                                .foregroundStyle(Tokens.Color.surfaceWhite)
                        }
                        .padding(.horizontal, 20.scale)
                        .padding(.vertical, 18.scale)
                        .background(
                            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                                .fill(Color.black.opacity(0.45))
                        )
                    }
                    .zIndex(30)
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
            .confirmationDialog("Select source", isPresented: $isUploadOptionsPresented, titleVisibility: .visible) {
                Button("Audio/Video from Files") {
                    isAudioImporterPresented = true
                }

                Button("Video from Photos") {
                    isVideoPickerPresented = true
                }

                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(
                isPresented: $isVideoPickerPresented,
                selection: $videoPickerItem,
                matching: .videos
            )
            .fileImporter(
                isPresented: $isAudioImporterPresented,
                allowedContentTypes: [.audio, .movie, .mpeg4Movie, .quickTimeMovie],
                allowsMultipleSelection: false
            ) { result in
                handleMediaImportResult(result)
            }
            .onChange(of: videoPickerItem) { _, newValue in
                handleVideoSelection(newValue)
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
                    Text("Transcribe")
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
            if viewModel.selectedMedia == nil {
                Button {
                    isUploadOptionsPresented = true
                } label: {
                    HStack(spacing: 10.scale) {
                        uploadIcon
                            .frame(width: 24.scale, height: 24.scale)

                        Text("Upload Audio or Video")
                            .font(Tokens.Font.regular14)
                            .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.6))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 72.scale)
                    .background(
                        RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                            .fill(Tokens.Color.cardSoftBackground)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16.scale)
                .padding(.top, 16.scale)
            } else {
                selectedMediaFileChip
                    .padding(.horizontal, 16.scale)
                    .padding(.top, 16.scale)
            }

            HStack(spacing: 8.scale) {
                smallComposerButton(assetName: "ttv_settings_20", fallbackSystemName: "slider.horizontal.3") {
                    viewModel.isSettingsPresented = true
                }

                Button(action: onTranscribe) {
                    HStack(spacing: 8.scale) {
                        Text("Transcribe")
                            .font(Tokens.Font.outfitSemibold16)
                            .foregroundStyle(Color.white)
                            .kerning(-0.16.scale)

                        Image("Loader.Icon")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 20.scale, height: 20.scale)
                            .foregroundStyle(Color.white)

                        Text("\(viewModel.transcribeCost)")
                            .font(Tokens.Font.outfitSemibold16)
                            .foregroundStyle(Color.white)
                            .kerning(-0.16.scale)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44.scale)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Tokens.Color.accent.opacity(viewModel.isTranscribeEnabled ? 1.0 : 0.5))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isTranscribeEnabled)
            }
            .padding(.horizontal, 16.scale)
            .padding(.top, 16.scale)
            .padding(.bottom, 16.scale)
        }
        .frame(height: 164.scale)
        .background(Tokens.Color.voiceComposerBackground)
        .clipShape(
            RoundedRectangle(cornerRadius: 32.scale, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32.scale, style: .continuous)
                .stroke(Tokens.Color.voiceComposerStroke, lineWidth: 1.scale)
        )
    }

    private var selectedMediaFileChip: some View {
        HStack(spacing: 10.scale) {
            Button {
                isUploadOptionsPresented = true
            } label: {
                HStack(spacing: 10.scale) {
                    selectedMediaIcon
                        .frame(width: 24.scale, height: 24.scale)

                    HStack(spacing: 0.scale) {
                        Text(viewModel.uploadButtonBaseName)
                            .font(Tokens.Font.regular14)
                            .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(0)

                        if let extensionText = viewModel.uploadButtonExtensionText {
                            Text(extensionText)
                                .font(Tokens.Font.regular14)
                                .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.6))
                                .lineLimit(1)
                                .layoutPriority(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.clearSelectedMedia()
            } label: {
                if let image = UIImage(named: "tr_remove_24") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24.scale, height: 24.scale)
                } else {
                    Circle()
                        .fill(Tokens.Color.surfaceWhite)
                        .frame(width: 24.scale, height: 24.scale)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(Tokens.Font.medium12)
                                .foregroundStyle(Tokens.Color.inkPrimary)
                        )
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12.scale)
        .frame(height: 56.scale)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                .fill(Tokens.Color.cardSoftBackground)
        )
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

    private var uploadIcon: some View {
        Group {
            if let image = UIImage(named: "tr_upload_20") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "doc.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.6))
            }
        }
    }

    private var selectedMediaIcon: some View {
        Group {
            if viewModel.selectedMedia?.isVideo == true,
               let image = UIImage(named: "tr_video_24") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if viewModel.selectedMedia?.isVideo == false,
                      let image = UIImage(named: "tr_audio_24") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "doc")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.6))
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

    private func handleMediaImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                viewModel.showError("No file selected")
                return
            }
            viewModel.beginPreparingSelection()
            Task {
                defer {
                    Task { @MainActor in
                        viewModel.endPreparingSelection()
                    }
                }

                do {
                    let selectedMedia = try readMediaFromFile(from: url)
                    await MainActor.run {
                        viewModel.setSelectedMedia(selectedMedia)
                    }
                } catch {
                    await MainActor.run {
                        viewModel.showError(error.localizedDescription)
                    }
                }
            }

        case let .failure(error):
            viewModel.showError(error.localizedDescription)
        }
    }

    private func handleVideoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        videoPickerItem = nil

        viewModel.beginPreparingSelection()

        Task {
            defer {
                Task { @MainActor in
                    viewModel.endPreparingSelection()
                }
            }

            do {
                if let movieURL = try await item.loadTransferable(type: URL.self) {
                    let data = try Data(contentsOf: movieURL)
                    let fileName = movieURL.lastPathComponent.isEmpty
                        ? "video_\(UUID().uuidString).mp4"
                        : movieURL.lastPathComponent

                    let selectedMedia = TranscribeSelectedMedia(
                        data: data,
                        fileName: fileName,
                        mimeType: "video/mp4",
                        isVideo: true
                    )

                    await MainActor.run {
                        viewModel.setSelectedMedia(selectedMedia)
                    }
                    return
                }

                guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                    throw APIError.backendMessage("Unable to read selected video")
                }

                let selectedMedia = TranscribeSelectedMedia(
                    data: data,
                    fileName: "video_\(UUID().uuidString).mp4",
                    mimeType: "video/mp4",
                    isVideo: true
                )

                await MainActor.run {
                    viewModel.setSelectedMedia(selectedMedia)
                }
            } catch {
                await MainActor.run {
                    viewModel.showError(error.localizedDescription)
                }
            }
        }
    }

    private func readMediaFromFile(from url: URL) throws -> TranscribeSelectedMedia {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            throw APIError.backendMessage("Selected file is empty")
        }

        let fileName = url.lastPathComponent.isEmpty
            ? "audio_\(UUID().uuidString).mp3"
            : url.lastPathComponent

        let extensionValue = url.pathExtension.lowercased()
        let fileType = UTType(filenameExtension: extensionValue)

        let isVideo = fileType?.conforms(to: .movie) == true ||
            fileType?.conforms(to: .video) == true ||
            ["mp4", "mov", "m4v", "avi", "mkv", "webm"].contains(extensionValue)

        let mimeType: String = {
            if let preferredMIMEType = fileType?.preferredMIMEType {
                return preferredMIMEType
            }

            if extensionValue == "wav" {
                return "audio/wav"
            }
            if extensionValue == "m4a" {
                return "audio/mp4"
            }
            if extensionValue == "aac" {
                return "audio/aac"
            }
            if extensionValue == "ogg" {
                return "audio/ogg"
            }
            if extensionValue == "flac" {
                return "audio/flac"
            }

            return isVideo ? "video/mp4" : "audio/mpeg"
        }()

        return TranscribeSelectedMedia(
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            isVideo: isVideo
        )
    }
}
