import Foundation

struct OpenAIClient {
    static let defaultEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    var session: URLSession = .shared

    static func resolvedEndpoint(from endpointString: String) -> URL {
        let trimmed = endpointString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host != nil
        else {
            return defaultEndpoint
        }
        return url
    }

    func editAnswer(
        endpoint: URL,
        apiKey: String,
        model: String,
        answerText: String,
        readingText: String,
        documentName: String,
        readingFraction: Double,
        outputLanguage: AppLanguage
    ) async throws -> String {
        let prompt = Self.answerCheckPrompt(
            readingText: readingText,
            answerText: answerText,
            documentName: documentName,
            readingFraction: readingFraction,
            outputLanguage: outputLanguage
        )

        return try await sendTextPrompt(
            endpoint: endpoint,
            apiKey: apiKey,
            model: model,
            prompt: prompt
        )
    }

    func checkSelectedText(
        endpoint: URL,
        apiKey: String,
        model: String,
        selectedText: String,
        readingText: String,
        documentName: String,
        readingFraction: Double,
        outputLanguage: AppLanguage
    ) async throws -> String {
        let prompt = Self.selectedTextPrompt(
            readingText: readingText,
            selectedText: selectedText,
            documentName: documentName,
            readingFraction: readingFraction,
            outputLanguage: outputLanguage
        )
        return try await sendTextPrompt(
            endpoint: endpoint,
            apiKey: apiKey,
            model: model,
            prompt: prompt
        )
    }

    static func answerCheckPrompt(
        readingText: String,
        answerText: String,
        documentName: String,
        readingFraction: Double,
        outputLanguage: AppLanguage = .simplifiedChinese
    ) -> String {
        """
        You are reviewing a learner's answer for the visible reading material.

        Document: \(documentName)
        Reading position: \(Int(SyncMapper.clamp(readingFraction) * 100))%

        Visible reading text from OCR:
        \(readingText)

        Current answer:
        \(answerText)

        Return only concise \(outputLanguage.promptName) Markdown feedback.
        Focus on missing key points from the OCR text, misunderstandings to correct, and one improved version of the answer if useful.
        Use short Markdown sections or bullets. Do not use markdown fences or meta commentary.
        """
    }

    static func selectedTextPrompt(
        readingText: String,
        selectedText: String,
        documentName: String,
        readingFraction: Double,
        outputLanguage: AppLanguage = .simplifiedChinese
    ) -> String {
        """
        You are checking only the selected part of a learner's answer against the visible reading material.

        Document: \(documentName)
        Reading position: \(Int(SyncMapper.clamp(readingFraction) * 100))%

        Visible reading text from OCR:
        \(readingText)

        Selected text:
        \(selectedText)

        Return only concise \(outputLanguage.promptName) Markdown feedback.
        Evaluate only the selected text, not the rest of the learner's answer.
        Focus on whether the selected text is accurate, missing key points, or needs correction based on the OCR text.
        Do not use markdown fences or meta commentary.
        """
    }

    // MARK: - API format detection

    /// Returns true when the endpoint path indicates the OpenAI Responses API.
    /// All other endpoints (DeepSeek, Ollama, etc.) are treated as Chat Completions.
    private static func isResponsesAPI(_ endpoint: URL) -> Bool {
        endpoint.path.hasSuffix("/responses")
    }

    // MARK: - Network

    private func sendTextPrompt(
        endpoint: URL,
        apiKey: String,
        model: String,
        prompt: String
    ) async throws -> String {
        let body: Data
        if Self.isResponsesAPI(endpoint) {
            body = try JSONEncoder().encode(
                ResponsesRequest(
                    model: model,
                    input: [
                        ResponsesInputMessage(
                            role: "user",
                            content: [.text(prompt)]
                        )
                    ],
                    reasoning: Reasoning(effort: "medium")
                )
            )
        } else {
            body = try JSONEncoder().encode(
                ChatCompletionsRequest(
                    model: model,
                    messages: [
                        ChatMessage(role: "user", content: prompt)
                    ]
                )
            )
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).bestMessage)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw StudyReaderError.serverError("API request failed: \(message)")
        }

        let decoded = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        guard let text = decoded.bestText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudyReaderError.openAIResponseMissingText
        }
        return text
    }
}

// MARK: - OpenAI Responses API request types

private struct ResponsesRequest: Encodable {
    var model: String
    var input: [ResponsesInputMessage]
    var reasoning: Reasoning
}

private struct Reasoning: Encodable {
    var effort: String
}

private struct ResponsesInputMessage: Encodable {
    var role: String
    var content: [ResponsesContent]
}

private enum ResponsesContent: Encodable {
    case text(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("input_text", forKey: .type)
            try container.encode(text, forKey: .text)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case text
    }
}

// MARK: - Chat Completions API request types (DeepSeek, Ollama, etc.)

private struct ChatCompletionsRequest: Encodable {
    var model: String
    var messages: [ChatMessage]
}

private struct ChatMessage: Encodable {
    var role: String
    var content: String
}

// MARK: - Unified response decoding (supports both API formats)

/// Decodes responses from both the OpenAI Responses API and the standard
/// Chat Completions API. Fields from either format that are absent in the
/// JSON will simply decode as `nil`.
struct ResponseEnvelope: Decodable {
    // --- OpenAI Responses API fields ---
    var outputText: String?
    var output: [ResponseOutputItem]?

    // --- Chat Completions API fields ---
    var choices: [ChatChoice]?

    var bestText: String? {
        // 1) OpenAI Responses API: top-level output_text
        if let outputText, !outputText.isEmpty {
            return outputText
        }

        // 2) OpenAI Responses API: output[].content[].text
        if let output {
            let text = output
                .flatMap { $0.content ?? [] }
                .compactMap(\.text)
                .joined(separator: "\n")
            if !text.isEmpty { return text }
        }

        // 3) Chat Completions API: choices[].message.content
        if let choices {
            let text = choices
                .compactMap { $0.message?.content }
                .joined(separator: "\n")
            if !text.isEmpty { return text }
        }

        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
        case choices
    }
}

struct ResponseOutputItem: Decodable {
    var content: [ResponseOutputContent]?
}

struct ResponseOutputContent: Decodable {
    var type: String?
    var text: String?
}

struct ChatChoice: Decodable {
    var message: ChatResponseMessage?
}

struct ChatResponseMessage: Decodable {
    var role: String?
    var content: String?
}

// MARK: - Error decoding (supports both API formats)

/// Decodes error responses from both OpenAI and Chat Completions-compatible APIs.
/// OpenAI uses `{"error": {"message": "..."}}`.
/// Some providers use `{"error": {"message": "..."}}` or `{"message": "..."}`.
private struct APIErrorEnvelope: Decodable {
    var error: APIErrorBody?
    var message: String?

    var bestMessage: String? {
        error?.message ?? message
    }
}

private struct APIErrorBody: Decodable {
    var message: String
}
