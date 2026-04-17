import AVFoundation
import SwiftUI
import UIKit

struct BillingBalanceAccessoryView: View {
    let isSubscribed: Bool
    let formattedTokens: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6.scale) {
                accessoryIcon
                    .frame(width: 20.scale, height: 20.scale)

                Text(accessoryTitle)
                    .font(Tokens.Font.semibold16)
                    .foregroundStyle(Tokens.Color.accent)
                    .kerning(-0.16.scale)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16.scale)
            .frame(minWidth: isSubscribed ? 94.scale : 108.scale)
            .frame(height: 40.scale)
            .background(
                Capsule()
                    .fill(Tokens.Color.surfaceWhite)
            )
            .overlay(
                Capsule()
                    .stroke(
                        Tokens.Color.accent,
                        lineWidth: 2.scale
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var accessoryTitle: String {
        isSubscribed ? formattedTokens : "Premium"
    }

    @ViewBuilder
    private var accessoryIcon: some View {
        if isSubscribed {
            tokenIcon
        } else {
            premiumIcon
        }
    }

    private var tokenIcon: some View {
        Group {
            if let image = UIImage(named: "Loader.Icon") {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Tokens.Color.accent)
            } else {
                Image(systemName: "sparkles")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Tokens.Color.accent)
            }
        }
    }

    private var premiumIcon: some View {
        Group {
            if UIImage(named: "premium") != nil {
                Image("premium")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Tokens.Color.accent)
            } else {
                Image(systemName: "crown.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Tokens.Color.accent)
            }
        }
    }
}

struct RootHomeSceneView: View {
    @ObservedObject var viewModel: RootHomeSceneViewModel

    var body: some View {
        GeometryReader { proxy in
            let trendingCardWidth = max(0.scale, (proxy.size.width - 40.scale) / 2.0)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0.scale) {
                    featuredSection
                    trendingSection(cardWidth: trendingCardWidth)
                        .padding(.top, 40.scale)
                        .padding(.bottom, 120.scale)
                }
            }
            .safeAreaInset(edge: .top, spacing: 16.scale) {
                RootHomeHeaderView(
                    title: viewModel.appTitle,
                    isSubscribed: viewModel.isSubscribed,
                    formattedTokens: viewModel.formattedTokens,
                    onTapBalance: {
                        viewModel.openTokensPaywall()
                    }
                )
                .padding(.horizontal, 16.scale)
                .padding(.top, 16.scale)
                .padding(.bottom, 8.scale)
                .background(Tokens.Color.surfaceWhite)
            }
            .background(Tokens.Color.surfaceWhite.ignoresSafeArea())
        }
    }

    private var featuredSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8.scale) {
                ForEach(viewModel.featuredCards) { card in
                    RootHomeFeaturedCardView(card: card) {
                        viewModel.selectCard(card)
                    }
                }
            }
            .padding(.horizontal, 16.scale)
        }
    }

    private func trendingSection(cardWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12.scale) {
            Text("Trending")
                .font(Tokens.Font.outfitSemibold18)
                .foregroundStyle(Tokens.Color.inkPrimary)
                .kerning(-0.18.scale)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8.scale),
                    GridItem(.flexible(), spacing: 8.scale)
                ],
                spacing: 8.scale
            ) {
                ForEach(viewModel.trendingCards) { card in
                    RootHomeTrendingCardView(
                        card: card,
                        cardWidth: cardWidth
                    ) {
                        viewModel.selectCard(card)
                    }
                }
            }
        }
        .padding(.horizontal, 16.scale)
    }
}

private struct RootHomeHeaderView: View {
    let title: String
    let isSubscribed: Bool
    let formattedTokens: String
    let onTapBalance: () -> Void

    var body: some View {
        HStack(spacing: 12.scale) {
            Text(title)
                .font(Tokens.Font.outfitBold23)
                .foregroundStyle(Tokens.Color.inkPrimary)
                .kerning(-0.28.scale)
                .lineLimit(1)

            Spacer(minLength: 12.scale)

            BillingBalanceAccessoryView(
                isSubscribed: isSubscribed,
                formattedTokens: formattedTokens,
                action: onTapBalance
            )
        }
        .frame(height: 40.scale)
    }
}

