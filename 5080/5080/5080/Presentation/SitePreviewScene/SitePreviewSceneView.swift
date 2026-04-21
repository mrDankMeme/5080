import SwiftUI

struct SitePreviewSceneView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SitePreviewSceneViewModel
    @State private var isPreviewLoading = true
    @State private var previewProgress = 0.0
    @State private var isPreviewProgressVisible = false
    @State private var progressBarHideTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 16.scale) {
                headerView
                projectHeading
                addressCard
                previewCard
            }
            .padding(.horizontal, 16.scale)
            .padding(.top, 8.scale)
            .padding(.bottom, max(16.scale, proxy.safeAreaInsets.bottom + 8.scale))
            .frame(
                width: proxy.size.width,
                height: proxy.size.height,
                alignment: .top
            )
            .background(backgroundView.ignoresSafeArea())
        }
        .onDisappear {
            progressBarHideTask?.cancel()
        }
    }
}

private extension SitePreviewSceneView {
    var backgroundView: some View {
        LinearGradient(
            colors: [
                Tokens.Color.base44SkyBlue,
                Tokens.Color.surfaceWhite,
                Tokens.Color.base44WarmCream
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var headerView: some View {
        HStack(spacing: 12.scale) {
            Button {
                dismiss()
            } label: {
                Circle()
                    .fill(Tokens.Color.surfaceWhite.opacity(0.96))
                    .frame(width: 40.scale, height: 40.scale)
                    .overlay {
                        Image(systemName: "chevron.left")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 11.scale, height: 18.scale)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                    }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0.scale)
        }
    }

    var projectHeading: some View {
        VStack(alignment: .leading, spacing: 10.scale) {
            Text(viewModel.badgeTitle)
                .font(Tokens.Font.semibold13)
                .foregroundStyle(Tokens.Color.base44BrandOrange)
                .padding(.horizontal, 10.scale)
                .frame(height: 28.scale)
                .background(Tokens.Color.base44BrandOrange.opacity(0.12))
                .clipShape(Capsule())

            Text(viewModel.titleText)
                .font(Tokens.Font.bold24)
                .foregroundStyle(Tokens.Color.inkPrimary)
                .multilineTextAlignment(.leading)

            if !viewModel.captionText.trimmed.isEmpty {
                Text(viewModel.captionText)
                    .font(Tokens.Font.regular16)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    var addressCard: some View {
        HStack(alignment: .center, spacing: 14.scale) {
            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                .fill(Tokens.Color.base44BrandOrange.opacity(0.12))
                .frame(width: 52.scale, height: 52.scale)
                .overlay {
                    Image(systemName: "globe")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20.scale, height: 20.scale)
                        .foregroundStyle(Tokens.Color.base44BrandOrange)
                }

            VStack(alignment: .leading, spacing: 4.scale) {
                Text(viewModel.domainText)
                    .font(Tokens.Font.semibold17)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .lineLimit(1)

                Text(viewModel.addressText)
                    .font(Tokens.Font.regular13)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12.scale)

            Button {
                viewModel.copyAddress()
            } label: {
                HStack(spacing: 6.scale) {
                    Image(systemName: viewModel.copyButtonSystemImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 13.scale, height: 13.scale)

                    Text(viewModel.copyButtonTitle)
                        .font(Tokens.Font.semibold13)
                }
                .foregroundStyle(
                    viewModel.isCopyConfirmationVisible
                        ? Tokens.Color.base44BrandOrange
                        : Tokens.Color.surfaceWhite
                )
                .padding(.horizontal, 12.scale)
                .frame(height: 36.scale)
                .background(
                    viewModel.isCopyConfirmationVisible
                        ? Tokens.Color.base44BrandOrange.opacity(0.12)
                        : Tokens.Color.base44BrandOrange
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16.scale)
        .background(Tokens.Color.surfaceWhite.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 24.scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24.scale, style: .continuous)
                .stroke(Tokens.Color.base44Border, lineWidth: 1.scale)
        }
        .shadow(color: Tokens.Color.inkPrimary.opacity(0.08), radius: 18.scale, y: 8.scale)
    }

    var previewCard: some View {
        ZStack(alignment: .bottom) {
            SitePreviewWebView(
                url: viewModel.previewURL,
                reloadKey: viewModel.previewReloadKey,
                onLoadingChanged: { isLoading in
                    if isLoading {
                        progressBarHideTask?.cancel()
                        progressBarHideTask = nil
                        if !isPreviewLoading {
                            isPreviewLoading = true
                        }
                    } else if previewProgress >= 1.0 || previewProgress <= 0.0 {
                        if isPreviewLoading {
                            isPreviewLoading = false
                        }
                    }
                },
                onProgressChanged: { progress in
                    updatePreviewProgress(progress)
                }
            )

            if isPreviewLoading {
                VStack(spacing: 12.scale) {
                    ProgressView()
                        .tint(Tokens.Color.base44BrandOrange)
                        .scaleEffect(1.05)

                    Text("Your live website is loading. Please wait a moment.")
                        .font(Tokens.Font.medium15)
                        .foregroundStyle(Tokens.Color.inkPrimary.opacity(0.66))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24.scale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.Color.surfaceWhite.opacity(0.96))
            }

            if isPreviewProgressVisible {
                previewProgressBar
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28.scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28.scale, style: .continuous)
                .stroke(Tokens.Color.base44Border, lineWidth: 1.scale)
        }
        .shadow(color: Tokens.Color.inkPrimary.opacity(0.08), radius: 20.scale, y: 10.scale)
    }

    var previewProgressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Tokens.Color.inkPrimary.opacity(0.08))

                Capsule()
                    .fill(Tokens.Color.base44BrandOrange)
                    .frame(width: max(8.scale, proxy.size.width * previewProgress))
            }
        }
        .frame(height: 3.scale)
        .padding(.horizontal, 14.scale)
        .padding(.bottom, 12.scale)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.16), value: previewProgress)
    }

    func updatePreviewProgress(_ rawProgress: Double) {
        let clampedProgress = min(max(rawProgress, 0.0), 1.0)

        progressBarHideTask?.cancel()
        progressBarHideTask = nil

        guard clampedProgress > 0 else {
            previewProgress = 0.0
            isPreviewProgressVisible = false
            return
        }

        previewProgress = clampedProgress
        isPreviewProgressVisible = true

        guard clampedProgress >= 1.0 else {
            if !isPreviewLoading {
                isPreviewLoading = true
            }
            return
        }

        if isPreviewLoading {
            withAnimation(.easeInOut(duration: 0.18)) {
                isPreviewLoading = false
            }
        }

        progressBarHideTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                isPreviewProgressVisible = false
            }
        }
    }
}
