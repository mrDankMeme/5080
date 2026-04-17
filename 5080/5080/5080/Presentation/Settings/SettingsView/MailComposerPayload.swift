import MessageUI
import SwiftUI
import UIKit

struct MailComposerPayload: Identifiable, Sendable {
    let id = UUID()
    let to: String
    let subject: String
    let body: String
    let isHTML: Bool
    let fallbackMailToURL: URL?

    static func makeMailToURL(
        to: String,
        subject: String,
        body: String
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = to
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

struct MailComposerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let payload: MailComposerPayload

    func makeUIViewController(context: Context) -> UIViewController {
        if MFMailComposeViewController.canSendMail() {
            let viewController = MFMailComposeViewController()
            viewController.mailComposeDelegate = context.coordinator
            viewController.setToRecipients([payload.to])
            viewController.setSubject(payload.subject)
            viewController.setMessageBody(payload.body, isHTML: payload.isHTML)
            return viewController
        }

        let viewController = UIViewController()

        DispatchQueue.main.async {
            if let fallbackMailToURL = payload.fallbackMailToURL {
                UIApplication.shared.open(fallbackMailToURL)
            }
            dismiss()
        }

        return viewController
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) { }

    func makeCoordinator() -> Coordinator {
        Coordinator {
            dismiss()
        }
    }
}

extension MailComposerView {
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true) {
                self.onFinish()
            }
        }
    }
}
