import SwiftUI
import WebKit

struct SitePreviewWebView: UIViewRepresentable {
    let url: URL
    let reloadKey: UUID
    var onLoadingChanged: ((Bool) -> Void)? = nil
    var onProgressChanged: ((Double) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onLoadingChanged: onLoadingChanged,
            onProgressChanged: onProgressChanged
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        context.coordinator.attachProgressObserver(to: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onLoadingChanged = onLoadingChanged
        context.coordinator.onProgressChanged = onProgressChanged

        if context.coordinator.lastURL != url {
            onLoadingChanged?(true)
            onProgressChanged?(0.02)
            webView.load(URLRequest(url: url))
            context.coordinator.lastURL = url
            context.coordinator.lastReloadKey = reloadKey
            return
        }

        if context.coordinator.lastReloadKey != reloadKey {
            onLoadingChanged?(true)
            onProgressChanged?(0.02)
            webView.reload()
            context.coordinator.lastReloadKey = reloadKey
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastURL: URL?
        var lastReloadKey: UUID?
        var onLoadingChanged: ((Bool) -> Void)?
        var onProgressChanged: ((Double) -> Void)?
        private var progressObservation: NSKeyValueObservation?

        init(
            onLoadingChanged: ((Bool) -> Void)?,
            onProgressChanged: ((Double) -> Void)?
        ) {
            self.onLoadingChanged = onLoadingChanged
            self.onProgressChanged = onProgressChanged
        }

        deinit {
            progressObservation?.invalidate()
        }

        func attachProgressObserver(to webView: WKWebView) {
            progressObservation?.invalidate()
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                let progress = min(max(webView.estimatedProgress, 0.0), 1.0)
                DispatchQueue.main.async {
                    self?.onProgressChanged?(progress)
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            onLoadingChanged?(true)
            onProgressChanged?(max(webView.estimatedProgress, 0.02))
        }

        func webView(
            _ webView: WKWebView,
            didCommit navigation: WKNavigation!
        ) {
            // Page content started rendering, but we keep the loading UI
            // until the page reaches full progress.
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            onProgressChanged?(1.0)
            onLoadingChanged?(false)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            onProgressChanged?(0.0)
            onLoadingChanged?(false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            onProgressChanged?(0.0)
            onLoadingChanged?(false)
        }
    }
}
