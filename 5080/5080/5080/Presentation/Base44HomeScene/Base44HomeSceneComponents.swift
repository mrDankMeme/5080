import SwiftUI

struct Base44ProjectRowView: View {
    let project: SiteMakerProjectSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14.scale) {
                RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                    .fill(Tokens.Color.base44BrandOrange.opacity(0.12))
                    .frame(width: 52.scale, height: 52.scale)
                    .overlay {
                        Image(systemName: project.previewURLString == nil ? "wand.and.stars" : "globe")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18.scale, height: 18.scale)
                            .foregroundStyle(Tokens.Color.base44BrandOrange)
                    }

                VStack(alignment: .leading, spacing: 6.scale) {
                    Text(project.name)
                        .font(Tokens.Font.semibold17)
                        .foregroundStyle(Tokens.Color.inkPrimary)
                        .lineLimit(2)

                    HStack(spacing: 8.scale) {
                        Text(project.statusTitle)
                            .font(Tokens.Font.semibold11)
                            .foregroundStyle(Tokens.Color.base44BrandOrange)
                            .padding(.horizontal, 9.scale)
                            .frame(height: 24.scale)
                            .background(Tokens.Color.base44BrandOrange.opacity(0.12))
                            .clipShape(Capsule())

                        Text(project.updatedAtLabel)
                            .font(Tokens.Font.regular13)
                            .foregroundStyle(Tokens.Color.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8.scale)

                Image(systemName: "chevron.right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 9.scale, height: 14.scale)
                    .foregroundStyle(Tokens.Color.inkPrimary30)
            }
            .padding(16.scale)
            .background(Tokens.Color.surfaceWhite.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 20.scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20.scale, style: .continuous)
                    .stroke(Tokens.Color.base44Border, lineWidth: 1.scale)
            }
        }
        .buttonStyle(.plain)
    }
}

struct Base44LogoMarkView: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Tokens.Color.base44BrandOrange, lineWidth: 2.2.scale)

            VStack(spacing: 2.4.scale) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule(style: .continuous)
                        .fill(Tokens.Color.base44BrandOrange)
                        .frame(width: 15.scale, height: 2.2.scale)
                }
            }
        }
    }
}

private extension SiteMakerProjectSummary {
    var statusTitle: String {
        switch status.lowercased() {
        case "live":
            return "Live"
        case "draft":
            return "Draft"
        case "error":
            return "Error"
        default:
            return status.capitalized
        }
    }

    var updatedAtLabel: String {
        guard let date = ISO8601DateFormatter.withFractionalSeconds.date(from: updatedAt) else {
            return "Recently updated"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
