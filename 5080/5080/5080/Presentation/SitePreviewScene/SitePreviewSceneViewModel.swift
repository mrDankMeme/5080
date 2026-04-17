import Combine
import Foundation
import UIKit

@MainActor
final class SitePreviewSceneViewModel: ObservableObject, Identifiable {
    let id: String
    let titleText: String
    let previewURL: URL
    let previewReloadKey = UUID()

    @Published private(set) var isCopyConfirmationVisible = false

    private var resetCopyStateTask: Task<Void, Never>?

    init(
        id: String,
        titleText: String,
        previewURL: URL
    ) {
        self.id = id
        self.titleText = titleText
        self.previewURL = previewURL
    }

    deinit {
        resetCopyStateTask?.cancel()
    }

    var badgeTitle: String {
        "Live website"
    }

    var captionText: String {
        "Open your published project inside the app and copy its web address anytime."
    }

    var domainText: String {
        let host = previewURL.host(percentEncoded: false)?.trimmed ?? ""
        return host.isEmpty ? "Published preview" : host
    }

    var addressText: String {
        previewURL.absoluteString
    }

    var copyButtonTitle: String {
        isCopyConfirmationVisible ? "Copied" : "Copy URL"
    }

    var copyButtonSystemImageName: String {
        isCopyConfirmationVisible ? "checkmark" : "link"
    }

    func copyAddress() {
        UIPasteboard.general.string = previewURL.absoluteString
        isCopyConfirmationVisible = true

        resetCopyStateTask?.cancel()
        resetCopyStateTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.isCopyConfirmationVisible = false
        }
    }
}
