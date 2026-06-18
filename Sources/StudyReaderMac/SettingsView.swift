import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var modelName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.title2.bold())
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("OpenAI API Key")
                    .font(.headline)
                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Stored in macOS Keychain. It is used only when you click Check.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Model")
                    .font(.headline)
                TextField("gpt-5.5", text: $modelName)
                    .textFieldStyle(.roundedBorder)
                Text("Use another Responses-compatible vision model if your account requires it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    appModel.modelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "gpt-5.5"
                        : modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                    appModel.saveAPIKey(apiKey)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 480)
        .onAppear {
            apiKey = appModel.apiKeyForSettings()
            modelName = appModel.modelName
        }
    }
}
