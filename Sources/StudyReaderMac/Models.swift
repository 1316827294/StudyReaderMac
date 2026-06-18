import AppKit
import Foundation

enum DocumentKind: String, Codable {
    case pdf
    case epub

    init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "pdf":
            self = .pdf
        case "epub":
            self = .epub
        default:
            return nil
        }
    }
}

struct ReadingPosition: Codable, Equatable {
    var documentId: String
    var anchorId: String
    var fraction: Double

    var clamped: ReadingPosition {
        ReadingPosition(documentId: documentId, anchorId: anchorId, fraction: SyncMapper.clamp(fraction))
    }
}

struct PositionAnchor: Codable, Equatable {
    var key: String
    var label: String

    static let start = PositionAnchor(key: "start", label: "Start")

    static func pdfPage(_ pageNumber: Int) -> PositionAnchor {
        let safePage = max(1, pageNumber)
        return PositionAnchor(key: "pdf-page-\(safePage)", label: "Page \(safePage)")
    }

    static func scrollBucket(fraction: Double) -> PositionAnchor {
        let bucket = Int((SyncMapper.clamp(fraction) * 100).rounded())
        return PositionAnchor(key: "scroll-\(bucket)", label: "Position \(bucket)%")
    }

    static func epubChapter(_ chapterNumber: Int) -> PositionAnchor {
        let safeChapter = max(1, chapterNumber)
        return PositionAnchor(key: "epub-chapter-\(safeChapter)", label: "Chapter \(safeChapter)")
    }
}

struct AnswerBlock: Identifiable, Equatable {
    var anchor: PositionAnchor
    var text: String

    var id: String { anchor.key }
}

struct AnswerSelection: Codable, Equatable {
    var text: String
    var rangeLocation: Int
    var rangeLength: Int

    var range: NSRange {
        NSRange(location: rangeLocation, length: rangeLength)
    }
}

struct SelectionFeedback: Codable, Identifiable, Equatable {
    var id: UUID
    var anchorKey: String
    var selectedText: String
    var rangeLocation: Int
    var rangeLength: Int
    var feedback: String
    var createdAt: Date
    var isCollapsed: Bool

    init(
        id: UUID = UUID(),
        anchorKey: String,
        selectedText: String,
        rangeLocation: Int,
        rangeLength: Int,
        feedback: String,
        createdAt: Date = Date(),
        isCollapsed: Bool = false
    ) {
        self.id = id
        self.anchorKey = anchorKey
        self.selectedText = selectedText
        self.rangeLocation = rangeLocation
        self.rangeLength = rangeLength
        self.feedback = feedback
        self.createdAt = createdAt
        self.isCollapsed = isCollapsed
    }

    var selection: AnswerSelection {
        AnswerSelection(text: selectedText, rangeLocation: rangeLocation, rangeLength: rangeLength)
    }
}

enum SelectionFeedbackLocator {
    static func resolvedRange(for feedback: SelectionFeedback, in text: String) -> NSRange? {
        let nsText = text as NSString
        let savedRange = NSRange(location: feedback.rangeLocation, length: feedback.rangeLength)
        if savedRange.location >= 0,
           savedRange.length > 0,
           NSMaxRange(savedRange) <= nsText.length,
           nsText.substring(with: savedRange) == feedback.selectedText {
            return savedRange
        }

        let foundRange = nsText.range(of: feedback.selectedText)
        return foundRange.location == NSNotFound ? nil : foundRange
    }
}

struct AnswerScrollTarget: Equatable {
    var anchor: PositionAnchor
    var fractionWithinAnchor: Double
    var source: ScrollSyncSource = .reader

    static let start = AnswerScrollTarget(anchor: .start, fractionWithinAnchor: 0)

    var clamped: AnswerScrollTarget {
        AnswerScrollTarget(anchor: anchor, fractionWithinAnchor: SyncMapper.clamp(fractionWithinAnchor), source: source)
    }
}

enum ScrollSyncSource: Equatable {
    case reader
    case answer
    case restore
}

enum SyncMapper {
    static func clamp(_ fraction: Double) -> Double {
        guard fraction.isFinite else { return 0 }
        return min(1, max(0, fraction))
    }

    static func fraction(contentOffset: CGFloat, viewportHeight: CGFloat, contentHeight: CGFloat) -> Double {
        let scrollableHeight = max(0, contentHeight - viewportHeight)
        guard scrollableHeight > 0 else { return 0 }
        return clamp(Double(contentOffset / scrollableHeight))
    }

    static func contentOffset(for fraction: Double, viewportHeight: CGFloat, contentHeight: CGFloat) -> CGFloat {
        let scrollableHeight = max(0, contentHeight - viewportHeight)
        return CGFloat(clamp(fraction)) * scrollableHeight
    }
}

struct AnalysisRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var createdAt: Date
    var documentName: String
    var readingFraction: Double
    var answerExcerpt: String
    var response: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        documentName: String,
        readingFraction: Double,
        answerExcerpt: String,
        response: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.documentName = documentName
        self.readingFraction = SyncMapper.clamp(readingFraction)
        self.answerExcerpt = answerExcerpt
        self.response = response
    }
}

struct DocumentSession: Codable, Equatable {
    var documentPath: String
    var documentKind: DocumentKind?
    var answerText: String
    var answersByAnchor: [String: String]
    var feedbackByAnchor: [String: String]
    var selectionFeedbackByAnchor: [String: [SelectionFeedback]]
    var lastReadingFraction: Double
    var lastOpenedAt: Date
    var history: [AnalysisRecord]

