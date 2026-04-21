import SwiftUI
import WebKit

struct SitePreviewWebView: UIViewRepresentable {
    let url: URL
    let reloadKey: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastURL != url {
            webView.load(URLRequest(url: url))
            context.coordinator.lastURL = url
            context.coordinator.lastReloadKey = reloadKey
            return
        }

        if context.coordinator.lastReloadKey != reloadKey {
            webView.reload()
            context.coordinator.lastReloadKey = reloadKey
        }
    }

    final class Coordinator {
        var lastURL: URL?
        var lastReloadKey: UUID?
    }
}
