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
            context.coordinator.prepare(url: url)
        } else {
            context.coordinator.applyExternalAnswerTargetIfNeeded(answerScrollTarget)
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
        private var preparedEPUB: PreparedEPUB?
        private var currentChapterIndex = 0
        private var loadGeneration = 0
        private var pendingChapterScrollFraction: Double?
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
            viewport.captureReadingText = { [weak self] in
                await self?.captureVisibleText()
            }
            viewport.scrollToFraction = { [weak self] fraction in
                self?.applyScrollFraction(fraction)
            }
        }

        func prepare(url: URL?) {
            loadGeneration += 1
            let generation = loadGeneration
            preparedEPUB = nil
            currentChapterIndex = 0
            pendingChapterScrollFraction = nil

            guard let url else {
                webView?.loadHTMLString("", baseURL: nil)
                return
            }

            webView?.loadHTMLString(loadingHTML(), baseURL: nil)
            Task.detached(priority: .userInitiated) {
                let result = Result { try EPUBExtractor.prepare(url: url) }
                await MainActor.run { [weak self] in
                    guard let self, self.loadGeneration == generation else { return }
                    switch result {
                    case .success(let prepared):
                        self.preparedEPUB = prepared
                        self.onAnchorsChanged((1...prepared.chapterCount).map { chapterNumber in
                            PositionAnchor.epubChapter(chapterNumber)
                        })
                        self.loadChapter(forGlobalFraction: self.syncFraction.wrappedValue)
                    case .failure(let error):
                        self.webView?.loadHTMLString(self.errorHTML(error.localizedDescription), baseURL: nil)
                    }
                }
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let fraction = self.pendingChapterScrollFraction
                    ?? self.chapterFraction(forGlobalFraction: self.syncFraction.wrappedValue).fraction
                self.scrollCurrentChapter(to: fraction)
                self.pendingChapterScrollFraction = nil
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
                let chapterFraction = SyncMapper.clamp(fraction)
                let global = self.globalFraction(chapterIndex: self.currentChapterIndex, chapterFraction: chapterFraction)
                if abs(self.syncFraction.wrappedValue - global) > 0.002 {
                    self.syncFraction.wrappedValue = global
                }
                let anchor = PositionAnchor.epubChapter(self.currentChapterIndex + 1)
                if self.currentAnchor.wrappedValue != anchor {
                    self.currentAnchor.wrappedValue = anchor
                }
                let target = AnswerScrollTarget(anchor: anchor, fractionWithinAnchor: chapterFraction, source: .reader)
                if self.answerScrollTarget.wrappedValue != target {
                    self.answerScrollTarget.wrappedValue = target
                }
            }
        }

        func applyScrollFraction(_ fraction: Double) {
            loadChapter(forGlobalFraction: fraction)
        }

        func applyExternalAnswerTargetIfNeeded(_ target: AnswerScrollTarget) {
            guard target.source == .answer || target.source == .restore else { return }
            if let chapterNumber = chapterNumber(from: target.anchor) {
                loadChapter(index: chapterNumber - 1, scrollFraction: target.fractionWithinAnchor)
            } else {
                applyScrollFraction(target.fractionWithinAnchor)
            }
        }

        private func loadChapter(forGlobalFraction fraction: Double) {
            let target = chapterFraction(forGlobalFraction: fraction)
            loadChapter(index: target.index, scrollFraction: target.fraction)
        }

        private func loadChapter(index: Int, scrollFraction: Double) {
            guard let preparedEPUB, let webView else { return }
            let safeIndex = min(max(0, index), preparedEPUB.chapterCount - 1)
            let clampedFraction = SyncMapper.clamp(scrollFraction)
            pendingChapterScrollFraction = clampedFraction
            if safeIndex != currentChapterIndex || webView.url == nil {
                currentChapterIndex = safeIndex
                isApplyingScroll = true
                webView.loadHTMLString(preparedEPUB.htmlForChapter(at: safeIndex), baseURL: preparedEPUB.baseURL)
            } else {
                scrollCurrentChapter(to: clampedFraction)
            }
        }

        private func scrollCurrentChapter(to fraction: Double) {
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

        private func chapterFraction(forGlobalFraction fraction: Double) -> (index: Int, fraction: Double) {
            guard let preparedEPUB, preparedEPUB.chapterCount > 0 else {
                return (0, SyncMapper.clamp(fraction))
            }
            let scaled = SyncMapper.clamp(fraction) * Double(preparedEPUB.chapterCount)
            let index = min(preparedEPUB.chapterCount - 1, max(0, Int(floor(scaled))))
            return (index, scaled - Double(index))
        }

        private func globalFraction(chapterIndex: Int, chapterFraction: Double) -> Double {
            guard let preparedEPUB, preparedEPUB.chapterCount > 0 else {
                return SyncMapper.clamp(chapterFraction)
            }
            return SyncMapper.clamp((Double(chapterIndex) + SyncMapper.clamp(chapterFraction)) / Double(preparedEPUB.chapterCount))
        }

        private func chapterNumber(from anchor: PositionAnchor) -> Int? {
            guard anchor.key.hasPrefix("epub-chapter-") else { return nil }
            return Int(anchor.key.replacingOccurrences(of: "epub-chapter-", with: ""))
        }

        private func loadingHTML() -> String {
            """
            <!doctype html>
            <html><body style="font: -apple-system-body; padding: 32px;">
            <p>Loading EPUB...</p>
            </body></html>
            """
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

        private func captureVisibleText() async -> String? {
            guard let webView else { return nil }
            let script = """
            (() => {
              const range = document.caretRangeFromPoint
                ? document.caretRangeFromPoint(window.innerWidth / 2, window.innerHeight / 2)
                : null;
              const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
              const viewportTop = 0;
              const viewportBottom = window.innerHeight;
              const lines = [];
              while (walker.nextNode()) {
                const node = walker.currentNode;
                const value = (node.nodeValue || '').trim();
                if (!value) continue;
                const parent = node.parentElement;
                if (!parent) continue;
                const rect = parent.getBoundingClientRect();
                if (rect.bottom >= viewportTop && rect.top <= viewportBottom) {
                  lines.push(value);
                }
              }
              return lines.join('\\n');
            })();
            """

            let domText = await withCheckedContinuation { continuation in
                webView.evaluateJavaScript(script) { result, _ in
                    continuation.resume(returning: result as? String)
                }
            }?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let domText, !domText.isEmpty {
                return domText
            }

            guard let imageData = await captureVisibleJPEG() else { return nil }
            return await OCRTextRecognizer.recognizeText(in: imageData)
        }
    }
}