    init(
        documentPath: String,
        documentKind: DocumentKind? = nil,
        answerText: String = "",
        answersByAnchor: [String: String] = [:],
        feedbackByAnchor: [String: String] = [:],
        selectionFeedbackByAnchor: [String: [SelectionFeedback]] = [:],
        lastReadingFraction: Double = 0,
        lastOpenedAt: Date = Date(),
        history: [AnalysisRecord] = []
    ) {
        self.documentPath = documentPath
        self.documentKind = documentKind
        self.answerText = answerText
        self.answersByAnchor = answersByAnchor
        self.feedbackByAnchor = feedbackByAnchor
        self.selectionFeedbackByAnchor = selectionFeedbackByAnchor
        self.lastReadingFraction = SyncMapper.clamp(lastReadingFraction)
        self.lastOpenedAt = lastOpenedAt
        self.history = history
    }

    func answer(for anchor: PositionAnchor) -> String {
        answersByAnchor[anchor.key] ?? (anchor.key == PositionAnchor.start.key ? answerText : "")
    }

    mutating func setAnswer(_ answer: String, for anchor: PositionAnchor) {
        answersByAnchor[anchor.key] = answer
        if anchor == .start {
            answerText = answer
        }
    }

    func feedback(for anchor: PositionAnchor) -> String {
        feedbackByAnchor[anchor.key] ?? ""
    }

    mutating func setFeedback(_ feedback: String, for anchor: PositionAnchor) {
        feedbackByAnchor[anchor.key] = feedback
    }

    mutating func addSelectionFeedback(_ feedback: SelectionFeedback, for anchor: PositionAnchor) {
        var items = selectionFeedbackByAnchor[anchor.key] ?? []
        items.append(feedback)
        selectionFeedbackByAnchor[anchor.key] = items
    }

    private enum CodingKeys: String, CodingKey {
        case documentPath
        case documentKind
        case answerText
        case answersByAnchor
        case feedbackByAnchor
        case selectionFeedbackByAnchor
        case lastReadingFraction
        case lastOpenedAt
        case history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        documentPath = try container.decode(String.self, forKey: .documentPath)
        documentKind = try container.decodeIfPresent(DocumentKind.self, forKey: .documentKind)
        answerText = try container.decodeIfPresent(String.self, forKey: .answerText) ?? ""
        answersByAnchor = try container.decodeIfPresent([String: String].self, forKey: .answersByAnchor) ?? [:]
        feedbackByAnchor = try container.decodeIfPresent([String: String].self, forKey: .feedbackByAnchor) ?? [:]
        selectionFeedbackByAnchor = try container.decodeIfPresent(
            [String: [SelectionFeedback]].self,
            forKey: .selectionFeedbackByAnchor
        ) ?? [:]
        lastReadingFraction = SyncMapper.clamp(
            try container.decodeIfPresent(Double.self, forKey: .lastReadingFraction) ?? 0
        )
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt) ?? Date.distantPast
        history = try container.decodeIfPresent([AnalysisRecord].self, forKey: .history) ?? []
    }
}

struct RecentBook: Identifiable, Equatable {
    var session: DocumentSession

    var id: String { session.documentPath }
    var url: URL { URL(fileURLWithPath: session.documentPath) }
    var title: String { url.lastPathComponent }
    var kind: DocumentKind? { session.documentKind ?? DocumentKind(url: url) }
    var lastOpenedAt: Date { session.lastOpenedAt }
    var readingFraction: Double { session.lastReadingFraction }
    var isAvailable: Bool { FileManager.default.fileExists(atPath: session.documentPath) }
}

enum FeedbackFormatter {
    static func appendSelectionFeedback(existing: String, selectedText: String, feedback: String) -> String {
        let excerpt = selectedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let safeExcerpt = String(excerpt.prefix(180))
        let block = """
        ### Selected text check
        > \(safeExcerpt)

        \(feedback.trimmingCharacters(in: .whitespacesAndNewlines))
        """

        let trimmedExisting = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedExisting.isEmpty {
            return block
        }
        return """
        \(trimmedExisting)

        ---

        \(block)
        """
    }
}

final class DocumentViewport {
    var captureJPEG: (() async -> Data?)?
    var captureReadingText: (() async -> String?)?
    var scrollToFraction: ((Double) -> Void)?
}

final class AnswerViewport {
    var visibleText: (() -> String)?
}

enum StudyReaderError: LocalizedError {
    case unsupportedDocument
    case missingAPIKey
    case missingDocumentCapture
    case missingRecognizedText
    case emptyAnswer
    case epubExtractionFailed(String)
    case openAIResponseMissingText
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocument:
            "Only PDF and DRM-free EPUB files are supported."
        case .missingAPIKey:
            "Add your OpenAI API key in Settings first."
        case .missingDocumentCapture:
            "Could not capture the current reading view."
        case .missingRecognizedText:
            "Could not recognize readable text from the current view."
        case .emptyAnswer:
            "Write an answer before checking."
        case .epubExtractionFailed(let message):
            "Could not open this EPUB: \(message)"
        case .openAIResponseMissingText:
            "OpenAI returned a response without readable text."
        case .serverError(let message):
            message
        }
    }
}

extension NSColor {
    convenience init?(studyReaderHex hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#").union(.whitespacesAndNewlines))
        guard value.count == 6,
              let raw = Int(value, radix: 16)
        else {
            return nil
        }

        self.init(
            red: CGFloat((raw >> 16) & 0xff) / 255.0,
            green: CGFloat((raw >> 8) & 0xff) / 255.0,
            blue: CGFloat(raw & 0xff) / 255.0,
            alpha: 1
        )
    }

    var studyReaderHexRGB: String? {
        guard let color = usingColorSpace(.sRGB) else { return nil }
        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
