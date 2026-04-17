import SwiftUI

struct PendingAttachmentsStripView: View {
    let attachments: [BuilderAttachmentDraft]
    let onRemove: (BuilderAttachmentDraft) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10.scale) {
                ForEach(attachments) { attachment in
                    attachmentChip(attachment)
                }
            }
            .padding(.horizontal, 1.scale)
        }
    }

    private func attachmentChip(_ attachment: BuilderAttachmentDraft) -> some View {
        HStack(spacing: 10.scale) {
            attachmentPreview(attachment)

            VStack(alignment: .leading, spacing: 2.scale) {
                Text(attachment.displayName)
                    .font(Tokens.Font.medium13)
                    .foregroundStyle(Tokens.Color.inkPrimary)
                    .lineLimit(1)

                Text(attachment.sizeLabel)
                    .font(Tokens.Font.regular12)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .lineLimit(1)
            }

            Button {
                onRemove(attachment)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18.scale, height: 18.scale)
                    .foregroundStyle(Tokens.Color.inkPrimary30)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8.scale)
        .padding(.horizontal, 10.scale)
        .background(Tokens.Color.surfaceWhite.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16.scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16.scale, style: .continuous)
                .stroke(Tokens.Color.base44Border, lineWidth: 1.scale)
        }
    }

    @ViewBuilder
    private func attachmentPreview(_ attachment: BuilderAttachmentDraft) -> some View {
        if let previewImage = attachment.previewImage {
            Image(uiImage: previewImage)
                .resizable()
                .scaledToFill()
                .frame(width: 36.scale, height: 36.scale)
                .clipShape(RoundedRectangle(cornerRadius: 10.scale, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10.scale, style: .continuous)
                .fill(Tokens.Color.base44SoftCard)
                .frame(width: 36.scale, height: 36.scale)
                .overlay {
                    Image(systemName: attachment.mimeType == "application/pdf" ? "doc.text.fill" : "paperclip")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16.scale, height: 16.scale)
                        .foregroundStyle(Tokens.Color.base44BrandOrange)
                }
        }
    }
}
