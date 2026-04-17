import SwiftUI
import UIKit

struct AIImageResultSceneView: View {
    @ObservedObject var viewModel: AIImageResultSceneViewModel

    let onBack: () -> Void

    @State private var isSharePresented = false

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom
            let headerTopPadding = max(8.scale, topInset + 8.scale)

            VStack(spacing: 16.scale) {
                header
                    .padding(.horizontal, 16.scale)
                    .padding(.top, headerTopPadding)

                GeometryReader { contentProxy in
                    imagePanel
                        .frame(
                            width: max(0.scale, contentProxy.size.width - 32.scale),
                            height: contentProxy.size.height
                        )
                        .frame(
                            width: contentProxy.size.width,
                            height: contentProxy.size.height,
                            alignment: .top
                        )
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
            .overlay(alignment: .top) {
                if let toast = viewModel.toast {
                    toastView(for: toast)
                        //.padding(.top, max(0.scale, headerTopPadding - 8.scale))
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(20)
                }
            }
        }
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(activityItems: [viewModel.imageURL])
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.toast)
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
                            .font(Tokens.Font.medium22)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var imagePanel: some View {
        GeometryReader { panelProxy in
            let contentWidth = max(0.scale, panelProxy.size.width - 24.scale)
            let contentHeight = max(0.scale, panelProxy.size.height - 24.scale)

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                    .fill(Tokens.Color.cardSoftBackground)

                Group {
                    if let image = viewModel.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: contentWidth, height: contentHeight)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 12.scale, style: .continuous)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12.scale, style: .continuous)
                            .fill(Tokens.Color.strokeSoft)
                            .frame(width: contentWidth, height: contentHeight)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(Tokens.Font.outfitSemibold22)
                                    .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.3))
                            )
                    }
                }
                .padding(12.scale)
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

    @ViewBuilder
    private func toastView(for toast: AIImageResultSceneViewModel.SaveToast) -> some View {
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
                                .font(Tokens.Font.semibold20)
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
                            .font(Tokens.Font.semibold20)
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
}
