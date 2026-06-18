import AppKit
import SwiftUI

struct SyncedAnswerSheetView: NSViewRepresentable {
    var blocks: [AnswerBlock]
    var feedbackByAnchor: [String: String]
    var feedbackAccentColor: NSColor
    var currentAnchor: PositionAnchor
    var scrollTarget: AnswerScrollTarget
    var pageHeights: [String: CGFloat]
    var onTextChanged: (PositionAnchor, String) -> Void
    var onScrollTargetChanged: (AnswerScrollTarget) -> Void
    var onSelectionCheckRequested: (PositionAnchor, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            feedbackByAnchor: feedbackByAnchor,
            feedbackAccentColor: feedbackAccentColor,
            onTextChanged: onTextChanged,
            onScrollTargetChanged: onScrollTargetChanged,
            onSelectionCheckRequested: onSelectionCheckRequested
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = AnswerScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let documentView = AnswerDocumentView(frame: .zero)
        documentView.autoresizingMask = [.width]
        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        scrollView.documentView = documentView

        context.coordinator.attach(scrollView: scrollView, documentView: documentView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onTextChanged = onTextChanged
        context.coordinator.onScrollTargetChanged = onScrollTargetChanged
        context.coordinator.onSelectionCheckRequested = onSelectionCheckRequested
        context.coordinator.feedbackByAnchor = feedbackByAnchor
        context.coordinator.feedbackAccentColor = feedbackAccentColor
        context.coordinator.beginUpdate(for: scrollTarget)
        context.coordinator.update(blocks: blocks, currentAnchor: currentAnchor, pageHeights: pageHeights)
        context.coordinator.applyScrollTarget(scrollTarget)
        context.coordinator.endUpdate(for: scrollTarget)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var feedbackByAnchor: [String: String]
        var feedbackAccentColor: NSColor
        var onTextChanged: (PositionAnchor, String) -> Void
        var onScrollTargetChanged: (AnswerScrollTarget) -> Void
        var onSelectionCheckRequested: (PositionAnchor, String) -> Void

        private weak var scrollView: NSScrollView?
        private weak var documentView: AnswerDocumentView?
        private var blockViews: [String: NSView] = [:]
        private var textViews: [String: PaperAnswerTextView] = [:]
        private var feedbackContainers: [String: NSView] = [:]
        private var feedbackTextViews: [String: NSTextView] = [:]
        private var selectionHintLabels: [ObjectIdentifier: NSTextField] = [:]
        private var anchorsByTextView: [ObjectIdentifier: PositionAnchor] = [:]
        private var heightConstraints: [ObjectIdentifier: NSLayoutConstraint] = [:]
        private var feedbackHeightConstraints: [String: NSLayoutConstraint] = [:]
        private var feedbackHeights: [String: CGFloat] = [:]
        private var orderedKeys: [String] = []
        private var allBlocks: [AnswerBlock] = []
        private var anchorIndexByKey: [String: Int] = [:]
        private var estimatedBlockHeights: [String: CGFloat] = [:]
        private var alignedBlockHeights: [String: CGFloat] = [:]
        private var scrollObserver: NSObjectProtocol?
        private let pageMinimumHeight: CGFloat = 620
        private let blockChromeHeight: CGFloat = 50
        private let renderRadius = 3
        private let syncReferenceRatio: CGFloat = 0.35
        private var isUpdatingText = false
        private var isApplyingScroll = false
        private var suppressionGeneration = 0
        private var ignoreReaderTargetsUntil: TimeInterval = 0

        init(
            feedbackByAnchor: [String: String],
            feedbackAccentColor: NSColor,
            onTextChanged: @escaping (PositionAnchor, String) -> Void,
            onScrollTargetChanged: @escaping (AnswerScrollTarget) -> Void,
            onSelectionCheckRequested: @escaping (PositionAnchor, String) -> Void
        ) {
            self.feedbackByAnchor = feedbackByAnchor
            self.feedbackAccentColor = feedbackAccentColor
            self.onTextChanged = onTextChanged
            self.onScrollTargetChanged = onScrollTargetChanged
            self.onSelectionCheckRequested = onSelectionCheckRequested
        }

        deinit {
            if let scrollObserver {
                NotificationCenter.default.removeObserver(scrollObserver)
            }
        }

        fileprivate func attach(scrollView: NSScrollView, documentView: AnswerDocumentView) {
            self.scrollView = scrollView
            self.documentView = documentView
            documentView.sheetScrollView = scrollView as? AnswerScrollView
            scrollView.contentView.postsBoundsChangedNotifications = true
            scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                self?.scrollViewDidScroll()
            }
        }

        func beginUpdate(for target: AnswerScrollTarget) {
            if scrollTargetShouldApply(target) {
                suppressScrollReports()
            }
        }

        func endUpdate(for target: AnswerScrollTarget) {
            if scrollTargetShouldApply(target) {
                releaseScrollSuppressionSoon()
            }
        }

        func update(blocks: [AnswerBlock], currentAnchor: PositionAnchor, pageHeights: [String: CGFloat]) {
            guard let documentView else { return }

            allBlocks = blocks
            alignedBlockHeights = pageHeights
            anchorIndexByKey = Dictionary(uniqueKeysWithValues: blocks.enumerated().map { ($0.element.anchor.key, $0.offset) })
            let displayBlocks = visibleBlocks(from: blocks, centeredOn: currentAnchor)
            let incomingKeys = displayBlocks.map { $0.anchor.key }
            if orderedKeys != incomingKeys {
                documentView.subviews.forEach { $0.removeFromSuperview() }
                blockViews.removeAll()
                textViews.removeAll()
                feedbackContainers.removeAll()
                feedbackTextViews.removeAll()
                selectionHintLabels.removeAll()
                anchorsByTextView.removeAll()
                heightConstraints.removeAll()
                feedbackHeightConstraints.removeAll()
                feedbackHeights.removeAll()
                orderedKeys = incomingKeys

                for block in displayBlocks {
                    let blockView = makeBlockView(for: block)
                    documentView.addSubview(blockView)
                    blockViews[block.anchor.key] = blockView
                }
            }

            isUpdatingText = true
            for block in displayBlocks {
                guard let textView = textViews[block.anchor.key] else { continue }
                if textView.string != block.text {
                    textView.string = block.text
                }
                updateFeedback(for: block.anchor)
                updateTextViewHeight(textView)
                updateBlockStyle(for: textView, isCurrent: block.anchor.key == currentAnchor.key)
            }
            isUpdatingText = false
            layoutDisplayedBlocks()
        }

        func applyScrollTarget(_ target: AnswerScrollTarget) {
            guard scrollTargetShouldApply(target),
                  let scrollView,
                  let documentView,
                  let targetView = textViews[target.anchor.key]?.superview
            else { return }

            layoutDisplayedBlocks()
            let viewportHeight = scrollView.contentView.bounds.height
            let maxDocumentOffset = max(0, documentView.bounds.height - viewportHeight)
            let anchorY = targetView.frame.minY + CGFloat(SyncMapper.clamp(target.fractionWithinAnchor)) * blockHeight(for: target.anchor.key)
            let rawTargetY = anchorY - viewportHeight * syncReferenceRatio
            let targetY = min(maxDocumentOffset, max(0, rawTargetY))
            let currentY = scrollView.contentView.bounds.origin.y
            guard abs(currentY - targetY) > 2 else { return }

            suppressScrollReports()
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            releaseScrollSuppressionSoon()
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingText,
                  let textView = notification.object as? NSTextView,
                  let anchor = anchorsByTextView[ObjectIdentifier(textView)]
            else { return }

            onTextChanged(anchor, textView.string)
            updateTextViewHeight(textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? PaperAnswerTextView else { return }
            updateSelectionHint(for: textView)
        }

        private func makeBlockView(for block: AnswerBlock) -> NSView {
            let container = NSView()
            container.wantsLayer = true
            container.layer?.cornerRadius = 0
            container.layer?.borderWidth = 0

            let label = NSTextField(labelWithString: block.anchor.label)
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false

            let selectionHint = NSTextField(labelWithString: "Right-click to Check Selection")
            selectionHint.font = .systemFont(ofSize: 12, weight: .semibold)
            selectionHint.textColor = .controlAccentColor
            selectionHint.alignment = .right
            selectionHint.isHidden = true
            selectionHint.translatesAutoresizingMaskIntoConstraints = false
            selectionHint.wantsLayer = true
            selectionHint.layer?.cornerRadius = 6
            selectionHint.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor

            let separator = NSView()
            separator.translatesAutoresizingMaskIntoConstraints = false
            separator.wantsLayer = true
            separator.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor

            let textView = PaperAnswerTextView()
            textView.sheetScrollView = scrollView as? AnswerScrollView
            textView.onCheckSelection = { [weak self, weak textView] selectedText in
                guard let self,
                      let textView,
                      let anchor = self.anchorsByTextView[ObjectIdentifier(textView)]
                else { return }
                self.onSelectionCheckRequested(anchor, selectedText)
            }
            textView.string = block.text
            textView.font = .systemFont(ofSize: 15)
            textView.isRichText = false
            textView.allowsUndo = true
            textView.importsGraphics = false
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isVerticallyResizable = true
            textView.isHorizontallyResizable = false
            textView.minSize = NSSize(width: 0, height: pageMinimumHeight)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.autoresizingMask = [.width]
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.heightTracksTextView = false
            textView.textContainerInset = NSSize(width: 34, height: 18)
            textView.backgroundColor = .clear
            textView.delegate = self
            textView.minimumPaperHeight = pageMinimumHeight
            textView.onSyntheticLineInserted = { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.onTextChanged(block.anchor, textView.string)
                self.updateTextViewHeight(textView)
            }
            textView.translatesAutoresizingMaskIntoConstraints = false
            textViews[block.anchor.key] = textView
            anchorsByTextView[ObjectIdentifier(textView)] = block.anchor
            selectionHintLabels[ObjectIdentifier(textView)] = selectionHint

            let feedbackContainer = NSView()
            feedbackContainer.translatesAutoresizingMaskIntoConstraints = false
            feedbackContainer.wantsLayer = true
            feedbackContainer.layer?.cornerRadius = 8
            feedbackContainer.layer?.borderWidth = 1

            let feedbackLabel = NSTextField(labelWithString: "AI Feedback")
            feedbackLabel.font = .systemFont(ofSize: 12, weight: .semibold)
            feedbackLabel.translatesAutoresizingMaskIntoConstraints = false

            let feedbackTextView = NSTextView()
            feedbackTextView.isEditable = false
            feedbackTextView.isSelectable = true
            feedbackTextView.drawsBackground = false
            feedbackTextView.textContainerInset = NSSize(width: 10, height: 8)
            feedbackTextView.textContainer?.widthTracksTextView = true
            feedbackTextView.textContainer?.heightTracksTextView = false
            feedbackTextView.isVerticallyResizable = true
            feedbackTextView.isHorizontallyResizable = false
            feedbackTextView.autoresizingMask = [.width]
            feedbackTextView.translatesAutoresizingMaskIntoConstraints = false

            feedbackContainer.addSubview(feedbackLabel)
            feedbackContainer.addSubview(feedbackTextView)
            feedbackContainers[block.anchor.key] = feedbackContainer
            feedbackTextViews[block.anchor.key] = feedbackTextView

            container.addSubview(label)
            container.addSubview(selectionHint)
            container.addSubview(separator)
            container.addSubview(textView)
            container.addSubview(feedbackContainer)

            let heightConstraint = textView.heightAnchor.constraint(equalToConstant: pageMinimumHeight)
            heightConstraint.priority = .defaultHigh
            heightConstraints[ObjectIdentifier(textView)] = heightConstraint
            let feedbackHeightConstraint = feedbackContainer.heightAnchor.constraint(equalToConstant: 0)
            feedbackHeightConstraints[block.anchor.key] = feedbackHeightConstraint

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(lessThanOrEqualTo: selectionHint.leadingAnchor, constant: -10),

                selectionHint.centerYAnchor.constraint(equalTo: label.centerYAnchor),
                selectionHint.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

                separator.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
                separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                separator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                separator.heightAnchor.constraint(equalToConstant: 1),

                textView.topAnchor.constraint(equalTo: separator.bottomAnchor),
                textView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                heightConstraint,

                feedbackContainer.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 0),
                feedbackContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 22),
                feedbackContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -22),
                feedbackContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
                feedbackHeightConstraint,

