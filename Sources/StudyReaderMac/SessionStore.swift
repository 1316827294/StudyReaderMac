import Foundation

final class SessionStore {
    private let directoryURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
        self.fileManager = fileManager
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.directoryURL = baseURL.appendingPathComponent("StudyReaderMac/Sessions", isDirectory: true)
        }
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
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(session)
        try data.write(to: sessionURL(forDocumentPath: session.documentPath), options: [.atomic])
    }

    func recentBooks(limit: Int = 12) -> [RecentBook] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> RecentBook? in
                guard let data = try? Data(contentsOf: url),
                      let session = try? decoder.decode(DocumentSession.self, from: data)
                else {
                    return nil
                }
                return RecentBook(session: session)
            }
            .sorted {
                if $0.lastOpenedAt == $1.lastOpenedAt {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.lastOpenedAt > $1.lastOpenedAt
            }
            .prefix(limit)
            .map { $0 }
    }

    func deleteSession(for documentPath: String) throws {
        let url = sessionURL(forDocumentPath: documentPath)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
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
