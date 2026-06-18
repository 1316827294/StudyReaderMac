import PDFKit
import SwiftUI

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
            viewport.scrollToFraction = { [weak self] fraction in
                self?.applyScrollFraction(fraction)
            }
        }

        func documentDidLoad() {
            attachScrollObserver()
            let pageCount = pdfView?.document?.pageCount ?? 0
            if pageCount > 0 {
                onAnchorsChanged((1...pageCount).map(PositionAnchor.pdfPage))
            }
            DispatchQueue.main.async { [weak self] in
                self?.reportPageHeightsIfNeeded()
                if let fraction = self?.syncFraction.wrappedValue, fraction > 0 {
                    self?.applyScrollFraction(fraction)
                }
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

            reportPageHeightsIfNeeded()
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
            guard let pdfView,
                  let document = pdfView.document,
                  let documentView = pdfView.documentView
            else { return }

            var topReferences: [CGFloat] = []
            var frameHeights: [CGFloat] = []
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let pageBounds = pdfView.convert(page.bounds(for: pdfView.displayBox), from: page)
                let frame = documentView.convert(pageBounds, from: pdfView)
                topReferences.append(frame.maxY)
                frameHeights.append(frame.height)
            }

            guard !topReferences.isEmpty else { return }

            var next: [String: CGFloat] = [:]
            for index in topReferences.indices {
                let height: CGFloat
                if index + 1 < topReferences.count {
                    height = max(1, abs(topReferences[index + 1] - topReferences[index]))
                } else if index > 0 {
                    height = max(1, abs(topReferences[index] - topReferences[index - 1]))
                } else {
                    height = max(1, frameHeights[index])
                }
                next[PositionAnchor.pdfPage(index + 1).key] = height
            }

            guard pageHeightsChanged(next, comparedTo: lastReportedPageHeights) else { return }
            lastReportedPageHeights = next
            onPageHeightsChanged(next)
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

            let visibleRect = scrollView.contentView.bounds
            var best: (page: PDFPage, index: Int, intersectionHeight: CGFloat)?

            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let pageBounds = pdfView.convert(page.bounds(for: pdfView.displayBox), from: page)
                let pageBoundsInDocumentView = documentView.convert(pageBounds, from: pdfView)
                let intersection = visibleRect.intersection(pageBoundsInDocumentView)
                guard !intersection.isNull, intersection.height > 0 else { continue }

                if best == nil || intersection.height > (best?.intersectionHeight ?? 0) {
                    best = (page, index, intersection.height)
                }
            }

            if let best {
                let yInDocumentView = min(max(visibleRect.midY, documentView.convert(pdfView.convert(best.page.bounds(for: pdfView.displayBox), from: best.page), from: pdfView).minY), documentView.convert(pdfView.convert(best.page.bounds(for: pdfView.displayBox), from: best.page), from: pdfView).maxY)
                let pointInPDFView = pdfView.convert(NSPoint(x: visibleRect.midX, y: yInDocumentView), from: documentView)
                let centerOnPage = pdfView.convert(pointInPDFView, to: best.page)
                let pageBounds = best.page.bounds(for: pdfView.displayBox)
                let fractionFromTop = SyncMapper.clamp(Double((pageBounds.maxY - centerOnPage.y) / max(1, pageBounds.height)))
                return (best.index, fractionFromTop)
            }

            if let page = pdfView.currentPage {
                return (document.index(for: page), 0)
            }

            return nil
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
