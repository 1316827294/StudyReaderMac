import Foundation

final class SessionStore {
    private let directoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directoryURL = baseURL.appendingPathComponent("StudyReaderMac/Sessions", isDirectory: true)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load(for documentURL: URL) -> DocumentSession {
        let url = sessionURL(for: documentURL)
        guard let data = try? Data(contentsOf: url),
              let session = try? decoder.decode(DocumentSession.self, from: data)
        else {
            return DocumentSession(documentPath: documentURL.path)
        }
        return session
    }

    func save(_ session: DocumentSession) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(session)
        try data.write(to: sessionURL(forDocumentPath: session.documentPath), options: [.atomic])
    }

    private func sessionURL(for documentURL: URL) -> URL {
        sessionURL(forDocumentPath: documentURL.path)
    }

    private func sessionURL(forDocumentPath path: String) -> URL {
        let id = Data(path.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return directoryURL.appendingPathComponent(id).appendingPathExtension("json")
    }
}
