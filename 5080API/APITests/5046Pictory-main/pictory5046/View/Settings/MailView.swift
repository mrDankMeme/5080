import MessageUI
import SwiftUI

struct MailView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss

    let subject: String
    let body: String
    let toRecipients: [String]

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView

        init(_ parent: MailView) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
            parent.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator

        vc.setSubject(subject)
        vc.setToRecipients(toRecipients)
        vc.setMessageBody(body, isHTML: false)

        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}
