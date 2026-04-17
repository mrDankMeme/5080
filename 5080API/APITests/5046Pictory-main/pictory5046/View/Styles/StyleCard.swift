import Combine
import SwiftUI

struct StyleCard: View {
    var style: PhotoStyleItem
    var isSelected: Bool

    private var previewURL: String? {
        if let preview = style.preview, !preview.isEmpty {
            return preview
        }
        let item = style.templates.first(where: { $0.isEnabled != false }) ?? style.templates.first
        return item?.previewProduction ?? item?.preview
    }

    var body: some View {
        VStack(spacing: 8) {
            CachedAsyncImage(urlString: previewURL, contentMode: .fill)
                .frame(width: 92, height: 92)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(style.title ?? "")
                .font(.footnote)
                .foregroundStyle(isSelected ? Color.black : Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.tail)
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
                .frame(maxWidth: 92, alignment: .center)
        }
        .padding(.bottom, 10)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white, lineWidth: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.interpolatingSpring(duration: 0.2), value: isSelected)
    }
}

struct EmptyStyleCard: View {
    var isSelected: Bool

    var body: some View {
        Text("No style")
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(width: 92, height: 92)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
            }
            .overlay {
                if isSelected {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white, lineWidth: 2)

                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#FD76FF").opacity(0.6), lineWidth: 3)
                            .blur(radius: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.interpolatingSpring(duration: 0.2), value: isSelected)
    }
}
