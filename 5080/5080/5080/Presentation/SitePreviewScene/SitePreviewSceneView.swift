import SwiftUI

struct SitePreviewSceneView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SitePreviewSceneViewModel

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

            Text(viewModel.captionText)
                .font(Tokens.Font.regular16)
                .foregroundStyle(Tokens.Color.textSecondary)
                .multilineTextAlignment(.leading)
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
        SitePreviewWebView(
            url: viewModel.previewURL,
            reloadKey: viewModel.previewReloadKey
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28.scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28.scale, style: .continuous)
                .stroke(Tokens.Color.base44Border, lineWidth: 1.scale)
        }
        .shadow(color: Tokens.Color.inkPrimary.opacity(0.08), radius: 20.scale, y: 10.scale)
    }
}
