import AVFoundation
import SwiftUI
import UIKit

struct TextToVideoResultSceneView: View {
    @ObservedObject var viewModel: TextToVideoResultSceneViewModel

    let onBack: () -> Void

    @State private var player = AVPlayer()
    @State private var isPlayerConfigured = false
    @State private var isPlaying = false
    @State private var isSharePresented = false

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom

            VStack(spacing: 16.scale) {
                header
                    .padding(.horizontal, 16.scale)
                    .padding(.top, max(8.scale, topInset + 8.scale))

                GeometryReader { contentProxy in
                    videoPanel
                        .frame(width: contentProxy.size.width, height: contentProxy.size.height)
                }

                Button {
                    viewModel.saveToGallery()
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
                .padding(.horizontal, 16.scale)
                .padding(.bottom, max(16.scale, bottomInset + 8.scale))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Color.surfaceWhite)
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(activityItems: [viewModel.videoURL])
        }
        .onAppear {
            configurePlayerIfNeeded()
        }
        .onDisappear {
            player.pause()
            isPlaying = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem,
                  item == player.currentItem else {
                return
            }

            player.seek(to: .zero)
            isPlaying = false
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

    private var videoPanel: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                .fill(Tokens.Color.cardSoftBackground)

            VStack(spacing: 0.scale) {
                Spacer(minLength: 0.scale)

                ZStack {
                    TextToVideoPlayerView(player: player)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 12.scale, style: .continuous)
                        )

                    Button {
                        togglePlayback()
                    } label: {
                        playbackIcon
                        .frame(width: 48.scale, height: 48.scale)
                        .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(12.scale)

                Spacer(minLength: 0.scale)
            }

            if let toast = viewModel.toast {
                toastView(for: toast)
                    .padding(.top, 16.scale)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16.scale)
    }

    private var playbackIcon: some View {
        Group {
            let assetName = isPlaying ? "ttv_stop_48" : "ttv_play_48"
            if let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Tokens.Color.toastSurface.opacity(0.95))
                    .overlay(
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Tokens.Color.accent)
                            .padding(12.scale)
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
                            .font(.system(size: 16.scale, weight: .semibold))
                            .foregroundStyle(Tokens.Color.inkPrimary)
                    )
            }
        }
    }

    @ViewBuilder
    private func toastView(for toast: TextToVideoResultSceneViewModel.SaveToast) -> some View {
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

            Text(toast == .saved ? "Saved to Gallery" : "Failed to save")
                .font(Tokens.Font.semibold16)
                .foregroundStyle(Tokens.Color.inkPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8.scale)
        .frame(width: 194.scale, height: 56.scale)
        .background(
            Capsule(style: .continuous)
                .fill(Tokens.Color.toastSurface)
        )
    }

    private func configurePlayerIfNeeded() {
        guard !isPlayerConfigured else { return }
        isPlayerConfigured = true
        player.replaceCurrentItem(with: AVPlayerItem(url: viewModel.videoURL))
        player.actionAtItemEnd = .pause
    }

    private func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
            return
        }

        player.play()
        isPlaying = true
    }
}

private struct TextToVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> TextToVideoPlayerContainerView {
        let view = TextToVideoPlayerContainerView()
        view.setPlayer(player)
        return view
    }

    func updateUIView(_ uiView: TextToVideoPlayerContainerView, context: Context) {
        uiView.setPlayer(player)
    }
}

private final class TextToVideoPlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    func setPlayer(_ player: AVPlayer) {
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
    }
}
