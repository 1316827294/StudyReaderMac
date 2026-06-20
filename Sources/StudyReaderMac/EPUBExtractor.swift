import Foundation

struct EPUBChapter {
    var href: String
    var html: String
}

struct PreparedEPUB {
    var chapters: [EPUBChapter]
    var baseURL: URL

    var chapterCount: Int { chapters.count }

    func htmlForChapter(at index: Int) -> String {
        let safeIndex = min(max(0, index), max(0, chapters.count - 1))
        let chapter = chapters[safeIndex]
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            :root { color-scheme: light dark; }
            body {
              margin: 0 auto;
              max-width: 820px;
              padding: 36px 48px 96px;
              font: -apple-system-body;
              line-height: 1.58;
              color: CanvasText;
              background: Canvas;
            }
            img, svg, video { max-width: 100%; height: auto; }
            p { margin: 0 0 0.9em; }
          </style>
        </head>
        <body>
        <section class="chapter" id="chapter-\(safeIndex)">
        \(chapter.html)
        </section>
        </body>
        </html>
        """
    }
}

enum EPUBExtractor {
    static func prepare(url: URL) throws -> PreparedEPUB {
        let workURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyReaderMac-EPUB-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workURL, withIntermediateDirectories: true)
        try unzip(epubURL: url, destinationURL: workURL)

        let containerURL = workURL.appendingPathComponent("META-INF/container.xml")
        let containerXML = try String(contentsOf: containerURL, encoding: .utf8)
        guard let opfPath = firstMatch(in: containerXML, pattern: #"full-path\s*=\s*"([^"]+)""#) else {
            throw StudyReaderError.epubExtractionFailed("Missing OPF rootfile.")
        }

        let opfURL = workURL.appendingPathComponent(opfPath)
        let opfDirectory = opfURL.deletingLastPathComponent()
        let opfData = try Data(contentsOf: opfURL)
        let parser = OPFParser()
        try parser.parse(data: opfData)

        let chapters = parser.spine.compactMap { idref -> EPUBChapter? in
            guard let item = parser.manifest[idref],
                  item.mediaType.contains("html") || item.href.hasSuffix(".xhtml") || item.href.hasSuffix(".html")
            else { return nil }

            let chapterURL = opfDirectory.appendingPathComponent(item.href).standardizedFileURL
            guard let raw = try? String(contentsOf: chapterURL, encoding: .utf8) else { return nil }
            let body = extractBody(from: raw) ?? raw
            let rewritten = rewriteRelativeLinks(in: body, chapterURL: chapterURL)
            return EPUBChapter(href: item.href, html: rewritten)
        }

        guard !chapters.isEmpty else {
            throw StudyReaderError.epubExtractionFailed("No readable XHTML spine chapters found.")
        }

        return PreparedEPUB(chapters: chapters, baseURL: workURL)
    }

    private static func unzip(epubURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-qq", epubURL.path, "-d", destinationURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw StudyReaderError.epubExtractionFailed("The EPUB archive could not be extracted.")
        }
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func extractBody(from html: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"<body[^>]*>([\s\S]*?)</body>"#,
            options: [.caseInsensitive]
        ),
        let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
        let range = Range(match.range(at: 1), in: html)
        else { return nil }
        return String(html[range])
    }

    private static func rewriteRelativeLinks(in html: String, chapterURL: URL) -> String {
        let directory = chapterURL.deletingLastPathComponent()
        var output = html
        for attribute in ["src", "href"] {
            guard let regex = try? NSRegularExpression(pattern: #"\#(attribute)\s*=\s*"([^":#][^"]*)""#, options: [.caseInsensitive]) else {
                continue
            }

            let original = output
            let matches = regex.matches(in: original, range: NSRange(original.startIndex..., in: original)).reversed()
            for match in matches {
                guard let valueRange = Range(match.range(at: 1), in: original),
                      let fullRange = Range(match.range(at: 0), in: original)
                else { continue }

                let value = String(original[valueRange])
                if value.hasPrefix("data:") || value.hasPrefix("/") {
                    continue
                }
                let fileURL = directory.appendingPathComponent(value).standardizedFileURL
                output.replaceSubrange(fullRange, with: #"\#(attribute)="\#(fileURL.absoluteString)""#)
            }
        }
        return output
    }
}

private struct OPFManifestItem {
    var href: String
    var mediaType: String
}

private final class OPFParser: NSObject, XMLParserDelegate {
    private(set) var manifest: [String: OPFManifestItem] = [:]
    private(set) var spine: [String] = []

    func parse(data: Data) throws {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw StudyReaderError.epubExtractionFailed(parser.parserError?.localizedDescription ?? "Invalid OPF file.")
        }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName.lowercased() {
        case "item":
            guard let id = attributeDict["id"], let href = attributeDict["href"] else { return }
            manifest[id] = OPFManifestItem(href: href, mediaType: attributeDict["media-type"] ?? "")
        case "itemref":
            guard let idref = attributeDict["idref"] else { return }
            spine.append(idref)
        default:
            break
        }
    }
}
