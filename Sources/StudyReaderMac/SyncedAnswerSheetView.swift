import AppKit
import SwiftUI

struct SyncedAnswerSheetView: NSViewRepresentable {
    var blocks: [AnswerBlock]
    var feedbackByAnchor: [String: String]
    var selectionFeedbackByAnchor: [String: [SelectionFeedback]]
    var feedbackAccentColor: NSColor
    var currentAnchor: PositionAnchor
    var scrollTarget: AnswerScrollTarget
    var pageHeights: [String: CGFloat]
    var onTextChanged: (PositionAnchor, String) -> Void
    var onScrollTargetChanged: (AnswerScrollTarget) -> Void
    var onSelectionCheckRequested: (PositionAnchor, AnswerSelection) -> Void
    var onSelectionFeedbackCollapseChanged: (PositionAnchor, UUID, Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            feedbackByAnchor: feedbackByAnchor,
            selectionFeedbackByAnchor: selectionFeedbackByAnchor,
            feedbackAccentColor: feedbackAccentColor,
            onTextChanged: onTextChanged,
            onScrollTargetChanged: onScrollTargetChanged,
            onSelectionCheckRequested: onSelectionCheckRequested,
            onSelectionFeedbackCollapseChanged: onSelectionFeedbackCollapseChanged
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
        context.coordinator.onSelectionFeedbackCollapseChanged = onSelectionFeedbackCollapseChanged
        context.coordinator.feedbackByAnchor = feedbackByAnchor
        context.coordinator.selectionFeedbackByAnchor = selectionFeedbackByAnchor
        context.coordinator.feedbackAccentColor = feedbackAccentColor
        context.coordinator.beginUpdate(for: scrollTarget)
        context.coordinator.update(blocks: blocks, currentAnchor: currentAnchor, pageHeights: pageHeights)
        context.coordinator.applyScrollTarget(scrollTarget)
        context.coordinator.endUpdate(for: scrollTarget)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var feedbackByAnchor: [String: String]
        var selectionFeedbackByAnchor: [String: [SelectionFeedback]]
        var feedbackAccentColor: NSColor
        var onTextChanged: (PositionAnchor, String) -> Void
        var onScrollTargetChanged: (AnswerScrollTarget) -> Void
        var onSelectionCheckRequested: (PositionAnchor, AnswerSelection) -> Void
        var onSelectionFeedbackCollapseChanged: (PositionAnchor, UUID, Bool) -> Void

        private weak var scrollView: NSScrollView?
        private weak var documentView: AnswerDocumentView?
        private var blockViews: [String: NSView] = [:]
        private var textViews: [String: PaperAnswerTextView] = [:]
        private var feedbackContainers: [String: NSView] = [:]
        private var feedbackTextViews: [String: NSTextView] = [:]
        private var selectionFeedbackPanels: [String: [UUID: SelectionFeedbackPanelView]] = [:]
        private var selectionFeedbackHeights: [String: CGFloat] = [:]
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
        private var selectionFeedbackSignatures: [String: String] = [:]
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
            selectionFeedbackByAnchor: [String: [SelectionFeedback]],
            feedbackAccentColor: NSColor,
            onTextChanged: @escaping (PositionAnchor, String) -> Void,
            onScrollTargetChanged: @escaping (AnswerScrollTarget) -> Void,
            onSelectionCheckRequested: @escaping (PositionAnchor, AnswerSelection) -> Void,
            onSelectionFeedbackCollapseChanged: @escaping (PositionAnchor, UUID, Bool) -> Void
        ) {
            self.feedbackByAnchor = feedbackByAnchor
            self.selectionFeedbackByAnchor = selectionFeedbackByAnchor
            self.feedbackAccentColor = feedbackAccentColor
            self.onTextChanged = onTextChanged
            self.onScrollTargetChanged = onScrollTargetChanged
            self.onSelectionCheckRequested = onSelectionCheckRequested
            self.onSelectionFeedbackCollapseChanged = onSelectionFeedbackCollapseChanged
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
            guard documentView != nil else { return }

            allBlocks = blocks
            alignedBlockHeights = pageHeights
            anchorIndexByKey = Dictionary(uniqueKeysWithValues: blocks.enumerated().map { ($0.element.anchor.key, $0.offset) })
            let displayBlocks = ensureVisibleBlocks(centeredOn: currentAnchor)

            isUpdatingText = true
            for block in displayBlocks {
                guard let textView = textViews[block.anchor.key] else { continue }
                if textView.string != block.text {
                    textView.string = block.text
                }
                updateFeedback(for: block.anchor)
                updateSelectionFeedback(for: block.anchor, in: textView)
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
            if let paperTextView = textView as? PaperAnswerTextView {
                updateSelectionFeedback(for: anchor, in: paperTextView)
            }
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
            textView.onCheckSelection = { [weak self, weak textView] selection in
                guard let self,
                      let textView,
                      let anchor = self.anchorsByTextView[ObjectIdentifier(textView)]
                else { return }
                self.onSelectionCheckRequested(anchor, selection)
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

                feedbackContainer.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 8),
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

        @discardableResult
        private func ensureVisibleBlocks(centeredOn anchor: PositionAnchor) -> [AnswerBlock] {
            guard let documentView else { return [] }

            let displayBlocks = visibleBlocks(from: allBlocks, centeredOn: anchor)
            let incomingKeys = displayBlocks.map { $0.anchor.key }
            guard orderedKeys != incomingKeys else { return displayBlocks }

            documentView.subviews.forEach { $0.removeFromSuperview() }
            blockViews.removeAll()
            textViews.removeAll()
            feedbackContainers.removeAll()
            feedbackTextViews.removeAll()
            for panelsByID in selectionFeedbackPanels.values {
                panelsByID.values.forEach { $0.removeFromSuperview() }
            }
            selectionFeedbackPanels.removeAll()
            selectionFeedbackHeights.removeAll()
            selectionFeedbackSignatures.removeAll()
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

            return displayBlocks
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

        private func updateSelectionFeedback(for anchor: PositionAnchor, in textView: PaperAnswerTextView) {
            let key = anchor.key
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else { return }

            let items = (selectionFeedbackByAnchor[key] ?? [])
                .sorted {
                    if $0.rangeLocation == $1.rangeLocation {
                        return $0.createdAt < $1.createdAt
                    }
                    return $0.rangeLocation < $1.rangeLocation
                }
            let panelWidth = max(220, textView.bounds.width - 44)
            let textHash = textView.string.hashValue
            let signature = items
                .map { "\($0.id.uuidString):\($0.rangeLocation):\($0.rangeLength):\($0.isCollapsed):\($0.feedback.hashValue):\(Int(panelWidth)):\(textHash)" }
                .joined(separator: "|")

            if selectionFeedbackSignatures[key] == signature {
                return
            }
            selectionFeedbackSignatures[key] = signature

            selectionFeedbackPanels[key]?.values.forEach { $0.removeFromSuperview() }
            selectionFeedbackPanels[key] = [:]
            textContainer.exclusionPaths = []

            guard !items.isEmpty else {
                selectionFeedbackHeights[key] = 0
                return
            }

            let textWidth = max(1, textContainer.containerSize.width)
            var exclusionPaths: [NSBezierPath] = []
            var panelBottom: CGFloat = 0
            var occupiedBottom: CGFloat = 0
            var panelsByID: [UUID: SelectionFeedbackPanelView] = [:]

            layoutManager.ensureLayout(for: textContainer)
            for item in items {
                textContainer.exclusionPaths = exclusionPaths
                layoutManager.ensureLayout(for: textContainer)
                guard let range = SelectionFeedbackLocator.resolvedRange(for: item, in: textView.string),
                      let selectionRect = selectionAnchorRect(for: range, layoutManager: layoutManager, textContainer: textContainer)
                else { continue }

                let panelHeight = selectionFeedbackHeight(for: item, width: panelWidth)
                let requestedY = selectionRect.maxY + 8
                let panelY = max(requestedY, occupiedBottom + 8)
                let textOrigin = textContainerOrigin(for: textView)
                let panelFrame = NSRect(
                    x: max(0, (textView.bounds.width - panelWidth) / 2),
                    y: textOrigin.y + panelY,
                    width: panelWidth,
                    height: panelHeight
                )
                let exclusionRect = NSRect(
                    x: 0,
                    y: panelY - 2,
                    width: textWidth,
                    height: panelHeight + 12
                )
                let panel = SelectionFeedbackPanelView()
                panel.frame = panelFrame
                panel.autoresizingMask = [.width]
                panel.configure(
                    item: item,
                    anchorKey: key,
                    accentColor: feedbackAccentColor,
                    attributedFeedback: attributedMarkdown(item.feedback, accentColor: feedbackAccentColor)
                ) { [weak self] id, isCollapsed in
                    self?.onSelectionFeedbackCollapseChanged(anchor, id, isCollapsed)
                }
                textView.addSubview(panel)
                panelsByID[item.id] = panel
                exclusionPaths.append(NSBezierPath(rect: exclusionRect))
                occupiedBottom = exclusionRect.maxY
                panelBottom = max(panelBottom, panelFrame.maxY)
            }

            textContainer.exclusionPaths = exclusionPaths
            selectionFeedbackPanels[key] = panelsByID
            selectionFeedbackHeights[key] = panelBottom
            layoutManager.ensureLayout(for: textContainer)
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
            let selectionFeedbackHeight = anchor.map { self.selectionFeedbackHeight(for: $0.key) } ?? 0
            let contentHeight = ceil(max(usedHeight, selectionFeedbackHeight + 24))
            let nextHeight = alignedBlockHeight
                .map { max(max(120, $0 - blockChromeHeight - feedbackHeight), contentHeight) }
                ?? max(minimumVisiblePageHeight, contentHeight)
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

        private func selectionAnchorRect(for range: NSRange, layoutManager: NSLayoutManager, textContainer: NSTextContainer) -> NSRect? {
            guard range.location != NSNotFound, range.length > 0 else { return nil }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { return nil }
            let lastGlyphIndex = NSMaxRange(glyphRange) - 1
            return layoutManager.lineFragmentUsedRect(forGlyphAt: lastGlyphIndex, effectiveRange: nil)
        }

        private func textContainerOrigin(for textView: NSTextView) -> NSPoint {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else {
                return NSPoint(x: textView.textContainerInset.width, y: textView.textContainerInset.height)
            }

            let usedRect = layoutManager.usedRect(for: textContainer)
            let x = textView.textContainerInset.width
            let y = textView.textContainerInset.height - usedRect.minY
            return NSPoint(x: x, y: y)
        }

        private func feedbackHeight(for key: String) -> CGFloat {
            feedbackHeights[key] ?? 0
        }

        private func selectionFeedbackHeight(for key: String) -> CGFloat {
            selectionFeedbackHeights[key] ?? 0
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
            return max(82, ceil(usedHeight))
        }

        private func selectionFeedbackHeight(for item: SelectionFeedback, width: CGFloat) -> CGFloat {
            if item.isCollapsed {
                return 54
            }

            let attributed = attributedMarkdown(item.feedback, accentColor: feedbackAccentColor)
            let textStorage = NSTextStorage(attributedString: attributed)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(containerSize: NSSize(width: max(1, width - 24), height: .greatestFiniteMagnitude))
            textContainer.lineFragmentPadding = 0
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            layoutManager.ensureLayout(for: textContainer)
            let usedHeight = layoutManager.usedRect(for: textContainer).height
            return max(96, ceil(usedHeight) + 54)
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
            let measuredHeight = heightConstraint.constant
                + blockChromeHeight
                + feedbackHeight(for: key)
            if let alignedHeight = alignedBlockHeights[key] {
                return max(alignedHeight, measuredHeight)
            }
            return measuredHeight
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
                if !orderedKeys.contains(virtualMatch.anchor.key) {
                    ensureVisibleBlocks(centeredOn: virtualMatch.anchor)
                    layoutDisplayedBlocks()
                }
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
    var onCheckSelection: ((AnswerSelection) -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        guard let selection = checkableSelection(),
              !selection.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return menu }

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
        guard let selection = checkableSelection(),
              !selection.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        onCheckSelection?(selection)
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

    fileprivate func checkableSelectedText() -> String {
        checkableSelection()?.text ?? ""
    }

    private func checkableSelection() -> AnswerSelection? {
        let selectedRanges = selectedRanges.map(\.rangeValue)
        guard !selectedRanges.isEmpty else { return nil }
        let nsString = string as NSString
        guard let range = selectedRanges.first(where: { $0.length > 0 && NSMaxRange($0) <= nsString.length }) else {
            return nil
        }
        return AnswerSelection(
            text: nsString.substring(with: range),
            rangeLocation: range.location,
            rangeLength: range.length
        )
    }
}

private final class SelectionFeedbackPanelView: NSView {
    private let toggleButton = NSButton()
    private let titleLabel = NSTextField(labelWithString: "AI Feedback - Selection")
    private let excerptLabel = NSTextField(labelWithString: "")
    private let feedbackTextView = NSTextView()
    private var itemID: UUID?
    private var isCollapsed = false
    private var onToggle: ((UUID, Bool) -> Void)?

    var anchorKey = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1

        toggleButton.bezelStyle = .inline
        toggleButton.isBordered = false
        toggleButton.target = self
        toggleButton.action = #selector(toggleCollapsed)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        excerptLabel.font = .systemFont(ofSize: 11)
        excerptLabel.textColor = .secondaryLabelColor
        excerptLabel.lineBreakMode = .byTruncatingTail
        excerptLabel.maximumNumberOfLines = 1
        excerptLabel.translatesAutoresizingMaskIntoConstraints = false

        feedbackTextView.isEditable = false
        feedbackTextView.isSelectable = true
        feedbackTextView.drawsBackground = false
        feedbackTextView.textContainerInset = NSSize(width: 8, height: 6)
        feedbackTextView.textContainer?.widthTracksTextView = true
        feedbackTextView.textContainer?.heightTracksTextView = false
        feedbackTextView.isVerticallyResizable = true
        feedbackTextView.isHorizontallyResizable = false
        feedbackTextView.autoresizingMask = [.width]
        feedbackTextView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(toggleButton)
        addSubview(titleLabel)
        addSubview(excerptLabel)
        addSubview(feedbackTextView)

        NSLayoutConstraint.activate([
            toggleButton.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            toggleButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            toggleButton.widthAnchor.constraint(equalToConstant: 18),
            toggleButton.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.centerYAnchor.constraint(equalTo: toggleButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: toggleButton.trailingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),

            excerptLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            excerptLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            excerptLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            feedbackTextView.topAnchor.constraint(equalTo: excerptLabel.bottomAnchor, constant: 2),
            feedbackTextView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            feedbackTextView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            feedbackTextView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        item: SelectionFeedback,
        anchorKey: String,
        accentColor: NSColor,
        attributedFeedback: NSAttributedString,
        onToggle: @escaping (UUID, Bool) -> Void
    ) {
        self.itemID = item.id
        self.anchorKey = anchorKey
        self.isCollapsed = item.isCollapsed
        self.onToggle = onToggle

        layer?.backgroundColor = accentColor.withAlphaComponent(0.06).cgColor
        layer?.borderColor = accentColor.withAlphaComponent(0.45).cgColor
        titleLabel.textColor = accentColor
        toggleButton.contentTintColor = accentColor
        toggleButton.image = NSImage(
            systemSymbolName: item.isCollapsed ? "chevron.right" : "chevron.down",
            accessibilityDescription: item.isCollapsed ? "Expand feedback" : "Collapse feedback"
        )
        excerptLabel.stringValue = item.selectedText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        feedbackTextView.isHidden = item.isCollapsed
        feedbackTextView.textStorage?.setAttributedString(attributedFeedback)
    }

    @objc private func toggleCollapsed() {
        guard let itemID else { return }
        onToggle?(itemID, !isCollapsed)
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
