import SwiftUI
import WebKit

struct SitePreviewWebView: UIViewRepresentable {
    let url: URL
    let reloadKey: UUID
    var onLoadingChanged: ((Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadingChanged: onLoadingChanged)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onLoadingChanged = onLoadingChanged

        if context.coordinator.lastURL != url {
            onLoadingChanged?(true)
            webView.load(URLRequest(url: url))
            context.coordinator.lastURL = url
            context.coordinator.lastReloadKey = reloadKey
            return
        }

        if context.coordinator.lastReloadKey != reloadKey {
            onLoadingChanged?(true)
            webView.reload()
            context.coordinator.lastReloadKey = reloadKey
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastURL: URL?
        var lastReloadKey: UUID?
        var onLoadingChanged: ((Bool) -> Void)?

        init(onLoadingChanged: ((Bool) -> Void)?) {
            self.onLoadingChanged = onLoadingChanged
        }

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            onLoadingChanged?(true)
        }

        func webView(
            _ webView: WKWebView,
            didCommit navigation: WKNavigation!
        ) {
            // Page content started rendering, hide loading overlay.
            onLoadingChanged?(false)
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            onLoadingChanged?(false)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            onLoadingChanged?(false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            onLoadingChanged?(false)
        }
    }
}
