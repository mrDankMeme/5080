import SwiftUI

struct TemplateCard: View {
    var effectWithTemplate: EffectWithTemplate

    private var previewURL: String? {
        effectWithTemplate.effect.preview ?? effectWithTemplate.template.preview
    }

    var body: some View {
        VStack(spacing: 8) {
            CachedAsyncImage(urlString: previewURL, contentMode: .fill)
                .frame(width: 167, height: 192)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.horizontal, 4)
                .padding(.top, 4)

            Text(effectWithTemplate.effect.title ?? "")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.bottom, 10)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "#252525").opacity(0.7))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