                feedbackLabel.topAnchor.constraint(equalTo: feedbackContainer.topAnchor, constant: 8),
                feedbackLabel.leadingAnchor.constraint(equalTo: feedbackContainer.leadingAnchor, constant: 12),
                feedbackLabel.trailingAnchor.constraint(equalTo: feedbackContainer.trailingAnchor, constant: -12),

                feedbackTextView.topAnchor.constraint(equalTo: feedbackLabel.bottomAnchor, constant: 2),
                feedbackTextView.leadingAnchor.constraint(equalTo: feedbackContainer.leadingAnchor, constant: 8),
                feedbackTextView.trailingAnchor.constraint(equalTo: feedbackContainer.trailingAnchor, constant: -8),
                feedbackTextView.bottomAnchor.constraint(equalTo: feedbackContainer.bottomAnchor, constant: -8)
            ])

            updateBlockStyle(for: textView, isCurrent: false)
            updateFeedback(for: block.anchor)
            updateTextViewHeight(textView)
            return container
        }

        private func updateSelectionHint(for textView: PaperAnswerTextView) {
            let hasSelection = !textView.checkableSelectedText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            selectionHintLabels[ObjectIdentifier(textView)]?.isHidden = !hasSelection
        }

        private func updateBlockStyle(for textView: NSTextView, isCurrent: Bool) {
            guard let container = textView.superview else { return }
            container.layer?.backgroundColor = isCurrent
                ? NSColor.controlAccentColor.withAlphaComponent(0.045).cgColor
                : NSColor.textBackgroundColor.cgColor
        }

        private func updateFeedback(for anchor: PositionAnchor) {
            let key = anchor.key
            guard let feedbackContainer = feedbackContainers[key],
                  let feedbackTextView = feedbackTextViews[key],
                  let heightConstraint = feedbackHeightConstraints[key]
            else { return }

            let feedback = feedbackByAnchor[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hasFeedback = !feedback.isEmpty
            feedbackContainer.isHidden = !hasFeedback
            feedbackContainer.layer?.backgroundColor = feedbackAccentColor.withAlphaComponent(0.06).cgColor
            feedbackContainer.layer?.borderColor = feedbackAccentColor.withAlphaComponent(0.45).cgColor

            if let label = feedbackContainer.subviews.compactMap({ $0 as? NSTextField }).first {
                label.textColor = feedbackAccentColor
            }

            if hasFeedback {
                feedbackTextView.textStorage?.setAttributedString(
                    attributedMarkdown(feedback, accentColor: feedbackAccentColor)
                )
            } else {
                feedbackTextView.string = ""
            }

            let targetHeight = hasFeedback ? feedbackHeight(for: feedbackTextView) : 0
            feedbackHeights[key] = targetHeight
            if abs(heightConstraint.constant - targetHeight) > 1 {
                heightConstraint.constant = targetHeight
            }
        }

        private func updateTextViewHeight(_ textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer,
                  let heightConstraint = heightConstraints[ObjectIdentifier(textView)]
            else { return }

            layoutManager.ensureLayout(for: textContainer)
            let viewportHeight = scrollView?.contentView.bounds.height ?? pageMinimumHeight
            let minimumVisiblePageHeight = max(pageMinimumHeight, viewportHeight + 12)
            let usedHeight = layoutManager.usedRect(for: textContainer).height
                + textView.textContainerInset.height * 2
                + 36
            let anchor = anchorsByTextView[ObjectIdentifier(textView)]
            let alignedBlockHeight = anchor.flatMap { alignedBlockHeights[$0.key] }
            let feedbackHeight = anchor.map { self.feedbackHeight(for: $0.key) } ?? 0
            let nextHeight = alignedBlockHeight.map { max(1, $0 - blockChromeHeight) }
                .map { max(120, $0 - feedbackHeight) }
                ?? max(minimumVisiblePageHeight, ceil(usedHeight))
            if abs(heightConstraint.constant - nextHeight) > 1 {
                heightConstraint.constant = nextHeight
                if let anchor {
                    estimatedBlockHeights[anchor.key] = alignedBlockHeight ?? (nextHeight + blockChromeHeight + feedbackHeight)
                }
                layoutDisplayedBlocks()
            } else if let anchor {
                estimatedBlockHeights[anchor.key] = alignedBlockHeight ?? (nextHeight + blockChromeHeight + feedbackHeight)
            }
        }

        private func feedbackHeight(for key: String) -> CGFloat {
            feedbackHeights[key] ?? 0
        }

        private func feedbackHeight(for textView: NSTextView) -> CGFloat {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else {
                return 0
            }
            let width = max(1, (scrollView?.contentView.bounds.width ?? 420) - 76)
            textContainer.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let usedHeight = layoutManager.usedRect(for: textContainer).height
                + textView.textContainerInset.height * 2
                + 34
            return min(360, max(82, ceil(usedHeight)))
        }

        private func attributedMarkdown(_ markdown: String, accentColor: NSColor) -> NSAttributedString {
            let attributed = (try? NSMutableAttributedString(
                markdown: markdown,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )) ?? NSMutableAttributedString(string: markdown)
            let fullRange = NSRange(location: 0, length: attributed.length)
            attributed.addAttributes([
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.labelColor
            ], range: fullRange)
            attributed.enumerateAttribute(.link, in: fullRange) { value, range, _ in
                if value != nil {
                    attributed.addAttribute(.foregroundColor, value: accentColor, range: range)
                    attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                }
            }
            return attributed
        }

        private func scrollTargetShouldApply(_ target: AnswerScrollTarget) -> Bool {
            if target.source == .restore {
                return true
            }
            if target.source == .reader {
                return Date.timeIntervalSinceReferenceDate >= ignoreReaderTargetsUntil
            }
            return false
        }

        private func markAnswerUserScroll() {
            ignoreReaderTargetsUntil = Date.timeIntervalSinceReferenceDate + 1.2
        }

        private func suppressScrollReports() {
            suppressionGeneration += 1
            isApplyingScroll = true
        }

        private func releaseScrollSuppressionSoon() {
            let generation = suppressionGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self, self.suppressionGeneration == generation else { return }
                self.isApplyingScroll = false
            }
        }

        private func layoutDisplayedBlocks() {
            guard let scrollView, let documentView else { return }

            let width = max(1, scrollView.contentView.bounds.width)
            for key in orderedKeys {
                guard let blockView = blockViews[key],
                      let index = anchorIndexByKey[key]
                else { continue }
                let height = blockHeight(for: key)
                let y = virtualY(forIndex: index)
                blockView.frame = CGRect(x: 0, y: y, width: width, height: height)
                blockView.layoutSubtreeIfNeeded()
            }

            let documentHeight = max(totalVirtualHeight(), scrollView.contentView.bounds.height)
            if abs(documentView.frame.width - width) > 1 || abs(documentView.frame.height - documentHeight) > 1 {
                documentView.setFrameSize(NSSize(width: width, height: documentHeight))
            }
        }

        private func visibleBlocks(from blocks: [AnswerBlock], centeredOn anchor: PositionAnchor) -> [AnswerBlock] {
            guard !blocks.isEmpty else { return [] }
            let centerIndex = blocks.firstIndex { $0.anchor.key == anchor.key }
                ?? nearestBlockIndex(for: anchor, in: blocks)
                ?? 0
            let lower = max(0, centerIndex - renderRadius)
            let upper = min(blocks.count - 1, centerIndex + renderRadius)
            return Array(blocks[lower...upper])
        }

        private func nearestBlockIndex(for anchor: PositionAnchor, in blocks: [AnswerBlock]) -> Int? {
            let target = anchorSortValue(anchor)
            return blocks.enumerated().min { lhs, rhs in
                abs(anchorSortValue(lhs.element.anchor) - target) < abs(anchorSortValue(rhs.element.anchor) - target)
            }?.offset
        }

        private func blockHeight(for key: String) -> CGFloat {
            guard let textView = textViews[key],
                  let heightConstraint = heightConstraints[ObjectIdentifier(textView)]
            else {
                return alignedBlockHeights[key] ?? estimatedBlockHeights[key] ?? defaultBlockHeight()
            }
            return alignedBlockHeights[key] ?? (heightConstraint.constant + blockChromeHeight + feedbackHeight(for: key))
        }

        private func defaultBlockHeight() -> CGFloat {
            let viewportHeight = scrollView?.contentView.bounds.height ?? pageMinimumHeight
            return max(pageMinimumHeight, viewportHeight + 12) + blockChromeHeight
        }

        private func virtualY(forIndex index: Int) -> CGFloat {
            guard index > 0 else { return 0 }
            return allBlocks.prefix(index).reduce(CGFloat(0)) { partial, block in
                partial + blockHeight(for: block.anchor.key)
            }
        }

        private func totalVirtualHeight() -> CGFloat {
            allBlocks.reduce(CGFloat(0)) { partial, block in
                partial + blockHeight(for: block.anchor.key)
            }
        }

        private func virtualPosition(at y: CGFloat) -> (anchor: PositionAnchor, frame: CGRect)? {
            var cursor: CGFloat = 0
            for block in allBlocks {
                let height = blockHeight(for: block.anchor.key)
                let frame = CGRect(x: 0, y: cursor, width: scrollView?.contentView.bounds.width ?? 1, height: height)
                if frame.minY <= y && y <= frame.maxY {
                    return (block.anchor, frame)
                }
                cursor += height
            }

            if let last = allBlocks.last {
                let height = blockHeight(for: last.anchor.key)
                return (last.anchor, CGRect(x: 0, y: max(0, cursor - height), width: scrollView?.contentView.bounds.width ?? 1, height: height))
            }
            return nil
        }

        private func anchorSortValue(_ anchor: PositionAnchor) -> Int {
            if anchor.key.hasPrefix("pdf-page-") {
                return Int(anchor.key.replacingOccurrences(of: "pdf-page-", with: "")) ?? 0
            }
            if anchor.key.hasPrefix("scroll-") {
                return Int(anchor.key.replacingOccurrences(of: "scroll-", with: "")) ?? 0
            }
            if anchor.key.hasPrefix("epub-chapter-") {
                return Int(anchor.key.replacingOccurrences(of: "epub-chapter-", with: "")) ?? 0
            }
            return 0
        }

        private func scrollViewDidScroll() {
            guard !isApplyingScroll,
                  let scrollView,
                  documentView != nil
            else { return }

            markAnswerUserScroll()
            layoutDisplayedBlocks()
            let visibleRect = scrollView.contentView.bounds
            let referenceY = visibleRect.minY + visibleRect.height * syncReferenceRatio
            var fallback: (anchor: PositionAnchor, frame: CGRect, intersectionHeight: CGFloat)?
            var lineMatch: (anchor: PositionAnchor, frame: CGRect)?

            for key in orderedKeys {
                guard let textView = textViews[key],
                      let container = textView.superview,
                      let anchor = anchorsByTextView[ObjectIdentifier(textView)]
                else { continue }

                let frame = container.frame
                if frame.minY <= referenceY && referenceY <= frame.maxY {
                    lineMatch = (anchor, frame)
                    break
                }

                let intersection = visibleRect.intersection(frame)
                guard !intersection.isNull, intersection.height > 0 else { continue }
                if fallback == nil || intersection.height > (fallback?.intersectionHeight ?? 0) {
                    fallback = (anchor, frame, intersection.height)
                }
            }

            let best: (anchor: PositionAnchor, frame: CGRect)
            if let lineMatch {
                best = lineMatch
            } else if let fallback {
                best = (fallback.anchor, fallback.frame)
            } else if let virtualMatch = virtualPosition(at: referenceY) {
                best = virtualMatch
            } else {
                return
            }

            let clampedReferenceY = min(max(referenceY, best.frame.minY), best.frame.maxY)
            let fraction = SyncMapper.clamp(Double((clampedReferenceY - best.frame.minY) / max(1, best.frame.height)))
            onScrollTargetChanged(AnswerScrollTarget(anchor: best.anchor, fractionWithinAnchor: fraction, source: .answer).clamped)
        }
    }
}

