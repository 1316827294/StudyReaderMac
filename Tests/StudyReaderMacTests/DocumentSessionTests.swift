import XCTest
@testable import StudyReaderMac

final class DocumentSessionTests: XCTestCase {
    func testReturnsAnchorSpecificAnswer() {
        let session = DocumentSession(
            documentPath: "/tmp/book.pdf",
            answerText: "legacy",
            answersByAnchor: ["pdf-page-2": "page two"]
        )

        XCTAssertEqual(session.answer(for: .pdfPage(2)), "page two")
    }

    func testFallsBackToLegacyAnswerOnlyForStartAnchor() {
        let session = DocumentSession(documentPath: "/tmp/book.pdf", answerText: "legacy")

        XCTAssertEqual(session.answer(for: .start), "legacy")
        XCTAssertEqual(session.answer(for: .pdfPage(3)), "")
    }

    func testDecodesLegacySessionWithoutNewFields() throws {
        let data = """
        {
          "documentPath": "/tmp/book.pdf",
          "answerText": "legacy",
          "answersByAnchor": { "pdf-page-1": "page one" },
          "lastReadingFraction": 0.25,
          "history": []
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let session = try decoder.decode(DocumentSession.self, from: data)

        XCTAssertNil(session.documentKind)
        XCTAssertEqual(session.answer(for: .pdfPage(1)), "page one")
        XCTAssertEqual(session.feedbackByAnchor, [:])
        XCTAssertEqual(session.selectionFeedbackByAnchor, [:])
        XCTAssertEqual(session.lastReadingFraction, 0.25)
    }

    func testStoresFeedbackSeparatelyFromAnswer() {
        var session = DocumentSession(documentPath: "/tmp/book.pdf")

        session.setAnswer("my answer", for: .pdfPage(2))
        session.setFeedback("**feedback**", for: .pdfPage(2))

        XCTAssertEqual(session.answer(for: .pdfPage(2)), "my answer")
        XCTAssertEqual(session.feedback(for: .pdfPage(2)), "**feedback**")
    }

    func testAppendsSelectionFeedbackWithoutOverwritingExistingFeedback() {
        let appended = FeedbackFormatter.appendSelectionFeedback(
            existing: "existing feedback",
            selectedText: "selected\nanswer",
            feedback: "new feedback"
        )

        XCTAssertTrue(appended.contains("existing feedback"))
        XCTAssertTrue(appended.contains("### Selected text check"))
        XCTAssertTrue(appended.contains("> selected answer"))
        XCTAssertTrue(appended.contains("new feedback"))
    }

    func testStoresSelectionFeedbackByAnchor() {
        var session = DocumentSession(documentPath: "/tmp/book.pdf")
        let feedback = SelectionFeedback(
            anchorKey: PositionAnchor.pdfPage(2).key,
            selectedText: "selected answer",
            rangeLocation: 4,
            rangeLength: 15,
            feedback: "looks good"
        )

        session.addSelectionFeedback(feedback, for: .pdfPage(2))

        XCTAssertEqual(session.selectionFeedbackByAnchor[PositionAnchor.pdfPage(2).key], [feedback])
        XCTAssertEqual(session.answer(for: .pdfPage(2)), "")
    }

    func testSelectionFeedbackRangeUsesSavedRangeWhenStillValid() {
        let feedback = SelectionFeedback(
            anchorKey: "pdf-page-1",
            selectedText: "second",
            rangeLocation: 6,
            rangeLength: 6,
            feedback: "feedback"
        )

        let range = SelectionFeedbackLocator.resolvedRange(for: feedback, in: "first second second")

        XCTAssertEqual(range, NSRange(location: 6, length: 6))
    }

    func testSelectionFeedbackRangeFallsBackToSelectedTextSearch() {
        let feedback = SelectionFeedback(
            anchorKey: "pdf-page-1",
            selectedText: "second",
            rangeLocation: 0,
            rangeLength: 5,
            feedback: "feedback"
        )

        let range = SelectionFeedbackLocator.resolvedRange(for: feedback, in: "first second")

        XCTAssertEqual(range, NSRange(location: 6, length: 6))
    }

    func testSelectionFeedbackRangeReturnsNilWhenTextCannotBeFound() {
        let feedback = SelectionFeedback(
            anchorKey: "pdf-page-1",
            selectedText: "missing",
            rangeLocation: 0,
            rangeLength: 7,
            feedback: "feedback"
        )

        XCTAssertNil(SelectionFeedbackLocator.resolvedRange(for: feedback, in: "first second"))
    }
}
