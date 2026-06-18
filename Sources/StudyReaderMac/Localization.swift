import Foundation

enum AppLanguage: String, CaseIterable, Equatable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    static var systemResolved: AppLanguage {
        let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
        return identifier.lowercased().hasPrefix("zh") ? .simplifiedChinese : .english
    }

    var promptName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "Simplified Chinese"
        }
    }
}

enum InterfaceLanguagePreference: String, CaseIterable, Equatable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var resolvedLanguage: AppLanguage {
        switch self {
        case .system:
            return .systemResolved
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        }
    }
}

enum AIOutputLanguagePreference: String, CaseIterable, Equatable {
    case interface
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    func resolvedLanguage(interfaceLanguage: AppLanguage) -> AppLanguage {
        switch self {
        case .interface:
            return interfaceLanguage
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        }
    }
}

enum L10n {
    static func text(_ key: String, language: AppLanguage) -> String {
        table[key]?[language] ?? table[key]?[.english] ?? key
    }

    static func text(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        text(key, language: language, arguments: arguments)
    }

    static func text(_ key: String, language: AppLanguage, arguments: [CVarArg]) -> String {
        String(format: text(key, language: language), locale: Locale(identifier: language.rawValue), arguments: arguments)
    }

    private static let table: [String: [AppLanguage: String]] = [
        "toolbar.open": [.english: "Open", .simplifiedChinese: "打开"],
        "toolbar.check": [.english: "Check", .simplifiedChinese: "检查"],
        "toolbar.settings": [.english: "Settings", .simplifiedChinese: "设置"],
        "toolbar.noDocument": [.english: "No document", .simplifiedChinese: "未打开文档"],
        "toolbar.version": [.english: "v0.37 Languages", .simplifiedChinese: "v0.37 多语言"],

        "pane.reading": [.english: "Reading", .simplifiedChinese: "阅读"],
        "pane.answerSheet": [.english: "Answer Sheet - %@", .simplifiedChinese: "答题区 - %@"],
        "anchor.start": [.english: "Start", .simplifiedChinese: "开始"],
        "anchor.page": [.english: "Page %d", .simplifiedChinese: "第 %d 页"],
        "anchor.position": [.english: "Position %d%%", .simplifiedChinese: "位置 %d%%"],
        "anchor.chapter": [.english: "Chapter %d", .simplifiedChinese: "第 %d 章"],

        "empty.openDocument": [.english: "Open a PDF or DRM-free EPUB", .simplifiedChinese: "打开 PDF 或无 DRM 的 EPUB"],
        "empty.recentHint": [.english: "Recent books appear here after you open them.", .simplifiedChinese: "打开文档后，最近阅读会显示在这里。"],
        "empty.recentBooks": [.english: "Recent Books", .simplifiedChinese: "最近阅读"],
        "recent.remove": [.english: "Remove from history", .simplifiedChinese: "从历史记录移除"],
        "recent.fileMissing": [.english: "File missing", .simplifiedChinese: "文件不存在"],
        "recent.percentRead": [.english: "%d%% read", .simplifiedChinese: "已读 %d%%"],

        "settings.title": [.english: "Settings", .simplifiedChinese: "设置"],
        "settings.apiAddress": [.english: "API Address", .simplifiedChinese: "API 地址"],
        "settings.apiAddressHelp": [.english: "OpenAI Chat Completions, DeepSeek, Ollama, or any compatible endpoint.", .simplifiedChinese: "支持 OpenAI Chat Completions、DeepSeek、Ollama 或兼容接口。"],
        "settings.model": [.english: "Model", .simplifiedChinese: "模型"],
        "settings.modelHelp": [.english: "Model name depends on your provider, e.g. gpt-4o, deepseek-chat, etc.", .simplifiedChinese: "模型名称取决于服务商，例如 gpt-4o、deepseek-chat 等。"],
        "settings.apiKey": [.english: "API Key", .simplifiedChinese: "API Key"],
        "settings.apiKeyHelp": [.english: "Saved with the rest of the app settings and used only when you click Check.", .simplifiedChinese: "会和其他设置一起保存，仅在点击检查时使用。"],
        "settings.feedbackColor": [.english: "AI Feedback Color", .simplifiedChinese: "AI 反馈颜色"],
        "settings.feedbackColorPicker": [.english: "Markdown feedback accent", .simplifiedChinese: "Markdown 反馈强调色"],
        "settings.feedbackColorHelp": [.english: "Used for the AI feedback block and Markdown emphasis in the answer sheet.", .simplifiedChinese: "用于答题区里的 AI 反馈块和 Markdown 强调样式。"],
        "settings.language": [.english: "Language", .simplifiedChinese: "语言"],
        "settings.interfaceLanguage": [.english: "Interface Language", .simplifiedChinese: "界面语言"],
        "settings.aiOutputLanguage": [.english: "AI Output Language", .simplifiedChinese: "AI 输出语言"],
        "settings.followSystem": [.english: "Follow System", .simplifiedChinese: "跟随系统"],
        "settings.followInterface": [.english: "Follow Interface Language", .simplifiedChinese: "跟随界面语言"],
        "settings.english": [.english: "English", .simplifiedChinese: "English"],
        "settings.simplifiedChinese": [.english: "Simplified Chinese", .simplifiedChinese: "简体中文"],
        "settings.cancel": [.english: "Cancel", .simplifiedChinese: "取消"],
        "settings.save": [.english: "Save", .simplifiedChinese: "保存"],

        "status.initial": [.english: "Open a PDF or DRM-free EPUB to begin.", .simplifiedChinese: "打开 PDF 或无 DRM 的 EPUB 开始。"],
        "status.dropFile": [.english: "Drop a PDF or DRM-free EPUB file.", .simplifiedChinese: "拖入 PDF 或无 DRM 的 EPUB 文件。"],
        "status.opened": [.english: "Opened %@.", .simplifiedChinese: "已打开 %@。"],
        "status.missingRecent": [.english: "Could not open %@. The file is missing.", .simplifiedChinese: "无法打开 %@，文件不存在。"],
        "status.removedRecent": [.english: "Removed %@ from history.", .simplifiedChinese: "已从历史记录移除 %@。"],
        "status.removeRecentFailed": [.english: "Could not remove %@: %@", .simplifiedChinese: "无法移除 %@：%@"],
        "status.apiKeyCleared": [.english: "API key cleared.", .simplifiedChinese: "API Key 已清除。"],
        "status.settingsSaved": [.english: "OpenAI settings saved.", .simplifiedChinese: "OpenAI 设置已保存。"],
        "status.openBeforeChecking": [.english: "Open a document before checking.", .simplifiedChinese: "请先打开文档再检查。"],
        "status.selectBeforeChecking": [.english: "Select answer text before checking.", .simplifiedChinese: "请先选择答题文本再检查。"],
        "status.recognizing": [.english: "Recognizing visible reading text...", .simplifiedChinese: "正在识别当前可见阅读文本..."],
        "status.sendingAnswer": [.english: "Sending recognized text and answer to OpenAI...", .simplifiedChinese: "正在将识别文本和答案发送给 OpenAI..."],
        "status.sendingSelection": [.english: "Sending recognized text and selected answer to OpenAI...", .simplifiedChinese: "正在将识别文本和选中答案发送给 OpenAI..."],
        "status.checkComplete": [.english: "Check complete. AI feedback was added below the current answer.", .simplifiedChinese: "检查完成，AI 反馈已添加到当前答案下方。"],
        "status.selectionCheckComplete": [.english: "Check complete. Selected text feedback was added.", .simplifiedChinese: "检查完成，选区反馈已添加。"],
        "error.unsupportedDocument": [.english: "Only PDF and DRM-free EPUB files are supported.", .simplifiedChinese: "仅支持 PDF 和无 DRM 的 EPUB 文件。"],
        "error.missingAPIKey": [.english: "Add your OpenAI API key in Settings first.", .simplifiedChinese: "请先在设置中添加 OpenAI API Key。"],
        "error.missingDocumentCapture": [.english: "Could not capture the current reading view.", .simplifiedChinese: "无法捕获当前阅读视图。"],
        "error.missingRecognizedText": [.english: "Could not recognize readable text from the current view.", .simplifiedChinese: "无法从当前视图识别出可读文本。"],
        "error.emptyAnswer": [.english: "Write an answer before checking.", .simplifiedChinese: "请先填写答案再检查。"],
        "error.epubExtractionFailed": [.english: "Could not open this EPUB: %@", .simplifiedChinese: "无法打开此 EPUB：%@"],
        "error.openAIResponseMissingText": [.english: "OpenAI returned a response without readable text.", .simplifiedChinese: "OpenAI 返回的响应中没有可读文本。"],

        "answer.aiFeedback": [.english: "AI Feedback", .simplifiedChinese: "AI 反馈"],
        "answer.aiFeedbackSelection": [.english: "AI Feedback - Selection", .simplifiedChinese: "AI 反馈 - 选区"],
        "answer.checkSelection": [.english: "Check Selection", .simplifiedChinese: "检查选区"],
        "answer.expandFeedback": [.english: "Expand feedback", .simplifiedChinese: "展开反馈"],
        "answer.collapseFeedback": [.english: "Collapse feedback", .simplifiedChinese: "收起反馈"]
    ]
}

extension PositionAnchor {
    func localizedLabel(language: AppLanguage) -> String {
        if key == Self.start.key {
            return L10n.text("anchor.start", language: language)
        }
        if key.hasPrefix("pdf-page-"), let number = Int(key.replacingOccurrences(of: "pdf-page-", with: "")) {
            return L10n.text("anchor.page", language: language, number)
        }
        if key.hasPrefix("scroll-"), let number = Int(key.replacingOccurrences(of: "scroll-", with: "")) {
            return L10n.text("anchor.position", language: language, number)
        }
        if key.hasPrefix("epub-chapter-"), let number = Int(key.replacingOccurrences(of: "epub-chapter-", with: "")) {
            return L10n.text("anchor.chapter", language: language, number)
        }
        return label
    }
}
