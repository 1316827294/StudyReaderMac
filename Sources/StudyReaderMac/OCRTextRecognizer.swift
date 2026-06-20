import Foundation
import Vision

enum OCRTextRecognizer {
    static func recognizeText(in imageData: Data) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, _ in
                    let lines = (request.results as? [VNRecognizedTextObservation])?
                        .compactMap { observation in
                            observation.topCandidates(1).first?.string
                        } ?? []
                    let text = lines
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n")
                    continuation.resume(returning: text.isEmpty ? nil : text)
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = supportedRecognitionLanguages(for: request)

                do {
                    let handler = VNImageRequestHandler(data: imageData)
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func supportedRecognitionLanguages(for request: VNRecognizeTextRequest) -> [String] {
        let preferred = [
            "zh-Hans",
            "zh-Hant",
            "en-US",
            "de-DE",
            "fr-FR",
            "es-ES",
            "it-IT",
            "pt-BR",
            "ja-JP",
            "ko-KR"
        ]
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let filtered = preferred.filter { supported.contains($0) }
        return filtered.isEmpty ? supported : filtered
    }
}
