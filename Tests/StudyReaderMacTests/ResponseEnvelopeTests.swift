import XCTest
@testable import StudyReaderMac

final class ResponseEnvelopeTests: XCTestCase {
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
}
