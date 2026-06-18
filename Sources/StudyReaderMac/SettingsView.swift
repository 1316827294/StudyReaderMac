import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var endpointURL = ""
    @State private var apiKey = ""
    @State private var modelName = ""
    @State private var feedbackAccentColor = Color.accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.title2.bold())
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API Address")
                    .font(.headline)
                TextField(OpenAIClient.defaultEndpoint.absoluteString, text: $endpointURL)
                    .textFieldStyle(.roundedBorder)
                Text("OpenAI Chat Completions, DeepSeek, Ollama, or any compatible endpoint.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Model")
                    .font(.headline)
                TextField("gpt-5.5", text: $modelName)
                    .textFieldStyle(.roundedBorder)
                Text("Model name depends on your provider, e.g. gpt-4o, deepseek-chat, etc.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.headline)
                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Saved with the rest of the app settings and used only when you click Check.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("AI Feedback Color")
                    .font(.headline)
                ColorPicker("Markdown feedback accent", selection: $feedbackAccentColor, supportsOpacity: false)
                Text("Used for the AI feedback block and Markdown emphasis in the answer sheet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    let trimmedEndpoint = endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    appModel.openAIEndpointURLString = trimmedEndpoint.isEmpty
                        ? OpenAIClient.defaultEndpoint.absoluteString
                        : trimmedEndpoint
                    appModel.modelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "gpt-5.5"
                        : modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                    appModel.feedbackAccentHex = NSColor(feedbackAccentColor).studyReaderHexRGB ?? "#0A84FF"
                    appModel.saveAPIKey(apiKey)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 480)
        .onAppear {
            endpointURL = appModel.openAIEndpointURLString
            apiKey = appModel.apiKeyForSettings()
            modelName = appModel.modelName
            feedbackAccentColor = Color(nsColor: appModel.feedbackAccentColor)
        }
    }
}
