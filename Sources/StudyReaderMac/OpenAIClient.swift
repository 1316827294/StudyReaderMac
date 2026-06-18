import Foundation

struct OpenAIClient {
    var endpoint = URL(string: "https://api.openai.com/v1/responses")!
    var session: URLSession = .shared

    func editAnswer(
        apiKey: String,
        model: String,
        answerText: String,
        readingImageJPEG: Data,
        documentName: String,
        readingFraction: Double
    ) async throws -> String {
        let imageURL = "data:image/jpeg;base64,\(readingImageJPEG.base64EncodedString())"
        let prompt = """
        You are editing a learner's answer for the visible reading material.

        Document: \(documentName)
        Reading position: \(Int(SyncMapper.clamp(readingFraction) * 100))%

        Current answer:
        \(answerText)

        Return only the revised answer text in Chinese.
        Improve the current answer by adding missing key points from the screenshot, correcting misunderstandings, and keeping the learner's useful wording where possible.
        Do not include headings like "feedback", explanations about your edits, markdown fences, or meta commentary.
        """

        let requestBody = ResponseRequest(
            model: model,
            input: [
                ResponseInputMessage(
                    role: "user",
                    content: [
                        .text(prompt),
                        .image(imageURL: imageURL, detail: "high")
                    ]
                )
            ],
            reasoning: Reasoning(effort: "medium")
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            let message = (try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data).error.message)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw StudyReaderError.serverError("OpenAI request failed: \(message)")
        }

        let decoded = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        guard let text = decoded.bestText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudyReaderError.openAIResponseMissingText
        }
        return text
    }
}

private struct ResponseRequest: Encodable {
    var model: String
    var input: [ResponseInputMessage]
    var reasoning: Reasoning
}

private struct Reasoning: Encodable {
    var effort: String
}

private struct ResponseInputMessage: Encodable {
    var role: String
    var content: [ResponseContent]
}

private enum ResponseContent: Encodable {
    case text(String)
    case image(imageURL: String, detail: String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("input_text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let imageURL, let detail):
            try container.encode("input_image", forKey: .type)
            try container.encode(imageURL, forKey: .imageURL)
            try container.encode(detail, forKey: .detail)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
        case detail
    }
}

struct ResponseEnvelope: Decodable {
    var outputText: String?
    var output: [ResponseOutputItem]?

    var bestText: String? {
        if let outputText, !outputText.isEmpty {
            return outputText
        }

        let text = output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined(separator: "\n")
        return text?.isEmpty == false ? text : nil
    }

    private enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }
}

struct ResponseOutputItem: Decodable {
    var content: [ResponseOutputContent]?
}

struct ResponseOutputContent: Decodable {
    var type: String?
    var text: String?
}

private struct OpenAIErrorEnvelope: Decodable {
    var error: OpenAIError
}

private struct OpenAIError: Decodable {
    var message: String
}
