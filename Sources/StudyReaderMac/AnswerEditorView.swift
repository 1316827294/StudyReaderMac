import AppKit
import SwiftUI

struct AnswerEditorView: NSViewRepresentable {
    @Binding var text: String
    var viewport: AnswerViewport

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, viewport: viewport)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let textView = NSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 15)
        textView.textContainerInset = NSSize(width: 18, height: 18)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        context.coordinator.attach(scrollView: scrollView, textView: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.updateTextIfNeeded(text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        private weak var scrollView: NSScrollView?
        private weak var textView: NSTextView?
        private let viewport: AnswerViewport

        init(text: Binding<String>, viewport: AnswerViewport) {
            self.text = text
            self.viewport = viewport
        }

        func attach(scrollView: NSScrollView, textView: NSTextView) {
            self.scrollView = scrollView
            self.textView = textView

            viewport.visibleText = { [weak self] in
                self?.textView?.string ?? ""
            }
        }

        func updateTextIfNeeded(_ newText: String) {
            guard textView?.string != newText else { return }
            textView?.string = newText
            textView?.scrollToBeginningOfDocument(nil)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text.wrappedValue = textView.string
        }
    }
}
