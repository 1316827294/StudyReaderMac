import PDFKit
import SwiftUI

private struct PDFPageLayout {
    var page: PDFPage
    var pageIndex: Int
    var pageNumber: Int
    var frame: CGRect
    var pitchHeight: CGFloat
}

struct PDFReaderView: NSViewRepresentable {
    var url: URL?
    @Binding var syncFraction: Double
    @Binding var currentAnchor: PositionAnchor
    @Binding var answerScrollTarget: AnswerScrollTarget
    var onAnchorsChanged: ([PositionAnchor]) -> Void
    var onPageHeightsChanged: ([String: CGFloat]) -> Void
    var viewport: DocumentViewport

    func makeCoordinator() -> Coordinator {
        Coordinator(
            syncFraction: $syncFraction,
            currentAnchor: $currentAnchor,
            answerScrollTarget: $answerScrollTarget,
            onAnchorsChanged: onAnchorsChanged,
            onPageHeightsChanged: onPageHeightsChanged,
            viewport: viewport
        )
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = .textBackgroundColor
        context.coordinator.attach(to: pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.syncFraction = $syncFraction
        context.coordinator.currentAnchor = $currentAnchor
        context.coordinator.answerScrollTarget = $answerScrollTarget
        context.coordinator.onAnchorsChanged = onAnchorsChanged
        context.coordinator.onPageHeightsChanged = onPageHeightsChanged
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            pdfView.document = url.flatMap(PDFDocument.init(url:))
            context.coordinator.documentDidLoad()
        } else {
            context.coordinator.applyExternalAnswerTargetIfNeeded(answerScrollTarget)
        }
    }

    final class Coordinator: NSObject {
        var syncFraction: Binding<Double>
        var currentAnchor: Binding<PositionAnchor>
        var answerScrollTarget: Binding<AnswerScrollTarget>
        var onAnchorsChanged: ([PositionAnchor]) -> Void
        var onPageHeightsChanged: ([String: CGFloat]) -> Void
        var loadedURL: URL?
        private weak var pdfView: PDFView?
        private var isApplyingScroll = false
        private var suppressionGeneration = 0
        private var observer: NSObjectProtocol?
        private var lastAppliedExternalTarget: AnswerScrollTarget?
        private var lastReportedPageHeights: [String: CGFloat] = [:]
        private var pageLayoutCache: [PDFPageLayout] = []
        private var cachedDocumentViewSize: CGSize = .zero
        private var anchorBatchGeneration = 0
        private let viewport: DocumentViewport

        init(
            syncFraction: Binding<Double>,
            currentAnchor: Binding<PositionAnchor>,
            answerScrollTarget: Binding<AnswerScrollTarget>,
            onAnchorsChanged: @escaping ([PositionAnchor]) -> Void,
            onPageHeightsChanged: @escaping ([String: CGFloat]) -> Void,
            viewport: DocumentViewport
        ) {
            self.syncFraction = syncFraction
            self.currentAnchor = currentAnchor
            self.answerScrollTarget = answerScrollTarget
            self.onAnchorsChanged = onAnchorsChanged
            self.onPageHeightsChanged = onPageHeightsChanged
            self.viewport = viewport
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func attach(to pdfView: PDFView) {
            self.pdfView = pdfView
            attachScrollObserver()

            viewport.captureJPEG = { [weak self] in
                let coordinator = self
                return await MainActor.run {
                    coordinator?.captureVisibleJPEG()
                }
            }
            viewport.captureReadingText = { [weak self] in
                let coordinator = self

                // 1) Try native PDFKit text extraction first (works for text-based PDFs)
                if let nativeText = await MainActor.run(body: {
                    coordinator?.extractVisiblePagesText()
                }), !nativeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return nativeText
                }

                // 2) Fallback: capture screenshot and run OCR (for scanned / image-only PDFs)
                guard let imageData = await MainActor.run(body: {
                    coordinator?.captureVisibleJPEG()
                }) else {
                    return nil
                }
                return await OCRTextRecognizer.recognizeText(in: imageData)
            }
            viewport.scrollToFraction = { [weak self] fraction in
                self?.applyScrollFraction(fraction)
            }
        }