private struct RootHomeFeaturedCardView: View {
    let card: RootHomePromptCard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                RootHomeCardArtworkView(
                    preview: card.preview,
                    mode: card.mode,
                    title: card.title
                )
                .frame(width: 300.scale, height: 180.scale)
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.18),
                            Color.black.opacity(0.72)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                RootHomeModeBadgeView(title: card.mode.title)
                    .padding(.top, 12.scale)
                    .padding(.trailing, 12.scale)

                VStack(alignment: .leading, spacing: 4.scale) {
                    Spacer(minLength: 0.scale)

                    Text(card.title)
                        .font(Tokens.Font.semibold16)
                        .foregroundStyle(Tokens.Color.surfaceWhite)
                        .lineLimit(1)
                        .kerning(-0.16.scale)

                    Text(card.prompt)
                        .font(Tokens.Font.regular14)
                        .foregroundStyle(Tokens.Color.surfaceWhite)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16.scale)
                .padding(.vertical, 16.scale)
                .frame(width: 300.scale, height: 180.scale, alignment: .bottomLeading)
            }
            .frame(width: 300.scale, height: 180.scale)
            .clipShape(RoundedRectangle(cornerRadius: 16.scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct RootHomeTrendingCardView: View {
    let card: RootHomePromptCard
    let cardWidth: CGFloat
    let action: () -> Void

    private var cardHeight: CGFloat {
        cardWidth + 117.5.scale
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0.scale) {
                RootHomeCardArtworkView(
                    preview: card.preview,
                    mode: card.mode,
                    title: card.title
                )
                .frame(width: cardWidth, height: cardWidth)
                .clipped()

                VStack(alignment: .leading, spacing: 8.scale) {
                    VStack(alignment: .leading, spacing: 4.scale) {
                        Text(card.title)
                            .font(Tokens.Font.semibold16)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .lineLimit(1)
                            .kerning(-0.16.scale)

                        Text(card.prompt)
                            .font(Tokens.Font.regular14)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0.scale)

                    RootHomeModeBadgeView(title: card.mode.title)
                }
                .padding(8.scale)
                .frame(width: cardWidth, height: 117.5.scale, alignment: .topLeading)
                .background(Tokens.Color.cardSoftBackground)
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(Tokens.Color.cardSoftBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16.scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct RootHomeCardArtworkView: View {
    let preview: RootHomePromptCardPreview
    let mode: RootHomeGenerationMode
    let title: String

    var body: some View {
        switch preview {
        case .asset(let assetName):
            Group {
                if let image = UIImage(named: assetName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RootHomePlaceholderArtworkView(
                        mode: mode,
                        title: title
                    )
                }
            }
        case .media(let url):
            RootHomeMediaArtworkView(
                url: url,
                mode: mode,
                title: title
            )
        }
    }
}

private struct RootHomeMediaArtworkView: View {
    let url: URL
    let mode: RootHomeGenerationMode
    let title: String

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RootHomePlaceholderArtworkView(
                    mode: mode,
                    title: title
                )
            }
        }
        .task(id: url) {
            await loadPreviewIfNeeded()
        }
    }
}

private extension RootHomeMediaArtworkView {
    func loadPreviewIfNeeded() async {
        guard image == nil else { return }

        let previewSize = CGSize(width: 512.scale, height: 512.scale)
        let resolvedImage: UIImage? = await Task.detached(priority: .userInitiated) {
            switch mode {
            case .aiImage:
                guard let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data) else {
                    return nil
                }
                return image

            case .textToVideo, .frameToVideo, .animateImage:
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = previewSize

                guard let cgImage = try? await generator.image(
                    at: CMTime(seconds: 0.1, preferredTimescale: 600)
                ).image else {
                    return nil
                }
                return UIImage(cgImage: cgImage)
            }
        }.value

        guard let resolvedImage else { return }
        image = resolvedImage
    }
}

private struct RootHomePlaceholderArtworkView: View {
    let mode: RootHomeGenerationMode
    let title: String

    private var gradient: LinearGradient {
        switch mode {
        case .textToVideo:
            return LinearGradient(
                colors: [Tokens.Color.accent, Tokens.Color.lightAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .frameToVideo:
            return LinearGradient(
                colors: [Tokens.Color.inkPrimary, Tokens.Color.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .animateImage:
            return LinearGradient(
                colors: [Tokens.Color.accentSoft, Tokens.Color.lightAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .aiImage:
            return LinearGradient(
                colors: [Tokens.Color.componentsBackground, Tokens.Color.accentSoft],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                .fill(gradient)

            Circle()
                .fill(Color.white.opacity(0.24))
                .frame(width: 116.scale, height: 116.scale)
                .blur(radius: 12.scale)
                .offset(x: 82.scale, y: -42.scale)

            Circle()
                .fill(Color.black.opacity(0.12))
                .frame(width: 140.scale, height: 140.scale)
                .blur(radius: 22.scale)
                .offset(x: -74.scale, y: 76.scale)

            VStack(alignment: .leading, spacing: 8.scale) {
                Image(systemName: "photo")
                    .font(.system(size: 24.scale, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.9))

                Text(title)
                    .font(Tokens.Font.semibold16)
                    .foregroundStyle(Tokens.Color.surfaceWhite)
                    .multilineTextAlignment(.leading)
            }
            .padding(16.scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }
}

private struct RootHomeModeBadgeView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Tokens.Font.regular13)
            .foregroundStyle(Tokens.Color.inkPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 10.scale)
            .frame(width: 95.scale, height: 24.scale)
            .background(
                RoundedRectangle(cornerRadius: 8.scale, style: .continuous)
                    .fill(Color.white.opacity(0.34))
            )
            .background(
                RoundedRectangle(cornerRadius: 8.scale, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8.scale, style: .continuous)
                    .stroke(Color.white.opacity(0.92), lineWidth: 1.scale)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8.scale, style: .continuous))
    }
}
