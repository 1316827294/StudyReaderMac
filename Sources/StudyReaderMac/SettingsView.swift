import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var endpointURL = ""
    @State private var apiKey = ""
    @State private var modelName = ""
    @State private var feedbackAccentColor = Color.accentColor
    @State private var interfaceLanguagePreference = InterfaceLanguagePreference.system
    @State private var aiOutputLanguagePreference = AIOutputLanguagePreference.interface

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(appModel.localized("settings.title"))
                    .font(.title2.bold())
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(appModel.localized("settings.apiAddress"))
                    .font(.headline)
                TextField(OpenAIClient.defaultEndpoint.absoluteString, text: $endpointURL)
                    .textFieldStyle(.roundedBorder)
                Text(appModel.localized("settings.apiAddressHelp"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(appModel.localized("settings.model"))
                    .font(.headline)
                TextField("gpt-5.5", text: $modelName)
                    .textFieldStyle(.roundedBorder)
                Text(appModel.localized("settings.modelHelp"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(appModel.localized("settings.apiKey"))
                    .font(.headline)
                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Text(appModel.localized("settings.apiKeyHelp"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(appModel.localized("settings.feedbackColor"))
                    .font(.headline)
                ColorPicker(appModel.localized("settings.feedbackColorPicker"), selection: $feedbackAccentColor, supportsOpacity: false)
                Text(appModel.localized("settings.feedbackColorHelp"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(appModel.localized("settings.language"))
                    .font(.headline)
                Picker(appModel.localized("settings.interfaceLanguage"), selection: $interfaceLanguagePreference) {
                    Text(appModel.localized("settings.followSystem")).tag(InterfaceLanguagePreference.system)
                    Text(appModel.localized("settings.english")).tag(InterfaceLanguagePreference.english)
                    Text(appModel.localized("settings.simplifiedChinese")).tag(InterfaceLanguagePreference.simplifiedChinese)
                }
                Picker(appModel.localized("settings.aiOutputLanguage"), selection: $aiOutputLanguagePreference) {
                    Text(appModel.localized("settings.followInterface")).tag(AIOutputLanguagePreference.interface)
                    Text(appModel.localized("settings.english")).tag(AIOutputLanguagePreference.english)
                    Text(appModel.localized("settings.simplifiedChinese")).tag(AIOutputLanguagePreference.simplifiedChinese)
                }
            }

            HStack {
                Button(appModel.localized("settings.cancel")) {
                    dismiss()
                }
                Spacer()
                Button(appModel.localized("settings.save")) {
                    let trimmedEndpoint = endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    appModel.openAIEndpointURLString = trimmedEndpoint.isEmpty
                        ? OpenAIClient.defaultEndpoint.absoluteString
                        : trimmedEndpoint
                    appModel.modelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "gpt-5.5"
                        : modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                    appModel.feedbackAccentHex = NSColor(feedbackAccentColor).studyReaderHexRGB ?? "#0A84FF"
                    appModel.interfaceLanguagePreference = interfaceLanguagePreference
                    appModel.aiOutputLanguagePreference = aiOutputLanguagePreference
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
            interfaceLanguagePreference = appModel.interfaceLanguagePreference
            aiOutputLanguagePreference = appModel.aiOutputLanguagePreference
        }
    }
}