        func documentDidLoad() {
            attachScrollObserver()
            anchorBatchGeneration += 1
            pageLayoutCache.removeAll()
            cachedDocumentViewSize = .zero
            lastReportedPageHeights.removeAll()
            let pageCount = pdfView?.document?.pageCount ?? 0
            if pageCount > 0 {
                let restoredPage = max(1, min(pageCount, Int((syncFraction.wrappedValue * Double(pageCount)).rounded()) + 1))
                let initialPages = pageWindow(centeredAt: restoredPage, pageCount: pageCount, radius: 1)
                onAnchorsChanged(initialPages.map(PositionAnchor.pdfPage))
                scheduleAnchorBatches(pageCount: pageCount, generation: anchorBatchGeneration)
            }
            DispatchQueue.main.async { [weak self] in
                if let fraction = self?.syncFraction.wrappedValue, fraction > 0 {
                    self?.applyScrollFraction(fraction)
                }
                self?.reportPageHeightsIfNeeded()
                self?.scrollViewDidScroll()
            }
        }

        func applyScrollFraction(_ fraction: Double) {
            guard let scrollView = pdfView?.documentView?.enclosingScrollView,
                  let documentView = scrollView.documentView
            else { return }

            let targetY = SyncMapper.contentOffset(
                for: fraction,
                viewportHeight: scrollView.contentView.bounds.height,
                contentHeight: documentView.bounds.height
            )
            let currentY = scrollView.contentView.bounds.origin.y
            guard abs(currentY - targetY) > 2 else { return }

            suppressScrollReports()
            documentView.scroll(NSPoint(x: 0, y: targetY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            releaseScrollSuppressionSoon()
        }

        func applyExternalAnswerTargetIfNeeded(_ target: AnswerScrollTarget) {
            guard target.source == .answer || target.source == .restore,
                  target != lastAppliedExternalTarget
            else { return }

            lastAppliedExternalTarget = target
            applyScrollTarget(target, feedbackSuppressionDelay: target.source == .answer ? 1.0 : 0.12)
        }

        private func applyScrollTarget(_ target: AnswerScrollTarget, feedbackSuppressionDelay: TimeInterval = 0.12) {
            guard let pdfView,
                  let document = pdfView.document,
                  let pageNumber = pageNumber(from: target.anchor),
                  pageNumber >= 1,
                  pageNumber <= document.pageCount,
                  let page = document.page(at: pageNumber - 1),
                  let scrollView = pdfView.documentView?.enclosingScrollView,
                  let documentView = scrollView.documentView
            else { return }

            let fraction = SyncMapper.clamp(target.fractionWithinAnchor)
            let pageFrameInPDFView = pdfView.convert(page.bounds(for: pdfView.displayBox), from: page)
            let pageFrame = documentView.convert(pageFrameInPDFView, from: pdfView)
            let pageY = pageFrame.maxY - CGFloat(fraction) * pageFrame.height
            let targetY = max(0, pageY - scrollView.contentView.bounds.height * 0.35)
            let maxY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
            let clampedY = min(maxY, targetY)

            guard abs(scrollView.contentView.bounds.origin.y - clampedY) > 2 else { return }

            suppressScrollReports()
            documentView.scroll(NSPoint(x: 0, y: clampedY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            releaseScrollSuppressionSoon(after: feedbackSuppressionDelay)
        }

        private func scrollViewDidScroll() {
            guard !isApplyingScroll,
                  let scrollView = pdfView?.documentView?.enclosingScrollView,
                  let documentView = scrollView.documentView
            else { return }

            ensurePageLayoutCache()
            let fraction = SyncMapper.fraction(
                contentOffset: scrollView.contentView.bounds.origin.y,
                viewportHeight: scrollView.contentView.bounds.height,
                contentHeight: documentView.bounds.height
            )

            if abs(syncFraction.wrappedValue - fraction) > 0.002 {
                syncFraction.wrappedValue = fraction
            }

            if let pagePosition = dominantVisiblePagePosition(scrollView: scrollView, documentView: documentView) {
                let pageIndex = pagePosition.pageIndex
                let anchor = PositionAnchor.pdfPage(pageIndex + 1)
                if currentAnchor.wrappedValue != anchor {
                    currentAnchor.wrappedValue = anchor
                }
                let target = AnswerScrollTarget(anchor: anchor, fractionWithinAnchor: pagePosition.fractionWithinPage, source: .reader).clamped
                if answerScrollTarget.wrappedValue != target {
                    answerScrollTarget.wrappedValue = target
                }
            } else {
                let anchor = PositionAnchor.scrollBucket(fraction: fraction)
                if currentAnchor.wrappedValue != anchor {
                    currentAnchor.wrappedValue = anchor
                }
                let target = AnswerScrollTarget(anchor: anchor, fractionWithinAnchor: fraction, source: .reader).clamped
                if answerScrollTarget.wrappedValue != target {
                    answerScrollTarget.wrappedValue = target
                }
            }
        }

        private func reportPageHeightsIfNeeded() {
            ensurePageLayoutCache()
            let next = Dictionary(uniqueKeysWithValues: pageLayoutCache.map { layout in
                (PositionAnchor.pdfPage(layout.pageNumber).key, layout.pitchHeight)
            })

            guard pageHeightsChanged(next, comparedTo: lastReportedPageHeights) else { return }
            lastReportedPageHeights = next
            onPageHeightsChanged(next)
        }

        private func ensurePageLayoutCache() {
            guard let pdfView,
                  let document = pdfView.document,
                  let documentView = pdfView.documentView
            else { return }

            let size = documentView.bounds.size
            guard pageLayoutCache.isEmpty
                    || abs(cachedDocumentViewSize.width - size.width) > 1
                    || abs(cachedDocumentViewSize.height - size.height) > 1
            else { return }

            cachedDocumentViewSize = size
            var frames: [(page: PDFPage, index: Int, frame: CGRect)] = []
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let pageBounds = pdfView.convert(page.bounds(for: pdfView.displayBox), from: page)
                let frame = documentView.convert(pageBounds, from: pdfView)
                frames.append((page, index, frame))
            }

            pageLayoutCache = frames.enumerated().map { offset, item in
                let pitchHeight: CGFloat
                if offset + 1 < frames.count {
                    pitchHeight = max(1, abs(frames[offset + 1].frame.midY - item.frame.midY))
                } else if offset > 0 {
                    pitchHeight = max(1, abs(item.frame.midY - frames[offset - 1].frame.midY))
                } else {
                    pitchHeight = max(1, item.frame.height)
                }
                return PDFPageLayout(
                    page: item.page,
                    pageIndex: item.index,
                    pageNumber: item.index + 1,
                    frame: item.frame,
                    pitchHeight: pitchHeight
                )
            }.sorted { $0.frame.minY < $1.frame.minY }
        }

        private func pageHeightsChanged(_ lhs: [String: CGFloat], comparedTo rhs: [String: CGFloat]) -> Bool {
            guard lhs.count == rhs.count else { return true }
            for (key, value) in lhs {
                guard let oldValue = rhs[key], abs(oldValue - value) <= 1 else {
                    return true
                }
            }
            return false
        }

        private func attachScrollObserver() {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }

            guard let clipView = pdfView?.documentView?.enclosingScrollView?.contentView else { return }
            clipView.postsBoundsChangedNotifications = true
            observer = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                self?.scrollViewDidScroll()
            }
        }

        private func dominantVisiblePagePosition(scrollView: NSScrollView, documentView: NSView) -> (pageIndex: Int, fractionWithinPage: Double)? {
            guard let pdfView, let document = pdfView.document else { return nil }
            ensurePageLayoutCache()

            let visibleRect = scrollView.contentView.bounds
            var candidates: [PDFPageLayout] = []
            if let index = layoutIndex(containingY: visibleRect.midY) {
                let lower = max(0, index - 2)
                let upper = min(pageLayoutCache.count - 1, index + 2)
                candidates = Array(pageLayoutCache[lower...upper])
            } else {
                candidates = pageLayoutCache.filter { layout in
                    layout.frame.intersects(visibleRect)
                }
            }

            let best = candidates
                .map { layout in (layout: layout, intersection: visibleRect.intersection(layout.frame)) }
                .filter { !$0.intersection.isNull && $0.intersection.height > 0 }
                .max { $0.intersection.height < $1.intersection.height }?.layout

            if let best {
                let yInDocumentView = min(max(visibleRect.midY, best.frame.minY), best.frame.maxY)
                let pointInPDFView = pdfView.convert(NSPoint(x: visibleRect.midX, y: yInDocumentView), from: documentView)
                let centerOnPage = pdfView.convert(pointInPDFView, to: best.page)
                let pageBounds = best.page.bounds(for: pdfView.displayBox)
                let fractionFromTop = SyncMapper.clamp(Double((pageBounds.maxY - centerOnPage.y) / max(1, pageBounds.height)))
                return (best.pageIndex, fractionFromTop)
            }

            if let page = pdfView.currentPage {
                return (document.index(for: page), 0)
            }

            return nil
        }

        private func layoutIndex(containingY y: CGFloat) -> Int? {
            guard !pageLayoutCache.isEmpty else { return nil }
            var low = 0
            var high = pageLayoutCache.count - 1
            while low <= high {
                let mid = (low + high) / 2
                let frame = pageLayoutCache[mid].frame
                if y < frame.minY {
                    high = mid - 1
                } else if y > frame.maxY {
                    low = mid + 1
                } else {
                    return mid
                }
            }
            return min(max(0, low), pageLayoutCache.count - 1)
        }

        private func pageWindow(centeredAt pageNumber: Int, pageCount: Int, radius: Int) -> [Int] {
            let start = max(1, pageNumber - radius)
            let end = min(pageCount, pageNumber + radius)
            guard start <= end else { return [] }
            return Array(start...end)
        }

        private func scheduleAnchorBatches(pageCount: Int, generation: Int) {
            guard pageCount > 0 else { return }
            let batchSize = 50
            var nextEnd = 0

            func sendNextBatch() {
                guard generation == anchorBatchGeneration else { return }
                nextEnd = min(pageCount, nextEnd + batchSize)
                onAnchorsChanged((1...nextEnd).map(PositionAnchor.pdfPage))
                if nextEnd < pageCount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                        sendNextBatch()
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                sendNextBatch()
            }
        }

        private func pageNumber(from anchor: PositionAnchor) -> Int? {
            guard anchor.key.hasPrefix("pdf-page-") else { return nil }
            return Int(anchor.key.replacingOccurrences(of: "pdf-page-", with: ""))
        }

        private func suppressScrollReports() {
            suppressionGeneration += 1
            isApplyingScroll = true
        }

        private func releaseScrollSuppressionSoon(after delay: TimeInterval = 0.12) {
            let generation = suppressionGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.suppressionGeneration == generation else { return }
                self.isApplyingScroll = false
            }
        }

