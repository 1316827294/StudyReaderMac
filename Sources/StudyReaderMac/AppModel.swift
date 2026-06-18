import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var documentURL: URL?
    @Published var documentKind: DocumentKind?
    @Published var answerText = ""
    @Published var analysisText = ""
    @Published var currentAnchor = PositionAnchor.start
    @Published var answerBlocks: [AnswerBlock] = []
    @Published var restoredReadingFraction = 0.0
    @Published var statusText = "Open a PDF or DRM-free EPUB to begin."
    @Published var isChecking = false
    @Published var showingSettings = false
    @Published var modelName: String {
        didSet {
            UserDefaults.standard.set(modelName, forKey: "OpenAIModelName")
        }
    }
    @Published private(set) var history: [AnalysisRecord] = []

    let documentViewport = DocumentViewport()
    let answerViewport = AnswerViewport()

    private let sessionStore = SessionStore()
    private let keychain = KeychainStore.shared
    private let client = OpenAIClient()
    private var currentSession: DocumentSession?

    init() {
        modelName = UserDefaults.standard.string(forKey: "OpenAIModelName") ?? "gpt-5.5"
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .epub]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            loadDocument(url)
        }
    }

    func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                guard let url = Self.fileURL(from: item) else { return }
                let model = self
                Task {
                    await MainActor.run {
                        model?.loadDocument(url)
                    }
                }
            }
            return true
        }
        statusText = "Drop a PDF or DRM-free EPUB file."
        return false
    }

    func loadDocument(_ url: URL) {
        guard let kind = DocumentKind(url: url) else {
            statusText = StudyReaderError.unsupportedDocument.localizedDescription
            return
        }

        documentURL = url
        documentKind = kind
        let session = sessionStore.load(for: url)
        currentSession = session
        restoredReadingFraction = session.lastReadingFraction
        currentAnchor = PositionAnchor.scrollBucket(fraction: session.lastReadingFraction)
        answerText = session.answer(for: currentAnchor)
        answerBlocks = makeAnswerBlocks(from: session, preferredAnchors: [currentAnchor])
        history = session.history
        analysisText = session.history.last?.response ?? ""
        statusText = "Opened \(url.lastPathComponent)."
    }

    nonisolated private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data,
           let text = String(data: data, encoding: .utf8) {
            return URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let string = item as? String {
            return URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    func updateReadingPosition(fraction: Double, anchor: PositionAnchor) {
        guard documentURL != nil else { return }
        let normalizedAnchor = anchor == .start ? PositionAnchor.scrollBucket(fraction: fraction) : anchor
        if normalizedAnchor.key != currentAnchor.key {
            storeCurrentAnswerInMemory()
            currentAnchor = normalizedAnchor
            ensureAnswerBlockExists(for: normalizedAnchor)
            answerText = answer(for: normalizedAnchor)
            analysisText = currentSession?.history.last(where: { record in
                abs(record.readingFraction - SyncMapper.clamp(fraction)) < 0.005
            })?.response ?? ""
        }
        persistCurrentSession(readingFraction: fraction)
    }

    func persistCurrentSession(readingFraction: Double) {
        saveSession(readingFraction: readingFraction)
    }

    func updateAvailableAnchors(_ anchors: [PositionAnchor]) {
        guard !anchors.isEmpty else { return }
        let existingTexts = Dictionary(uniqueKeysWithValues: answerBlocks.map { ($0.anchor.key, $0.text) })
        let known = currentSession?.answersByAnchor ?? [:]
        let mergedAnchors: [PositionAnchor]
        var nextCurrentAnchor = currentAnchor
        if anchors.allSatisfy({ $0.key.hasPrefix("pdf-page-") }) {
            mergedAnchors = mergeAnchors(anchors)
            if !mergedAnchors.contains(where: { $0.key == nextCurrentAnchor.key }) {
                nextCurrentAnchor = mergedAnchors.first ?? .start
            }
        } else {
            mergedAnchors = mergeAnchors(anchors + answerBlocks.map(\.anchor))
        }
        answerBlocks = mergedAnchors.map { anchor in
            AnswerBlock(anchor: anchor, text: existingTexts[anchor.key] ?? known[anchor.key] ?? "")
        }
        if nextCurrentAnchor.key != currentAnchor.key {
            currentAnchor = nextCurrentAnchor
            answerText = answer(for: currentAnchor)
        }
        ensureAnswerBlockExists(for: currentAnchor)
    }

    func globalFraction(for target: AnswerScrollTarget) -> Double {
        guard let pageNumber = pageNumber(from: target.anchor),
              pageNumber > 0
        else {
            return target.fractionWithinAnchor
        }

        let pageCount = max(1, answerBlocks.filter { $0.anchor.key.hasPrefix("pdf-page-") }.count)
        return SyncMapper.clamp((Double(pageNumber - 1) + target.fractionWithinAnchor) / Double(pageCount))
    }

    func answer(for anchor: PositionAnchor) -> String {
        answerBlocks.first(where: { $0.anchor.key == anchor.key })?.text
            ?? currentSession?.answer(for: anchor)
            ?? ""
    }

    func setAnswer(_ text: String, for anchor: PositionAnchor, readingFraction: Double) {
        ensureAnswerBlockExists(for: anchor)
        if let index = answerBlocks.firstIndex(where: { $0.anchor.key == anchor.key }) {
            answerBlocks[index].text = text
        }
        if anchor.key == currentAnchor.key {
            answerText = text
        }
        saveSession(readingFraction: readingFraction)
    }

    private func saveSession(readingFraction: Double) {
        guard let documentURL else { return }
        var session = currentSession ?? DocumentSession(documentPath: documentURL.path)
        ensureAnswerBlockExists(for: currentAnchor)
        if let index = answerBlocks.firstIndex(where: { $0.anchor.key == currentAnchor.key }) {
            answerBlocks[index].text = answerText
        }
        for block in answerBlocks {
            session.setAnswer(block.text, for: block.anchor)
        }
        session.setAnswer(answerText, for: currentAnchor)
        session.answerText = answerText
        session.lastReadingFraction = SyncMapper.clamp(readingFraction)
        session.history = history
        currentSession = session
        try? sessionStore.save(session)
    }

    func apiKeyForSettings() -> String {
        keychain.readAPIKey() ?? ""
    }

    func saveAPIKey(_ apiKey: String) {
        do {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try keychain.deleteAPIKey()
                statusText = "API key removed."
            } else {
                try keychain.saveAPIKey(trimmed)
                statusText = "API key saved in Keychain."
            }
        } catch {
            statusText = "Could not update API key: \(error.localizedDescription)"
        }
    }

    func runCheck(readingFraction: Double) {
        guard !isChecking else { return }
        guard let documentURL else {
            statusText = "Open a document before checking."
            return
        }

        Task {
            await checkDocument(documentURL: documentURL, readingFraction: readingFraction)
        }
    }

    private func checkDocument(documentURL: URL, readingFraction: Double) async {
        isChecking = true
        statusText = "Capturing current reading view..."
        defer { isChecking = false }

        do {
            guard let apiKey = keychain.readAPIKey(), !apiKey.isEmpty else {
                throw StudyReaderError.missingAPIKey
            }

            let answer = answerText
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !answer.isEmpty else {
                throw StudyReaderError.emptyAnswer
            }

            guard let imageData = await documentViewport.captureJPEG?() else {
                throw StudyReaderError.missingDocumentCapture
            }

            statusText = "Sending screenshot and answer to OpenAI..."
            let editedAnswer = try await client.editAnswer(
                apiKey: apiKey,
                model: modelName,
                answerText: answer,
                readingImageJPEG: imageData,
                documentName: documentURL.lastPathComponent,
                readingFraction: readingFraction
            )

            setAnswer(editedAnswer, for: currentAnchor, readingFraction: readingFraction)
            analysisText = ""
            let record = AnalysisRecord(
                documentName: documentURL.lastPathComponent,
                readingFraction: readingFraction,
                answerExcerpt: String(answer.prefix(600)),
                response: editedAnswer
            )
            history.append(record)
            statusText = "Check complete. The current answer was edited."
        } catch {
            statusText = error.localizedDescription
        }
    }

    private func ensureAnswerBlockExists(for anchor: PositionAnchor) {
        guard !answerBlocks.contains(where: { $0.anchor.key == anchor.key }) else { return }
        let text = currentSession?.answer(for: anchor) ?? ""
        answerBlocks.append(AnswerBlock(anchor: anchor, text: text))
        answerBlocks = sortAnswerBlocks(answerBlocks)
    }

    private func storeCurrentAnswerInMemory() {
        ensureAnswerBlockExists(for: currentAnchor)
        if let index = answerBlocks.firstIndex(where: { $0.anchor.key == currentAnchor.key }) {
            answerBlocks[index].text = answerText
        }
    }

    private func makeAnswerBlocks(from session: DocumentSession, preferredAnchors: [PositionAnchor]) -> [AnswerBlock] {
        let savedAnchors = session.answersByAnchor.keys.map { key in
            PositionAnchor(key: key, label: label(forAnchorKey: key))
        }
        let anchors = mergeAnchors(preferredAnchors + savedAnchors)
        return anchors.map { AnswerBlock(anchor: $0, text: session.answer(for: $0)) }
    }

    private func mergeAnchors(_ anchors: [PositionAnchor]) -> [PositionAnchor] {
        var seen = Set<String>()
        let unique = anchors.filter { anchor in
            guard !seen.contains(anchor.key) else { return false }
            seen.insert(anchor.key)
            return true
        }
        return unique.sorted { anchorSortValue($0) < anchorSortValue($1) }
    }

    private func sortAnswerBlocks(_ blocks: [AnswerBlock]) -> [AnswerBlock] {
        blocks.sorted { anchorSortValue($0.anchor) < anchorSortValue($1.anchor) }
    }

    private func label(forAnchorKey key: String) -> String {
        if key.hasPrefix("pdf-page-"), let number = Int(key.replacingOccurrences(of: "pdf-page-", with: "")) {
            return "Page \(number)"
        }
        if key.hasPrefix("scroll-"), let number = Int(key.replacingOccurrences(of: "scroll-", with: "")) {
            return "Position \(number)%"
        }
        return key
    }

    private func anchorSortValue(_ anchor: PositionAnchor) -> Int {
        if anchor.key.hasPrefix("pdf-page-") {
            return Int(anchor.key.replacingOccurrences(of: "pdf-page-", with: "")) ?? 0
        }
        if anchor.key.hasPrefix("scroll-") {
            return Int(anchor.key.replacingOccurrences(of: "scroll-", with: "")) ?? 0
        }
        return 0
    }

    private func pageNumber(from anchor: PositionAnchor) -> Int? {
        guard anchor.key.hasPrefix("pdf-page-") else { return nil }
        return Int(anchor.key.replacingOccurrences(of: "pdf-page-", with: ""))
    }
}

private extension UTType {
    static let epub = UTType(filenameExtension: "epub")!
}
