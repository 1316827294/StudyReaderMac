import XCTest
@testable import StudyReaderMac

final class ResponseEnvelopeTests: XCTestCase {
    // MARK: - OpenAI Responses API format

    func testUsesOutputTextWhenPresent() throws {
        let data = #"{"output_text":"done"}"#.data(using: .utf8)!
        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        XCTAssertEqual(envelope.bestText, "done")
    }

    func testFallsBackToOutputContentText() throws {
        let data = """
        {
          "output": [
            {
              "content": [
                { "type": "output_text", "text": "first" },
                { "type": "output_text", "text": "second" }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        XCTAssertEqual(envelope.bestText, "first\nsecond")
    }

    // MARK: - Chat Completions API format (DeepSeek, Ollama, etc.)

    func testDecodesChatCompletionsResponse() throws {
        let data = """
        {
          "id": "chatcmpl-abc123",
          "choices": [
            {
              "message": {
                "role": "assistant",
                "content": "Hello from DeepSeek"
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        XCTAssertEqual(envelope.bestText, "Hello from DeepSeek")
    }

    func testDecodesChatCompletionsMultipleChoices() throws {
        let data = """
        {
          "choices": [
            { "message": { "role": "assistant", "content": "Part 1" } },
            { "message": { "role": "assistant", "content": "Part 2" } }
          ]
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        XCTAssertEqual(envelope.bestText, "Part 1\nPart 2")
    }

    func testOutputTextTakesPriorityOverChoices() throws {
        // If both fields are present (unlikely), output_text wins
        let data = """
        {
          "output_text": "from responses API",
          "choices": [
            { "message": { "content": "from chat API" } }
          ]
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        XCTAssertEqual(envelope.bestText, "from responses API")
    }

    // MARK: - Prompts

    func testSelectedTextPromptScopesFeedbackToSelection() {
        let prompt = OpenAIClient.selectedTextPrompt(
            readingText: "visible OCR text",
            selectedText: "selected answer",
            documentName: "book.pdf",
            readingFraction: 0.42
        )

        XCTAssertTrue(prompt.contains("Visible reading text from OCR:"))
        XCTAssertTrue(prompt.contains("visible OCR text"))
        XCTAssertTrue(prompt.contains("Selected text:"))
        XCTAssertTrue(prompt.contains("selected answer"))
        XCTAssertTrue(prompt.contains("Evaluate only the selected text"))
        XCTAssertFalse(prompt.contains("Current answer:"))
        XCTAssertFalse(prompt.localizedCaseInsensitiveContains("screenshot"))
    }

    func testAnswerPromptUsesOCRTextInsteadOfScreenshot() {
        let prompt = OpenAIClient.answerCheckPrompt(
            readingText: "visible OCR text",
            answerText: "learner answer",
            documentName: "book.pdf",
            readingFraction: 0.3
        )

        XCTAssertTrue(prompt.contains("Visible reading text from OCR:"))
        XCTAssertTrue(prompt.contains("visible OCR text"))
        XCTAssertTrue(prompt.contains("Current answer:"))
        XCTAssertTrue(prompt.contains("learner answer"))
        XCTAssertFalse(prompt.localizedCaseInsensitiveContains("screenshot"))
    }

    // MARK: - Endpoint resolution

    func testResolvedEndpointFallsBackForEmptyOrInvalidValues() {
        XCTAssertEqual(OpenAIClient.resolvedEndpoint(from: ""), OpenAIClient.defaultEndpoint)
        XCTAssertEqual(OpenAIClient.resolvedEndpoint(from: "not a url"), OpenAIClient.defaultEndpoint)
        XCTAssertEqual(OpenAIClient.resolvedEndpoint(from: "ftp://example.com/v1/chat/completions"), OpenAIClient.defaultEndpoint)
    }

    func testResolvedEndpointAcceptsHTTPAndHTTPSURLs() {
        XCTAssertEqual(
            OpenAIClient.resolvedEndpoint(from: "https://api.deepseek.com/v1/chat/completions"),
            URL(string: "https://api.deepseek.com/v1/chat/completions")!
        )
        XCTAssertEqual(
            OpenAIClient.resolvedEndpoint(from: "http://localhost:11434/v1/chat/completions"),
            URL(string: "http://localhost:11434/v1/chat/completions")!
        )
    }
}
