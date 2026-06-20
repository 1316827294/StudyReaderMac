import XCTest
@testable import StudyReaderMac

final class SessionStoreTests: XCTestCase {
    func testListsRecentBooksByLastOpenedAt() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SessionStore(directoryURL: directory)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        try store.save(DocumentSession(
            documentPath: "/tmp/older.pdf",
            documentKind: .pdf,
            lastOpenedAt: Date(timeIntervalSince1970: 100)
        ))
        try store.save(DocumentSession(
            documentPath: "/tmp/newer.epub",
            documentKind: .epub,
            lastOpenedAt: Date(timeIntervalSince1970: 200)
        ))

        let books = store.recentBooks()

        XCTAssertEqual(books.map(\.title), ["newer.epub", "older.pdf"])
        XCTAssertEqual(books.map(\.kind), [.epub, .pdf])
    }
}
