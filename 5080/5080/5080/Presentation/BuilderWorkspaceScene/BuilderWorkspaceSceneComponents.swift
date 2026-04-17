import SwiftUI

struct BuilderWorkspaceSegmentedControl: View {
    @Binding var selectedPane: BuilderPane

    var body: some View {
        HStack(spacing: 0.scale) {
            ForEach(BuilderPane.allCases) { pane in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selectedPane = pane
                    }
                } label: {
                    Text(pane.rawValue)
                        .font(Tokens.Font.semibold17)
                        .foregroundStyle(
                            selectedPane == pane
                                ? Tokens.Color.surfaceWhite
                                : Tokens.Color.inkPrimary.opacity(0.76)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12.scale)
                        .background {
                            if selectedPane == pane {
                                Capsule()
                                    .fill(Tokens.Color.base44BrandOrange)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5.scale)
        .background(Tokens.Color.surfaceWhite.opacity(0.94))
        .clipShape(Capsule())
    }
}

struct UploadedAssetsStripView: View {
    let assets: [BuilderUploadedAssetItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10.scale) {
                ForEach(assets) { asset in
                    HStack(spacing: 8.scale) {
                        Image(systemName: asset.mimeType == "application/pdf" ? "doc.text.fill" : "photo.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14.scale, height: 14.scale)
                            .foregroundStyle(Tokens.Color.base44BrandOrange)

                        Text(asset.fileName)
                            .font(Tokens.Font.medium13)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10.scale)
                    .frame(height: 36.scale)
                    .background(Tokens.Color.surfaceWhite.opacity(0.96))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Tokens.Color.base44Border, lineWidth: 1.scale)
                    }
                }
            }
            .padding(.horizontal, 1.scale)
        }
    }
}
