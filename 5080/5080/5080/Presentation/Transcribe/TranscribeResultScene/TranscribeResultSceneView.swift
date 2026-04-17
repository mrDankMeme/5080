import SwiftUI
import UIKit

struct TranscribeResultSceneView: View {
    @ObservedObject var viewModel: TranscribeResultSceneViewModel

    let onBack: () -> Void

    @State private var isSharePresented = false

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .top) {
                VStack(spacing: 0.scale) {
                    header
                        .padding(.horizontal, 16.scale)
                        .padding(.top, max(8.scale, topInset + 8.scale))

                    fileCard
                        .padding(.horizontal, 16.scale)
                        .padding(.top, 12.scale)

                    Text(viewModel.sectionTitle)
                        .font(Tokens.Font.outfitSemibold18)
                        .foregroundStyle(Tokens.Color.inkPrimary)
                        .kerning(-0.18.scale)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16.scale)
                        .padding(.top, 16.scale)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12.scale) {
                            if viewModel.isSummary {
                                summaryContent
                            } else {
                                transcriptContent
                            }
                        }
                        .padding(.horizontal, 16.scale)
                        .padding(.top, 4.scale)
                        .padding(.bottom, 16.scale)
                    }

                    Button {
                        viewModel.copyText()
                    } label: {
                        Text(viewModel.copyButtonTitle)
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

                if viewModel.copyState == .copied {
                    copiedToast
                        //.padding(.top, max(8.scale, topInset + 8.scale) + 56.scale)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(activityItems: [viewModel.formattedExportText])
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.copyState)
    }

    private var header: some View {
        HStack(spacing: 12.scale) {
            Button(action: onBack) {
                headerBackIcon
                    .frame(width: 40.scale, height: 40.scale)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0.scale)

            Text("Transcription")
                .font(Tokens.Font.outfitSemibold16)
                .foregroundStyle(Tokens.Color.inkPrimary)
                .kerning(-0.16.scale)

            Spacer(minLength: 0.scale)

            Button {
                isSharePresented = true
            } label: {
                Circle()
                    .fill(Tokens.Color.cardSoftBackground)
                    .frame(width: 40.scale, height: 40.scale)
                    .overlay(
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20.scale, weight: .regular))
                            .foregroundStyle(Tokens.Color.inkPrimary)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var fileCard: some View {
        HStack(spacing: 10.scale) {
            fileIcon
                .frame(width: 24.scale, height: 24.scale)

            HStack(spacing: 0.scale) {
                Text(viewModel.fileBaseName)
                    .font(Tokens.Font.regular16)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(0)

                if let extensionText = viewModel.fileExtensionText {
                    Text(extensionText)
                        .font(Tokens.Font.regular16)
                        .foregroundStyle(Tokens.Color.inkPrimary)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }

            Spacer(minLength: 0.scale)
        }
        .padding(.horizontal, 16.scale)
        .frame(height: 56.scale)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                .fill(Tokens.Color.cardSoftBackground)
        )
    }

    private var transcriptContent: some View {
        VStack(alignment: .leading, spacing: 12.scale) {
            if viewModel.transcriptRows.isEmpty {
                Text(viewModel.payload.rawResultJSONString)
                    .font(Tokens.Font.regular16)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .lineSpacing(6.scale)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(viewModel.transcriptRows) { row in
                    VStack(alignment: .leading, spacing: 8.scale) {
                        if let timestampText = row.timestampText,
                           viewModel.payload.timestampsEnabled {
                            Text(timestampText)
                                .font(Tokens.Font.regular16)
                                .foregroundStyle(Tokens.Color.accent)
                                .padding(.horizontal, 12.scale)
                                .frame(height: 27.scale)
                                .background(
                                    RoundedRectangle(cornerRadius: 8.scale, style: .continuous)
                                        .fill(Tokens.Color.accent.opacity(0.05))
                                )
                        }

                        Text(row.text)
                            .font(Tokens.Font.regular16)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .lineSpacing(6.scale)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.bottom, 12.scale)
                }
            }
        }
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 16.scale) {
            if viewModel.summaryRows.isEmpty {
                Text(viewModel.payload.rawResultJSONString)
                    .font(Tokens.Font.regular16)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .lineSpacing(6.scale)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(viewModel.summaryRows) { row in
                    VStack(alignment: .leading, spacing: 8.scale) {
                        Text(row.title)
                            .font(Tokens.Font.outfitSemibold18)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .kerning(-0.18.scale)

                        Text(row.text)
                            .font(Tokens.Font.regular16)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .lineSpacing(6.scale)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var fileIcon: some View {
        Group {
            if let image = UIImage(named: viewModel.fileIconAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: viewModel.payload.isVideo ? "film" : "waveform")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Tokens.Color.inkPrimary)
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
                            .font(.system(size: 16.scale, weight: .semibold))
                            .foregroundStyle(Tokens.Color.inkPrimary)
                    )
            }
        }
    }

    private var copiedToast: some View {
        HStack(spacing: 8.scale) {
            if let image = UIImage(named: "ttv_toast_success_40") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40.scale, height: 40.scale)
            } else {
                Circle()
                    .fill(Tokens.Color.accent)
                    .frame(width: 40.scale, height: 40.scale)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(Tokens.Font.semibold20)
                            .foregroundStyle(Color.white)
                    )
            }

            Text("Text copied")
                .font(Tokens.Font.semibold16)
                .foregroundStyle(Tokens.Color.inkPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8.scale)
        .frame(height: 56.scale)
        .background(
            Capsule(style: .continuous)
                .fill(Tokens.Color.toastSurface)
        )
    }
}
