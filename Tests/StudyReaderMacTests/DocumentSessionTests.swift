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
}