private final class PaperAnswerTextView: NSTextView {
    weak var sheetScrollView: AnswerScrollView?
    var minimumPaperHeight: CGFloat = 620
    var onSyntheticLineInserted: (() -> Void)?
    var onCheckSelection: ((String) -> Void)?

    override func mouseDown(with event: NSEvent) {
        insertBlankLinesIfNeeded(for: event)
        super.mouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        let selected = checkableSelectedText().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty else { return menu }

        if menu.items.first?.isSeparatorItem == false {
            menu.insertItem(.separator(), at: 0)
        }
        let item = NSMenuItem(title: "Check Selection", action: #selector(checkSelectionFromMenu(_:)), keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "checkmark.seal", accessibilityDescription: "Check Selection")
        item.attributedTitle = NSAttributedString(
            string: "Check Selection",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold),
                .foregroundColor: NSColor.controlAccentColor
            ]
        )
        item.target = self
        menu.insertItem(item, at: 0)
        return menu
    }

    @objc private func checkSelectionFromMenu(_ sender: NSMenuItem) {
        let selected = checkableSelectedText().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty else { return }
        onCheckSelection?(selected)
    }

    override func scrollWheel(with event: NSEvent) {
        if let scrollView = sheetScrollView {
            scrollView.scrollWheel(with: event)
        } else if let scrollView = enclosingScrollView as? AnswerScrollView {
            scrollView.scrollWheel(with: event)
        } else if let scrollView = enclosingScrollView {
            scrollView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    private func insertBlankLinesIfNeeded(for event: NSEvent) {
        guard let font,
              let window,
              let textStorage
        else { return }

        let localPoint = convert(event.locationInWindow, from: nil)
        let lineHeight = max(layoutManager?.defaultLineHeight(for: font) ?? font.boundingRectForFont.height, 16)
        let yInText = localPoint.y - textContainerInset.height
        guard yInText > 0 else { return }

        let requestedLine = max(0, Int(floor(yInText / lineHeight)))
        let existingLines = max(1, string.components(separatedBy: .newlines).count)
        guard requestedLine >= existingLines else { return }

        let newlinesToAppend = requestedLine - existingLines + 1
        let appendString = String(repeating: "\n", count: newlinesToAppend)
        let endRange = NSRange(location: (string as NSString).length, length: 0)

        shouldChangeText(in: endRange, replacementString: appendString)
        textStorage.append(NSAttributedString(string: appendString))
        didChangeText()
        setSelectedRange(NSRange(location: (string as NSString).length, length: 0))
        window.makeFirstResponder(self)
        onSyntheticLineInserted?()
    }

    fileprivate func checkableSelectedText() -> String {
        let selectedRanges = selectedRanges.map(\.rangeValue)
        guard !selectedRanges.isEmpty else { return "" }
        let nsString = string as NSString
        return selectedRanges
            .filter { $0.length > 0 && NSMaxRange($0) <= nsString.length }
            .map { nsString.substring(with: $0) }
            .joined(separator: "\n")
    }
}

private final class AnswerDocumentView: NSView {
    weak var sheetScrollView: AnswerScrollView?

    override var isFlipped: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        if let sheetScrollView {
            sheetScrollView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
}

private final class AnswerScrollView: NSScrollView {}