        /// Extracts text from the currently visible PDF pages using PDFKit's
        /// native text layer. This is more reliable than OCR for text-based PDFs
        /// and inherently supports all languages embedded in the PDF.
        private func extractVisiblePagesText() -> String? {
            guard let pdfView,
                  pdfView.document != nil,
                  let scrollView = pdfView.documentView?.enclosingScrollView,
                  let documentView = scrollView.documentView
            else { return nil }

            let visibleRect = scrollView.contentView.bounds
            guard visibleRect.width > 0, visibleRect.height > 0 else { return nil }

            ensurePageLayoutCache()

            // Collect text from every page whose frame intersects the visible rect.
            var parts: [String] = []
            for layout in pageLayoutCache {
                guard layout.frame.intersects(visibleRect) else { continue }
                let page = layout.page

                // Convert visible rect into page coordinate space and try
                // extracting only the text within the visible portion.
                let visibleInPDFView = pdfView.convert(visibleRect, from: documentView)
                let visibleOnPage = pdfView.convert(visibleInPDFView, to: page)
                let pageBounds = page.bounds(for: pdfView.displayBox)
                let clipped = visibleOnPage.intersection(pageBounds)

                if !clipped.isNull, clipped.width > 0, clipped.height > 0,
                   let selection = page.selection(for: clipped) {
                    if let text = selection.string,
                       !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        parts.append(text)
                        continue
                    }
                }

                // Fall back to the entire page string if selection-based
                // extraction returns nothing (can happen with some PDF encodings).
                if let fullText = page.string,
                   !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    parts.append(fullText)
                }
            }

            let result = parts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")

            return result.isEmpty ? nil : result
        }

        private func captureVisibleJPEG() -> Data? {
            guard let scrollView = pdfView?.documentView?.enclosingScrollView,
                  let documentView = scrollView.documentView
            else { return nil }

            let visibleRect = scrollView.contentView.bounds
            guard visibleRect.width > 0, visibleRect.height > 0,
                  let bitmap = documentView.bitmapImageRepForCachingDisplay(in: visibleRect)
            else { return nil }

            documentView.cacheDisplay(in: visibleRect, to: bitmap)
            let image = NSImage(size: visibleRect.size)
            image.addRepresentation(bitmap)
            return image.jpegData(compressionFactor: 0.82)
        }
    }
}
