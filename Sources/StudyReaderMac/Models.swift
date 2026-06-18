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
}

struct AnswerBlock: Identifiable, Equatable {
    var anchor: PositionAnchor
    var text: String

    var id: String { anchor.key }
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
    var answerText: String
    var answersByAnchor: [String: String]
    var lastReadingFraction: Double
    var history: [AnalysisRecord]

    init(
        documentPath: String,
        answerText: String = "",
        answersByAnchor: [String: String] = [:],
        lastReadingFraction: Double = 0,
        history: [AnalysisRecord] = []
    ) {
        self.documentPath = documentPath
        self.answerText = answerText
        self.answersByAnchor = answersByAnchor
        self.lastReadingFraction = SyncMapper.clamp(lastReadingFraction)
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
}

final class DocumentViewport {
    var captureJPEG: (() async -> Data?)?
    var scrollToFraction: ((Double) -> Void)?
}

final class AnswerViewport {
    var visibleText: (() -> String)?
}

enum StudyReaderError: LocalizedError {
    case unsupportedDocument
    case missingAPIKey
    case missingDocumentCapture
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
