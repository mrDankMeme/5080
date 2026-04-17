import SwiftUI
import UIKit

struct VoiceGenResultSceneView: View {
    @ObservedObject var viewModel: VoiceGenResultSceneViewModel

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

                    Spacer(minLength: 0.scale)

                    VoiceResultGlyphView()
                        .frame(width: 80.scale, height: 80.scale)

                    Spacer(minLength: 0.scale)

                    VStack(spacing: 0.scale) {
                        Text(viewModel.displayTitle)
                            .font(Tokens.Font.outfitSemibold18)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .kerning(-0.18.scale)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 16.scale)

                        VoiceWaveformTrackView(viewModel: viewModel)
                            .frame(height: 80.scale)
                            .padding(.horizontal, 16.scale)
                            .padding(.top, 16.scale)

                        HStack(spacing: 0.scale) {
                            Text(viewModel.currentTimeText)
                                .font(Tokens.Font.regular14)
                                .foregroundStyle(Tokens.Color.inkPrimary)

                            Spacer(minLength: 0.scale)

                            Text(viewModel.durationText)
                                .font(Tokens.Font.regular14)
                                .foregroundStyle(Tokens.Color.inkPrimary)
                        }
                        .padding(.horizontal, 16.scale)
                        .padding(.top, 4.scale)

                        HStack(spacing: 16.scale) {
                            Button {
                                viewModel.skipBackward()
                            } label: {
                                rewindIcon
                                    .frame(width: 32.scale, height: 32.scale)
                            }
                            .buttonStyle(.plain)

                            Button {
                                viewModel.togglePlayback()
                            } label: {
                                playbackIcon
                                    .frame(width: 48.scale, height: 48.scale)
                            }
                            .buttonStyle(.plain)

                            Button {
                                viewModel.skipForward()
                            } label: {
                                forwardIcon
                                    .frame(width: 32.scale, height: 32.scale)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 8.scale)
                    }

                    Button {
                        viewModel.saveToFiles()
                    } label: {
                        Text(viewModel.saveButtonTitle)
                            .font(Tokens.Font.semibold16)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52.scale)
                            .background(
                                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                                    .fill(Tokens.Color.accent.opacity(viewModel.saveButtonOpacity))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSaveDisabled)
                    .padding(.top, 52.scale)
                    .padding(.horizontal, 16.scale)
                    .padding(.bottom, max(16.scale, bottomInset + 8.scale))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.Color.surfaceWhite)
                .ignoresSafeArea()

                if let toast = viewModel.toast {
                    toastView(for: toast)
                        //.padding(.top, max(8.scale, topInset + 8.scale) + 44.scale)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.toast)
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(activityItems: [viewModel.audioURL])
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
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

            Text("Your Creation")
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

    private var playbackIcon: some View {
        Group {
            if let image = UIImage(named: viewModel.playButtonAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Tokens.Color.toastSurface.opacity(0.95))
                    .overlay(
                        Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Tokens.Color.accent)
                            .padding(12.scale)
                    )
            }
        }
        .clipShape(Circle())
    }

    private var rewindIcon: some View {
        Group {
            if let image = UIImage(named: "vg_rewind_32") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 22.scale, weight: .regular))
                    .foregroundStyle(Tokens.Color.inkPrimary)
            }
        }
    }

    private var forwardIcon: some View {
        Group {
            if let image = UIImage(named: "vg_forward_32") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "goforward.10")
                    .font(.system(size: 22.scale, weight: .regular))
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

    @ViewBuilder
    private func toastView(for toast: VoiceGenResultSceneViewModel.SaveToast) -> some View {
        HStack(spacing: 8.scale) {
            if toast == .saved {
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
                                .font(.system(size: 20.scale, weight: .semibold))
                                .foregroundStyle(Color.white)
                        )
                }
            } else if let image = UIImage(named: "ttv_toast_failed_40") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40.scale, height: 40.scale)
            } else {
                Circle()
                    .fill(Tokens.Color.destructive)
                    .frame(width: 40.scale, height: 40.scale)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 20.scale, weight: .semibold))
                            .foregroundStyle(Color.white)
                    )
            }

            Text(viewModel.toastTitle)
                .font(Tokens.Font.semibold16)
                .foregroundStyle(Tokens.Color.inkPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8.scale)
        .frame(width: 210.scale, height: 56.scale)
        .background(
            Capsule(style: .continuous)
                .fill(Tokens.Color.toastSurface)
        )
    }
}

private struct VoiceWaveformTrackView: View {
    @ObservedObject var viewModel: VoiceGenResultSceneViewModel

    private let barWidth: CGFloat = 2.scale
    private let barSpacing: CGFloat = 2.scale

    var body: some View {
        GeometryReader { proxy in
            let totalBars = max(1, Int((proxy.size.width + barSpacing) / (barWidth + barSpacing)))
            let samples = viewModel.waveformSamples(for: totalBars)
            let playedBars = Int(CGFloat(totalBars) * viewModel.playbackProgress)

            HStack(alignment: .top, spacing: barSpacing) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                    Capsule(style: .continuous)
                        .fill(index < playedBars ? Tokens.Color.accent : Tokens.Color.strokeSoft.opacity(0.55))
                        .frame(width: barWidth, height: max(6.scale, min(80.scale, sample * 80.scale)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct VoiceResultGlyphView: View {
    var body: some View {
        Group {
            if let image = UIImage(named: "vg_result_80") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                HStack(spacing: 8.scale) {
                    RoundedRectangle(cornerRadius: 2.scale, style: .continuous)
                        .fill(Tokens.Color.accent)
                        .frame(width: 8.scale, height: 30.scale)

                    RoundedRectangle(cornerRadius: 2.scale, style: .continuous)
                        .fill(Tokens.Color.accent)
                        .frame(width: 8.scale, height: 52.scale)

                    RoundedRectangle(cornerRadius: 2.scale, style: .continuous)
                        .fill(Tokens.Color.accent)
                        .frame(width: 8.scale, height: 70.scale)

                    RoundedRectangle(cornerRadius: 2.scale, style: .continuous)
                        .fill(Tokens.Color.accent)
                        .frame(width: 8.scale, height: 52.scale)

                    RoundedRectangle(cornerRadius: 2.scale, style: .continuous)
                        .fill(Tokens.Color.accent)
                        .frame(width: 8.scale, height: 30.scale)
                }
            }
        }
    }
}
