import UIKit

struct BuilderAttachmentDraft: Identifiable {
    static let maxUploadBytes = 10 * 1024 * 1024

    let id = UUID()
    let displayName: String
    let mimeType: String
    let data: Data
    let previewImage: UIImage?

    init(
        displayName: String,
        mimeType: String,
        data: Data
    ) {
        self.displayName = displayName
        self.mimeType = mimeType
        self.data = data

        if mimeType.hasPrefix("image/"), mimeType != "image/svg+xml" {
            self.previewImage = UIImage(data: data)
        } else {
            self.previewImage = nil
        }
    }

    var sizeLabel: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(data.count))
    }
}
