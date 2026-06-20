import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var endpointURL = ""
    @State private var apiKey = ""
    @State private var modelName = ""
    @State private var selectedProvider = "custom"
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
                Text(appModel.localized("settings.apiProvider"))
                    .font(.headline)
                Picker("", selection: $selectedProvider) {
                    Text("OpenAI").tag("openai")
                    Text("DeepSeek").tag("deepseek")
                    Text("Ollama").tag("ollama")
                    Text(appModel.localized("settings.customProvider")).tag("custom")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .onChange(of: selectedProvider) { _, newValue in
                    switch newValue {
                    case "openai":
                        endpointURL = "https://api.openai.com/v1/chat/completions"
                        if modelName.isEmpty || modelName == "deepseek-chat" || modelName == "llama3" || modelName == "gpt-5.5" {
                            modelName = "gpt-4o"
                        }
                    case "deepseek":
                        endpointURL = "https://api.deepseek.com/chat/completions"
                        if modelName.isEmpty || modelName == "gpt-4o" || modelName == "llama3" || modelName == "gpt-5.5" {
                            modelName = "deepseek-chat"
                        }
                    case "ollama":
                        endpointURL = "http://localhost:11434/v1/chat/completions"
                        if modelName.isEmpty || modelName == "gpt-4o" || modelName == "deepseek-chat" || modelName == "gpt-5.5" {
                            modelName = "llama3"
                        }
                    default:
                        break
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(appModel.localized("settings.apiAddress"))
                    .font(.headline)
                TextField(OpenAIClient.defaultEndpoint.absoluteString, text: $endpointURL)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: endpointURL) { _, newValue in
                        if newValue == "https://api.openai.com/v1/chat/completions" {
                            selectedProvider = "openai"
                        } else if newValue == "https://api.deepseek.com/chat/completions" {
                            selectedProvider = "deepseek"
                        } else if newValue == "http://localhost:11434/v1/chat/completions" {
                            selectedProvider = "ollama"
                        } else {
                            selectedProvider = "custom"
                        }
                    }
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
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName(interfaceLanguage: appModel.interfaceLanguage))
                            .tag(language.interfacePreference)
                    }
                }
                Picker(appModel.localized("settings.aiOutputLanguage"), selection: $aiOutputLanguagePreference) {
                    Text(appModel.localized("settings.followInterface")).tag(AIOutputLanguagePreference.interface)
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName(interfaceLanguage: appModel.interfaceLanguage))
                            .tag(language.aiOutputPreference)
                    }
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
            
            if endpointURL == "https://api.openai.com/v1/chat/completions" {
                selectedProvider = "openai"
            } else if endpointURL == "https://api.deepseek.com/chat/completions" {
                selectedProvider = "deepseek"
            } else if endpointURL == "http://localhost:11434/v1/chat/completions" {
                selectedProvider = "ollama"
            } else {
                selectedProvider = "custom"
            }
        }
    }
}
