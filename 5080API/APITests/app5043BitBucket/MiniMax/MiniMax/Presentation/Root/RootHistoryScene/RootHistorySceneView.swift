import AVFoundation
import SwiftUI
import Swinject
import UIKit

struct RootHistorySceneView: View {
    @Environment(\.resolver) private var resolver
    @ObservedObject var viewModel: RootHistorySceneViewModel

    @State private var rowFrames: [UUID: CGRect] = [:]
    @FocusState private var isRenameFieldFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0.scale) {
                        if viewModel.sections.isEmpty {
                            emptyState
                        } else {
                            sectionsView
                        }
                    }
                    .padding(.horizontal, 16.scale)
                    .padding(.top, 16.scale)
                    .padding(.bottom, 120.scale)
                }
                .coordinateSpace(name: "history_scroll")
                .safeAreaInset(edge: .top, spacing: 0.scale) {
                    historyHeader
                        .padding(.horizontal, 16.scale)
                        .padding(.top, 16.scale)
                        .padding(.bottom, 8.scale)
                        .background(Tokens.Color.surfaceWhite)
                }
                .background(Tokens.Color.surfaceWhite.ignoresSafeArea())

                if let menuEntry = viewModel.menuEntry,
                   let frame = rowFrames[menuEntry.id] {
                    contextMenuOverlay(
                        menuEntry: menuEntry,
                        frame: frame,
                        containerFrame: proxy.frame(in: .global),
                        containerSize: proxy.size
                    )
                    .zIndex(20)
                }

                if viewModel.isDeleteDialogPresented {
                    deleteDialog
                        .zIndex(30)
                }

                if viewModel.isRenameDialogPresented {
                    renameDialog
                        .zIndex(30)
                }
            }
            .background(Tokens.Color.surfaceWhite.ignoresSafeArea())
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onPreferenceChange(HistoryRowFramePreferenceKey.self) { value in
            rowFrames = value
        }
        .onChange(of: viewModel.isRenameDialogPresented) { _, isPresented in
            isRenameFieldFocused = isPresented
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isSharePresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissShareSheet()
                }
            }
        )) {
            ShareSheet(activityItems: viewModel.shareItems)
        }
        .fullScreenCover(item: Binding(
            get: { viewModel.resultDestination },
            set: { destination in
                if destination == nil {
                    viewModel.dismissResultDestination()
                }
            }
        )) { destination in
            destinationView(for: destination)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.menuEntryID)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isDeleteDialogPresented)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isRenameDialogPresented)
    }

    private var historyHeader: some View {
        VStack(alignment: .leading, spacing: 8.scale) {
            Text("History")
                .font(Tokens.Font.outfitBold28)
                .foregroundStyle(Tokens.Color.inkPrimary)
                .kerning(-0.28.scale)

            filterTabs
        }
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8.scale) {
                ForEach(viewModel.filterChips) { chip in
                    Button {
                        viewModel.selectFilter(chip.filter)
                    } label: {
                        HStack(spacing: 8.scale) {
                            if let assetName = chip.assetImageName,
                               let icon = UIImage(named: assetName) {
                                Image(uiImage: icon)
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .frame(width: 24.scale, height: 24.scale)
                                    .foregroundStyle(Tokens.Color.inkPrimary)
                            } else if let symbol = chip.systemImageName {
                                Image(systemName: symbol)
                                    .font(.system(size: 16.scale, weight: .regular))
                                    .foregroundStyle(Tokens.Color.inkPrimary)
                            }

                            Text(chip.title)
                                .font(Tokens.Font.medium16)
                                .foregroundStyle(Tokens.Color.inkPrimary)
                                .kerning(-0.16.scale)
                        }
                        .frame(height: 52.scale)
                        .padding(.horizontal, 20.scale)
                        .background(
                            RoundedRectangle(cornerRadius: 20.scale, style: .continuous)
                                .fill(Tokens.Color.cardSoftBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20.scale, style: .continuous)
                                .stroke(
                                    viewModel.selectedFilter == chip.filter ? Tokens.Color.accent : Color.clear,
                                    lineWidth: 2.scale
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2.scale)
            .padding(.vertical, 2.scale)
        }
    }

    private var sectionsView: some View {
        VStack(alignment: .leading, spacing: 20.scale) {
            ForEach(viewModel.sections) { section in
                VStack(alignment: .leading, spacing: 8.scale) {
                    Text(section.title)
                        .font(Tokens.Font.medium14)
                        .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.6))
                        .kerning(-0.14.scale)

                    VStack(spacing: 8.scale) {
                        ForEach(section.items) { item in
                            historyRow(item: item)
                        }
                    }
                }
            }
        }
    }

    private func historyRow(item: RootHistorySceneViewModel.EntryItem, isHighlighted: Bool = false) -> some View {
        HStack(spacing: 8.scale) {
            HistoryPreviewCell(item: item)

            VStack(alignment: .leading, spacing: 2.scale) {
                Text(item.title)
                    .font(Tokens.Font.semibold16)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(item.subtitle)
                    .font(Tokens.Font.regular14)
                    .foregroundStyle(item.status == .failed ? Tokens.Color.inkPrimary : Tokens.Color.inkPrimary.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.openContextMenu(for: item.id)
            } label: {
                Group {
                    if let icon = UIImage(named: "history_more_24") {
                        Image(uiImage: icon)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                    } else {
                        Image(systemName: "ellipsis.vertical")
                            .resizable()
                            .scaledToFit()
                            .padding(2.scale)
                    }
                }
                .foregroundStyle(Tokens.Color.inkPrimary)
                .frame(width: 24.scale, height: 24.scale)
            }
            .buttonStyle(.plain)
            .frame(width: 24.scale, height: 24.scale)
            .padding(.trailing, 16.scale)
            .allowsHitTesting(!isHighlighted)
        }
        .frame(height: 64.scale)
        .padding(.leading, 0.scale)
        .padding(.trailing, 0.scale)
        .background(
            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                .fill(Tokens.Color.cardSoftBackground)
        )
        .overlay(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: HistoryRowFramePreferenceKey.self,
                    value: [item.id: geometry.frame(in: .global)]
                )
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 16.scale, style: .continuous))
        .onTapGesture {
            viewModel.tapEntry(item)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0.scale) {
            if viewModel.hasAnyEntries {
                VStack(spacing: 12.scale) {
                    Image(systemName: "tray")
                        .font(.system(size: 28.scale, weight: .regular))
                        .foregroundStyle(Tokens.Color.accent)

                    Text("No files for selected filter")
                        .font(Tokens.Font.semibold16)
                        .foregroundStyle(Tokens.Color.inkPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 88.scale)
            } else {
                VStack(spacing: 16.scale) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36.scale, weight: .regular))
                        .foregroundStyle(Tokens.Color.accent)

                    Text("Your history is empty")
                        .font(Tokens.Font.outfitSemibold18)
                        .foregroundStyle(Tokens.Color.inkPrimary)
                        .kerning(-0.18.scale)

                    Text("Create your first AI video, voiceover, or transcript, and it will appear here.")
                        .font(Tokens.Font.regular16)
                        .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4.scale)
                        .frame(maxWidth: 300.scale)

                    Button {
                        viewModel.tapCreateNew()
                    } label: {
                        Text("Create New")
                            .font(Tokens.Font.semibold16)
                            .foregroundStyle(Color.white)
                            .frame(width: 208.scale, height: 52.scale)
                            .background(
                                RoundedRectangle(cornerRadius: 20.scale, style: .continuous)
                                    .fill(Tokens.Color.accent)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8.scale)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 140.scale)
            }
        }
    }

    private func contextMenuOverlay(
        menuEntry: RootHistorySceneViewModel.EntryItem,
        frame: CGRect,
        containerFrame: CGRect,
        containerSize: CGSize
    ) -> some View {
        let localRowFrame = CGRect(
            x: frame.minX - containerFrame.minX,
            y: frame.minY - containerFrame.minY,
            width: frame.width,
            height: frame.height
        )

        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.dismissContextMenu()
                }

            historyRow(item: menuEntry, isHighlighted: true)
                .frame(width: containerSize.width - 32.scale, height: 64.scale)
                .position(x: containerSize.width / 2, y: localRowFrame.midY)

            menuCard
                .position(
                    x: menuCardCenterX(for: localRowFrame, containerSize: containerSize),
                    y: menuCardCenterY(for: localRowFrame, containerSize: containerSize)
                )
        }
    }

    private var menuCard: some View {
        VStack(spacing: 4.scale) {
            historyMenuButton(
                title: "Share",
                assetName: "history_share_20",
                fallbackSymbol: "square.and.arrow.up",
                textColor: Tokens.Color.inkPrimary
            ) {
                viewModel.tapShareFromMenu()
            }

            historyMenuButton(
                title: "Rename",
                assetName: "history_rename_20",
                fallbackSymbol: "pencil",
                textColor: Tokens.Color.inkPrimary
            ) {
                viewModel.tapRenameFromMenu()
            }

            historyMenuButton(
                title: "Delete",
                assetName: "history_delete_20",
                fallbackSymbol: "trash",
                textColor: Color(hex: "F42828") ?? Tokens.Color.destructive
            ) {
                viewModel.tapDeleteFromMenu()
            }
        }
        .padding(.horizontal, 8.scale)
        .padding(.vertical, 8.scale)
        .frame(width: 115.scale, height: 132.scale)
        .background(
            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                .fill(Tokens.Color.surfaceWhite)
        )
    }

    private func historyMenuButton(
        title: String,
        assetName: String,
        fallbackSymbol: String,
        textColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6.scale) {
                Group {
                    if let icon = UIImage(named: assetName) {
                        Image(uiImage: icon)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: fallbackSymbol)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(width: 20.scale, height: 20.scale)
                .foregroundStyle(textColor)

                Text(title)
                    .font(Tokens.Font.semibold16)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
            }
            .frame(width: 99.scale, height: 36.scale)
            .background(
                RoundedRectangle(cornerRadius: 10.scale, style: .continuous)
                    .fill(Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var deleteDialog: some View {
        ZStack {
            Tokens.Color.inkPrimary.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.dismissDeleteDialog()
                }

            VStack(spacing: 0.scale) {
                Text("Delete this file?")
                    .font(Tokens.Font.semibold16)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .padding(.top, 16.scale)

                Text("This action cannot be undone")
                    .font(Tokens.Font.regular14)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .padding(.top, 8.scale)

                HStack(spacing: 8.scale) {
                    Button {
                        viewModel.dismissDeleteDialog()
                    } label: {
                        Text("Cancel")
                            .font(Tokens.Font.outfitSemibold16)
                            .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.6))
                            .frame(width: 130.scale, height: 42.scale)
                            .background(
                                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                                    .fill(Tokens.Color.cardSoftBackground)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.confirmDelete()
                    } label: {
                        Text("Delete")
                            .font(Tokens.Font.outfitSemibold16)
                            .foregroundStyle(Color.white)
                            .frame(width: 130.scale, height: 42.scale)
                            .background(
                                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                                    .fill(Color(hex: "F42828") ?? Tokens.Color.destructive)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16.scale)
            }
            .frame(width: 300.scale, height: 137.scale)
            .background(
                RoundedRectangle(cornerRadius: 32.scale, style: .continuous)
                    .fill(Tokens.Color.surfaceWhite)
            )
        }
    }

    private var renameDialog: some View {
        ZStack {
            Tokens.Color.inkPrimary.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.dismissRenameDialog()
                }

            VStack(spacing: 0.scale) {
                VStack(alignment: .leading, spacing: 8.scale) {
                    HStack(spacing: 8.scale) {
                        Group {
                            if let icon = UIImage(named: "history_rename_20") {
                                Image(uiImage: icon)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(systemName: "pencil")
                                    .resizable()
                                    .scaledToFit()
                            }
                        }
                        .frame(width: 20.scale, height: 20.scale)
                        .foregroundStyle(Tokens.Color.inkPrimary)

                        TextField("", text: Binding(
                            get: { viewModel.renameDraft },
                            set: { viewModel.updateRenameDraft($0) }
                        ))
                        .font(Tokens.Font.semibold16)
                        .foregroundStyle(Tokens.Color.inkPrimary)
                        .focused($isRenameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            viewModel.saveRename()
                        }
                    }
                    .padding(.horizontal, 16.scale)
                    .frame(width: 258.scale, height: 52.scale)
                    .background(
                        RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                            .fill(Tokens.Color.cardSoftBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                            .stroke(
                                viewModel.renameValidationMessage == nil
                                ? Color.clear
                                : (Color(hex: "F42828") ?? Tokens.Color.destructive),
                                lineWidth: 2.scale
                            )
                    )

                    if let message = viewModel.renameValidationMessage {
                        Text(message)
                            .font(Tokens.Font.regular14)
                            .foregroundStyle(Color(hex: "F42828") ?? Tokens.Color.destructive)
                    }
                }
                .padding(.top, 16.scale)

                HStack(spacing: 8.scale) {
                    Button {
                        viewModel.dismissRenameDialog()
                    } label: {
                        Text("Cancel")
                            .font(Tokens.Font.outfitSemibold16)
                            .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.6))
                            .frame(width: 130.scale, height: 42.scale)
                            .background(
                                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                                    .fill(Tokens.Color.cardSoftBackground)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.saveRename()
                    } label: {
                        Text("Save")
                            .font(Tokens.Font.outfitSemibold16)
                            .foregroundStyle(Color.white)
                            .frame(width: 130.scale, height: 42.scale)
                            .background(
                                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                                    .fill(Tokens.Color.accent)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16.scale)
            }
            .frame(width: 300.scale, height: viewModel.renameValidationMessage == nil ? 142.scale : 168.scale)
            .background(
                RoundedRectangle(cornerRadius: 32.scale, style: .continuous)
                    .fill(Tokens.Color.surfaceWhite)
            )
        }
    }

    @ViewBuilder
    private func destinationView(for destination: RootHistorySceneViewModel.ResultDestination) -> some View {
        switch destination.kind {
        case .video(let url):
            TextToVideoResultSceneView(
                viewModel: resolver.resolve(TextToVideoResultSceneViewModel.self, argument: url)
                    ?? TextToVideoResultSceneViewModel(videoURL: url),
                onBack: {
                    viewModel.dismissResultDestination()
                }
            )

        case .image(let url):
            AIImageResultSceneView(
                viewModel: resolver.resolve(AIImageResultSceneViewModel.self, argument: url)
                    ?? AIImageResultSceneViewModel(imageURL: url),
                onBack: {
                    viewModel.dismissResultDestination()
                }
            )

        case .voice(let url, let title):
            VoiceGenResultSceneView(
                viewModel: resolver.resolve(VoiceGenResultSceneViewModel.self, arguments: url, title)
                    ?? VoiceGenResultSceneViewModel(audioURL: url, displayTitle: title),
                onBack: {
                    viewModel.dismissResultDestination()
                }
            )

        case .transcript(let payload):
            TranscribeResultSceneView(
                viewModel: resolver.resolve(TranscribeResultSceneViewModel.self, argument: payload)
                    ?? TranscribeResultSceneViewModel(payload: payload),
                onBack: {
                    viewModel.dismissResultDestination()
                }
            )
        }
    }

    private func menuCardCenterX(for frame: CGRect, containerSize: CGSize) -> CGFloat {
        let menuWidth = 115.scale
        let desired = frame.maxX - menuWidth / 2
        return min(max(desired, 16.scale + menuWidth / 2), containerSize.width - 16.scale - menuWidth / 2)
    }

    private func menuCardCenterY(for frame: CGRect, containerSize: CGSize) -> CGFloat {
        let menuHeight = 132.scale
        let desired = frame.maxY + 8.scale + menuHeight / 2
        return min(max(desired, 16.scale + menuHeight / 2), containerSize.height - 16.scale - menuHeight / 2)
    }
}

private struct HistoryPreviewCell: View {
    let item: RootHistorySceneViewModel.EntryItem

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            switch item.status {
            case .processing:
                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                    .fill(Tokens.Color.accent.opacity(0.05))

                HistoryProcessingIconView()
                    .frame(width: 24.scale, height: 24.scale)

            case .failed:
                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                    .fill((Color(hex: "F42828") ?? Tokens.Color.destructive).opacity(0.05))

                Group {
                    if let icon = UIImage(named: "history_failed_24") {
                        Image(uiImage: icon)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                    } else {
                        Image(systemName: "exclamationmark.triangle")
                            .resizable()
                            .scaledToFit()
                    }
                }
                .foregroundStyle(Color(hex: "F42828") ?? Tokens.Color.destructive)
                .frame(width: 24.scale, height: 24.scale)

            case .ready:
                readyPreview
            }
        }
        .frame(width: 64.scale, height: 64.scale)
        .contentShape(RoundedRectangle(cornerRadius: 16.scale, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16.scale, style: .continuous))
        .clipped()
        .onAppear {
            loadPreviewIfNeeded()
        }
        .onChange(of: item.mediaURL) { _, _ in
            image = nil
            loadPreviewIfNeeded()
        }
    }

    @ViewBuilder
    private var readyPreview: some View {
        switch item.flowKind {
        case .aiImage:
            mediaImagePreview

        case .textToVideo, .animateImage, .frameToVideo:
            mediaVideoPreview

        case .voiceGen:
            genericPreview(
                assetName: "history_voice_24",
                fallbackSymbol: "waveform",
                color: Tokens.Color.accent
            )

        case .transcribe:
            if item.transcribePayload?.isVideo == true {
                genericPreview(
                    assetName: "history_transcript_video_24",
                    fallbackSymbol: "film",
                    color: Tokens.Color.accent
                )
            } else {
                genericPreview(
                    assetName: "history_transcript_24",
                    fallbackSymbol: "doc.text",
                    color: Tokens.Color.accent
                )
            }
        }
    }

    @ViewBuilder
    private var mediaImagePreview: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            genericPreview(
                assetName: "history_image_24",
                fallbackSymbol: "photo",
                color: Tokens.Color.accent
            )
        }
    }

    @ViewBuilder
    private var mediaVideoPreview: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 24.scale, height: 24.scale)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 12.scale, weight: .semibold))
                                .foregroundStyle(Tokens.Color.inkPrimary)
                                .padding(.leading, 1.scale)
                        )
                }
        } else {
            genericPreview(
                assetName: "history_video_24",
                fallbackSymbol: "video",
                color: Tokens.Color.accent
            )
        }
    }

    private func genericPreview(
        assetName: String,
        fallbackSymbol: String,
        color: Color
    ) -> some View {
        RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
            .fill(color.opacity(0.05))
            .overlay(
                Group {
                    if let icon = UIImage(named: assetName) {
                        Image(uiImage: icon)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                    } else {
                        Image(systemName: fallbackSymbol)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .foregroundStyle(color)
                .frame(width: 24.scale, height: 24.scale)
            )
    }

    private func loadPreviewIfNeeded() {
        guard item.status == .ready else { return }
        guard let mediaURL = item.mediaURL else { return }
        guard image == nil else { return }

        Task {
            switch item.flowKind {
            case .aiImage:
                if let data = try? Data(contentsOf: mediaURL),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        image = uiImage
                    }
                }

            case .textToVideo, .animateImage, .frameToVideo:
                if let thumbnail = await makeVideoThumbnail(from: mediaURL) {
                    await MainActor.run {
                        image = thumbnail
                    }
                }

            case .voiceGen, .transcribe:
                break
            }
        }
    }

    private func makeVideoThumbnail(from url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 256.scale, height: 256.scale)

                do {
                    let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

private struct HistoryProcessingIconView: View {
    @State private var isRotating = false

    var body: some View {
        Group {
            if let image = UIImage(named: "history_processing_spinner_24") ??
                UIImage(named: "history_processing_24") ??
                UIImage(named: "Loader.Icon") {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Tokens.Color.accent)
            } else {
                ProgressView()
                    .tint(Tokens.Color.accent)
            }
        }
        .rotationEffect(.degrees(isRotating ? 360 : 0))
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                isRotating = true
            }
        }
        .onDisappear {
            isRotating = false
        }
    }
}

private struct HistoryRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
