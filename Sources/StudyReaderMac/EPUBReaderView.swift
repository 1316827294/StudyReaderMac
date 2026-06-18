import SwiftUI
import WebKit

struct EPUBReaderView: NSViewRepresentable {
    var url: URL?
    @Binding var syncFraction: Double
    @Binding var currentAnchor: PositionAnchor
    @Binding var answerScrollTarget: AnswerScrollTarget
    var onAnchorsChanged: ([PositionAnchor]) -> Void
    var viewport: DocumentViewport

    func makeCoordinator() -> Coordinator {
        Coordinator(
            syncFraction: $syncFraction,
            currentAnchor: $currentAnchor,
            answerScrollTarget: $answerScrollTarget,
            onAnchorsChanged: onAnchorsChanged,
            viewport: viewport
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "scroll")
        let script = WKUserScript(
            source: """
            (() => {
              let ticking = false;
              function report() {
                const root = document.documentElement;
                const scrollable = Math.max(1, root.scrollHeight - window.innerHeight);
                const fraction = Math.min(1, Math.max(0, window.scrollY / scrollable));
                window.webkit.messageHandlers.scroll.postMessage(fraction);
              }
              window.addEventListener('scroll', () => {
                if (!ticking) {
                  window.requestAnimationFrame(() => { ticking = false; report(); });
                  ticking = true;
                }
              }, { passive: true });
              window.addEventListener('load', report);
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.attach(to: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.syncFraction = $syncFraction
        context.coordinator.currentAnchor = $currentAnchor
        context.coordinator.answerScrollTarget = $answerScrollTarget
        context.coordinator.onAnchorsChanged = onAnchorsChanged
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            onAnchorsChanged(stride(from: 0, through: 100, by: 5).map { percent in
                PositionAnchor.scrollBucket(fraction: Double(percent) / 100.0)
            })
            if let url {
                do {
                    let prepared = try EPUBExtractor.prepare(url: url)
                    webView.loadHTMLString(prepared.html, baseURL: prepared.baseURL)
                } catch {
                    webView.loadHTMLString(errorHTML(error.localizedDescription), baseURL: nil)
                }
            }
        }
    }

    private func errorHTML(_ message: String) -> String {
        """
        <!doctype html>
        <html><body style="font: -apple-system-body; padding: 32px;">
        <h2>Could not open EPUB</h2>
        <p>\(message)</p>
        </body></html>
        """
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var syncFraction: Binding<Double>
        var currentAnchor: Binding<PositionAnchor>
        var answerScrollTarget: Binding<AnswerScrollTarget>
        var onAnchorsChanged: ([PositionAnchor]) -> Void
        var loadedURL: URL?
        private weak var webView: WKWebView?
        private var isApplyingScroll = false
        private let viewport: DocumentViewport

        init(
            syncFraction: Binding<Double>,
            currentAnchor: Binding<PositionAnchor>,
            answerScrollTarget: Binding<AnswerScrollTarget>,
            onAnchorsChanged: @escaping ([PositionAnchor]) -> Void,
            viewport: DocumentViewport
        ) {
            self.syncFraction = syncFraction
            self.currentAnchor = currentAnchor
            self.answerScrollTarget = answerScrollTarget
            self.onAnchorsChanged = onAnchorsChanged
            self.viewport = viewport
        }

        func attach(to webView: WKWebView) {
            self.webView = webView
            viewport.captureJPEG = { [weak self] in
                await self?.captureVisibleJPEG()
            }
            viewport.scrollToFraction = { [weak self] fraction in
                self?.applyScrollFraction(fraction)
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.applyScrollFraction(self.syncFraction.wrappedValue)
            }
        }

        nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "scroll" else { return }
            let fraction: Double?
            if let number = message.body as? NSNumber {
                fraction = number.doubleValue
            } else {
                fraction = message.body as? Double
            }

            guard let fraction else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.isApplyingScroll else { return }
                let clamped = SyncMapper.clamp(fraction)
                if abs(self.syncFraction.wrappedValue - clamped) > 0.002 {
                    self.syncFraction.wrappedValue = clamped
                }
                let anchor = PositionAnchor.scrollBucket(fraction: clamped)
                if self.currentAnchor.wrappedValue != anchor {
                    self.currentAnchor.wrappedValue = anchor
                }
                let target = AnswerScrollTarget(anchor: anchor, fractionWithinAnchor: 0)
                if self.answerScrollTarget.wrappedValue != target {
                    self.answerScrollTarget.wrappedValue = target
                }
            }
        }

        func applyScrollFraction(_ fraction: Double) {
            guard let webView else { return }
            isApplyingScroll = true
            let clamped = SyncMapper.clamp(fraction)
            webView.evaluateJavaScript("""
            (() => {
              const root = document.documentElement;
              const scrollable = Math.max(0, root.scrollHeight - window.innerHeight);
              window.scrollTo(0, \(clamped) * scrollable);
            })();
            """) { [weak self] _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self?.isApplyingScroll = false
                }
            }
        }

        private func captureVisibleJPEG() async -> Data? {
            guard let webView else { return nil }
            return await withCheckedContinuation { continuation in
                let configuration = WKSnapshotConfiguration()
                configuration.rect = webView.bounds
                webView.takeSnapshot(with: configuration) { image, _ in
                    continuation.resume(returning: image?.jpegData(compressionFactor: 0.82))
                }
            }
        }
    }
}
