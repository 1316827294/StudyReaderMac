import Foundation

enum AppLanguage: String, CaseIterable, Equatable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"

    static var systemResolved: AppLanguage {
        resolvedSystemLanguage(from: Locale.preferredLanguages.first ?? Locale.current.identifier)
    }

    static func resolvedSystemLanguage(from identifier: String) -> AppLanguage {
        let normalized = identifier.lowercased()
        if normalized.hasPrefix("zh") { return .simplifiedChinese }
        if normalized.hasPrefix("ja") { return .japanese }
        if normalized.hasPrefix("ko") { return .korean }
        if normalized.hasPrefix("es") { return .spanish }
        if normalized.hasPrefix("fr") { return .french }
        if normalized.hasPrefix("de") { return .german }
        return .english
    }

    var promptName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "Simplified Chinese"
        case .japanese:
            return "Japanese"
        case .korean:
            return "Korean"
        case .spanish:
            return "Spanish"
        case .french:
            return "French"
        case .german:
            return "German"
        }
    }

    var displayNameKey: String {
        switch self {
        case .english:
            return "settings.english"
        case .simplifiedChinese:
            return "settings.simplifiedChinese"
        case .japanese:
            return "settings.japanese"
        case .korean:
            return "settings.korean"
        case .spanish:
            return "settings.spanish"
        case .french:
            return "settings.french"
        case .german:
            return "settings.german"
        }
    }

    var interfacePreference: InterfaceLanguagePreference {
        switch self {
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        case .japanese:
            return .japanese
        case .korean:
            return .korean
        case .spanish:
            return .spanish
        case .french:
            return .french
        case .german:
            return .german
        }
    }

    var aiOutputPreference: AIOutputLanguagePreference {
        switch self {
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        case .japanese:
            return .japanese
        case .korean:
            return .korean
        case .spanish:
            return .spanish
        case .french:
            return .french
        case .german:
            return .german
        }
    }

    func displayName(interfaceLanguage: AppLanguage) -> String {
        L10n.text(displayNameKey, language: interfaceLanguage)
    }
}

enum InterfaceLanguagePreference: String, CaseIterable, Equatable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"

    var resolvedLanguage: AppLanguage {
        switch self {
        case .system:
            return .systemResolved
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        case .japanese:
            return .japanese
        case .korean:
            return .korean
        case .spanish:
            return .spanish
        case .french:
            return .french
        case .german:
            return .german
        }
    }
}

enum AIOutputLanguagePreference: String, CaseIterable, Equatable {
    case interface
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"

    func resolvedLanguage(interfaceLanguage: AppLanguage) -> AppLanguage {
        switch self {
        case .interface:
            return interfaceLanguage
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        case .japanese:
            return .japanese
        case .korean:
            return .korean
        case .spanish:
            return .spanish
        case .french:
            return .french
        case .german:
            return .german
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

    private static func localized(
        en: String,
        zh: String,
        ja: String,
        ko: String,
        es: String,
        fr: String,
        de: String
    ) -> [AppLanguage: String] {
        [
            .english: en,
            .simplifiedChinese: zh,
            .japanese: ja,
            .korean: ko,
            .spanish: es,
            .french: fr,
            .german: de
        ]
    }

    private static let table: [String: [AppLanguage: String]] = [
        "toolbar.open": localized(en: "Open", zh: "打开", ja: "開く", ko: "열기", es: "Abrir", fr: "Ouvrir", de: "Öffnen"),
        "toolbar.check": localized(en: "Check", zh: "检查", ja: "チェック", ko: "검사", es: "Revisar", fr: "Vérifier", de: "Prüfen"),
        "toolbar.settings": localized(en: "Settings", zh: "设置", ja: "設定", ko: "설정", es: "Ajustes", fr: "Réglages", de: "Einstellungen"),
        "toolbar.noDocument": localized(en: "No document", zh: "未打开文档", ja: "文書なし", ko: "문서 없음", es: "Sin documento", fr: "Aucun document", de: "Kein Dokument"),
        "toolbar.version": localized(en: "v0.38 Languages", zh: "v0.38 多语言", ja: "v0.38 多言語", ko: "v0.38 다국어", es: "v0.38 Idiomas", fr: "v0.38 Langues", de: "v0.38 Sprachen"),

        "pane.reading": localized(en: "Reading", zh: "阅读", ja: "読書", ko: "읽기", es: "Lectura", fr: "Lecture", de: "Lesen"),
        "pane.answerSheet": localized(en: "Answer Sheet - %@", zh: "答题区 - %@", ja: "回答シート - %@", ko: "답안지 - %@", es: "Hoja de respuestas - %@", fr: "Feuille de réponses - %@", de: "Antwortbogen - %@"),
        "anchor.start": localized(en: "Start", zh: "开始", ja: "開始", ko: "시작", es: "Inicio", fr: "Début", de: "Start"),
        "anchor.page": localized(en: "Page %d", zh: "第 %d 页", ja: "%d ページ", ko: "%d페이지", es: "Página %d", fr: "Page %d", de: "Seite %d"),
        "anchor.position": localized(en: "Position %d%%", zh: "位置 %d%%", ja: "位置 %d%%", ko: "위치 %d%%", es: "Posición %d%%", fr: "Position %d%%", de: "Position %d%%"),
        "anchor.chapter": localized(en: "Chapter %d", zh: "第 %d 章", ja: "第 %d 章", ko: "%d장", es: "Capítulo %d", fr: "Chapitre %d", de: "Kapitel %d"),

        "empty.openDocument": localized(en: "Open a PDF or DRM-free EPUB", zh: "打开 PDF 或无 DRM 的 EPUB", ja: "PDF または DRM なし EPUB を開く", ko: "PDF 또는 DRM 없는 EPUB 열기", es: "Abre un PDF o EPUB sin DRM", fr: "Ouvrir un PDF ou un EPUB sans DRM", de: "PDF oder DRM-freies EPUB öffnen"),
        "empty.recentHint": localized(en: "Recent books appear here after you open them.", zh: "打开文档后，最近阅读会显示在这里。", ja: "開いた本はここに最近の本として表示されます。", ko: "문서를 열면 최근 책이 여기에 표시됩니다.", es: "Los libros recientes aparecerán aquí después de abrirlos.", fr: "Les livres récents apparaîtront ici après ouverture.", de: "Zuletzt geöffnete Bücher erscheinen hier."),
        "empty.recentBooks": localized(en: "Recent Books", zh: "最近阅读", ja: "最近の本", ko: "최근 책", es: "Libros recientes", fr: "Livres récents", de: "Zuletzt geöffnete Bücher"),
        "recent.remove": localized(en: "Remove from history", zh: "从历史记录移除", ja: "履歴から削除", ko: "기록에서 제거", es: "Eliminar del historial", fr: "Retirer de l'historique", de: "Aus Verlauf entfernen"),
        "recent.fileMissing": localized(en: "File missing", zh: "文件不存在", ja: "ファイルが見つかりません", ko: "파일 없음", es: "Falta el archivo", fr: "Fichier manquant", de: "Datei fehlt"),
        "recent.percentRead": localized(en: "%d%% read", zh: "已读 %d%%", ja: "%d%% 読了", ko: "%d%% 읽음", es: "%d%% leído", fr: "%d%% lu", de: "%d%% gelesen"),

        "settings.title": localized(en: "Settings", zh: "设置", ja: "設定", ko: "설정", es: "Ajustes", fr: "Réglages", de: "Einstellungen"),
        "settings.apiAddress": localized(en: "API Address", zh: "API 地址", ja: "API アドレス", ko: "API 주소", es: "Dirección de API", fr: "Adresse API", de: "API-Adresse"),
        "settings.apiAddressHelp": localized(en: "OpenAI Chat Completions, DeepSeek, Ollama, or any compatible endpoint.", zh: "支持 OpenAI Chat Completions、DeepSeek、Ollama 或兼容接口。", ja: "OpenAI Chat Completions、DeepSeek、Ollama、または互換エンドポイント。", ko: "OpenAI Chat Completions, DeepSeek, Ollama 또는 호환 엔드포인트.", es: "OpenAI Chat Completions, DeepSeek, Ollama o cualquier endpoint compatible.", fr: "OpenAI Chat Completions, DeepSeek, Ollama ou tout endpoint compatible.", de: "OpenAI Chat Completions, DeepSeek, Ollama oder ein kompatibler Endpunkt."),
        "settings.model": localized(en: "Model", zh: "模型", ja: "モデル", ko: "모델", es: "Modelo", fr: "Modèle", de: "Modell"),
        "settings.modelHelp": localized(en: "Model name depends on your provider, e.g. gpt-4o, deepseek-chat, etc.", zh: "模型名称取决于服务商，例如 gpt-4o、deepseek-chat 等。", ja: "モデル名はプロバイダーによって異なります。例: gpt-4o、deepseek-chat など。", ko: "모델 이름은 제공업체에 따라 다릅니다. 예: gpt-4o, deepseek-chat 등.", es: "El nombre del modelo depende del proveedor, p. ej. gpt-4o, deepseek-chat, etc.", fr: "Le nom du modèle dépend du fournisseur, par ex. gpt-4o, deepseek-chat, etc.", de: "Der Modellname hängt vom Anbieter ab, z. B. gpt-4o, deepseek-chat usw."),
        "settings.apiKey": localized(en: "API Key", zh: "API Key", ja: "API キー", ko: "API 키", es: "Clave API", fr: "Clé API", de: "API-Schlüssel"),
        "settings.apiKeyHelp": localized(en: "Saved with the rest of the app settings and used only when you click Check.", zh: "会和其他设置一起保存，仅在点击检查时使用。", ja: "他のアプリ設定と一緒に保存され、チェック時のみ使用されます。", ko: "다른 앱 설정과 함께 저장되며 검사할 때만 사용됩니다.", es: "Se guarda con el resto de ajustes y solo se usa al hacer clic en Revisar.", fr: "Enregistrée avec les autres réglages et utilisée uniquement lors de la vérification.", de: "Wird mit den App-Einstellungen gespeichert und nur beim Prüfen verwendet."),
        "settings.feedbackColor": localized(en: "AI Feedback Color", zh: "AI 反馈颜色", ja: "AI フィードバックの色", ko: "AI 피드백 색상", es: "Color de comentarios de IA", fr: "Couleur du retour IA", de: "Farbe für KI-Feedback"),
        "settings.feedbackColorPicker": localized(en: "Markdown feedback accent", zh: "Markdown 反馈强调色", ja: "Markdown フィードバックのアクセント", ko: "Markdown 피드백 강조색", es: "Acento de comentarios Markdown", fr: "Accent du retour Markdown", de: "Akzent für Markdown-Feedback"),
        "settings.feedbackColorHelp": localized(en: "Used for the AI feedback block and Markdown emphasis in the answer sheet.", zh: "用于答题区里的 AI 反馈块和 Markdown 强调样式。", ja: "回答シート内の AI フィードバックブロックと Markdown 強調に使用します。", ko: "답안지의 AI 피드백 블록과 Markdown 강조에 사용됩니다.", es: "Se usa para el bloque de comentarios de IA y el énfasis Markdown en la hoja.", fr: "Utilisé pour le bloc de retour IA et les emphases Markdown dans la feuille.", de: "Für den KI-Feedback-Block und Markdown-Hervorhebungen im Antwortbogen."),
        "settings.language": localized(en: "Language", zh: "语言", ja: "言語", ko: "언어", es: "Idioma", fr: "Langue", de: "Sprache"),
        "settings.interfaceLanguage": localized(en: "Interface Language", zh: "界面语言", ja: "インターフェイス言語", ko: "인터페이스 언어", es: "Idioma de la interfaz", fr: "Langue de l'interface", de: "Sprache der Oberfläche"),
        "settings.aiOutputLanguage": localized(en: "AI Output Language", zh: "AI 输出语言", ja: "AI 出力言語", ko: "AI 출력 언어", es: "Idioma de salida de IA", fr: "Langue de sortie IA", de: "Sprache der KI-Ausgabe"),
        "settings.followSystem": localized(en: "Follow System", zh: "跟随系统", ja: "システムに従う", ko: "시스템 따르기", es: "Seguir sistema", fr: "Suivre le système", de: "System folgen"),
        "settings.followInterface": localized(en: "Follow Interface Language", zh: "跟随界面语言", ja: "インターフェイス言語に従う", ko: "인터페이스 언어 따르기", es: "Seguir idioma de la interfaz", fr: "Suivre la langue de l'interface", de: "Oberflächensprache folgen"),
        "settings.english": localized(en: "English", zh: "English", ja: "English", ko: "English", es: "English", fr: "English", de: "English"),
        "settings.simplifiedChinese": localized(en: "Simplified Chinese", zh: "简体中文", ja: "簡体字中国語", ko: "중국어 간체", es: "Chino simplificado", fr: "Chinois simplifié", de: "Vereinfachtes Chinesisch"),
        "settings.japanese": localized(en: "Japanese", zh: "日语", ja: "日本語", ko: "일본어", es: "Japonés", fr: "Japonais", de: "Japanisch"),
        "settings.korean": localized(en: "Korean", zh: "韩语", ja: "韓国語", ko: "한국어", es: "Coreano", fr: "Coréen", de: "Koreanisch"),
        "settings.spanish": localized(en: "Spanish", zh: "西班牙语", ja: "スペイン語", ko: "스페인어", es: "Español", fr: "Espagnol", de: "Spanisch"),
        "settings.french": localized(en: "French", zh: "法语", ja: "フランス語", ko: "프랑스어", es: "Francés", fr: "Français", de: "Französisch"),
        "settings.german": localized(en: "German", zh: "德语", ja: "ドイツ語", ko: "독일어", es: "Alemán", fr: "Allemand", de: "Deutsch"),
        "settings.cancel": localized(en: "Cancel", zh: "取消", ja: "キャンセル", ko: "취소", es: "Cancelar", fr: "Annuler", de: "Abbrechen"),
        "settings.save": localized(en: "Save", zh: "保存", ja: "保存", ko: "저장", es: "Guardar", fr: "Enregistrer", de: "Speichern"),

        "status.initial": localized(en: "Open a PDF or DRM-free EPUB to begin.", zh: "打开 PDF 或无 DRM 的 EPUB 开始。", ja: "開始するには PDF または DRM なし EPUB を開いてください。", ko: "시작하려면 PDF 또는 DRM 없는 EPUB을 여세요.", es: "Abre un PDF o EPUB sin DRM para empezar.", fr: "Ouvrez un PDF ou un EPUB sans DRM pour commencer.", de: "Öffnen Sie ein PDF oder DRM-freies EPUB, um zu beginnen."),
        "status.dropFile": localized(en: "Drop a PDF or DRM-free EPUB file.", zh: "拖入 PDF 或无 DRM 的 EPUB 文件。", ja: "PDF または DRM なし EPUB ファイルをドロップしてください。", ko: "PDF 또는 DRM 없는 EPUB 파일을 드롭하세요.", es: "Suelta un archivo PDF o EPUB sin DRM.", fr: "Déposez un fichier PDF ou EPUB sans DRM.", de: "Legen Sie eine PDF- oder DRM-freie EPUB-Datei ab."),
        "status.opened": localized(en: "Opened %@.", zh: "已打开 %@。", ja: "%@ を開きました。", ko: "%@ 열림.", es: "%@ abierto.", fr: "%@ ouvert.", de: "%@ geöffnet."),
        "status.missingRecent": localized(en: "Could not open %@. The file is missing.", zh: "无法打开 %@，文件不存在。", ja: "%@ を開けません。ファイルが見つかりません。", ko: "%@을(를) 열 수 없습니다. 파일이 없습니다.", es: "No se pudo abrir %@. Falta el archivo.", fr: "Impossible d'ouvrir %@. Le fichier est manquant.", de: "%@ konnte nicht geöffnet werden. Die Datei fehlt."),
        "status.removedRecent": localized(en: "Removed %@ from history.", zh: "已从历史记录移除 %@。", ja: "%@ を履歴から削除しました。", ko: "%@을(를) 기록에서 제거했습니다.", es: "%@ eliminado del historial.", fr: "%@ retiré de l'historique.", de: "%@ aus dem Verlauf entfernt."),
        "status.removeRecentFailed": localized(en: "Could not remove %@: %@", zh: "无法移除 %@：%@", ja: "%@ を削除できません: %@", ko: "%@을(를) 제거할 수 없습니다: %@", es: "No se pudo eliminar %@: %@", fr: "Impossible de retirer %@ : %@", de: "%@ konnte nicht entfernt werden: %@"),
        "status.apiKeyCleared": localized(en: "API key cleared.", zh: "API Key 已清除。", ja: "API キーを消去しました。", ko: "API 키를 지웠습니다.", es: "Clave API borrada.", fr: "Clé API effacée.", de: "API-Schlüssel gelöscht."),
        "status.settingsSaved": localized(en: "OpenAI settings saved.", zh: "OpenAI 设置已保存。", ja: "OpenAI 設定を保存しました。", ko: "OpenAI 설정을 저장했습니다.", es: "Ajustes de OpenAI guardados.", fr: "Réglages OpenAI enregistrés.", de: "OpenAI-Einstellungen gespeichert."),
        "status.openBeforeChecking": localized(en: "Open a document before checking.", zh: "请先打开文档再检查。", ja: "チェックする前に文書を開いてください。", ko: "검사하기 전에 문서를 여세요.", es: "Abre un documento antes de revisar.", fr: "Ouvrez un document avant de vérifier.", de: "Öffnen Sie vor dem Prüfen ein Dokument."),
        "status.selectBeforeChecking": localized(en: "Select answer text before checking.", zh: "请先选择答题文本再检查。", ja: "チェックする前に回答テキストを選択してください。", ko: "검사하기 전에 답안 텍스트를 선택하세요.", es: "Selecciona texto de la respuesta antes de revisar.", fr: "Sélectionnez du texte de réponse avant de vérifier.", de: "Wählen Sie vor dem Prüfen Antworttext aus."),
        "status.recognizing": localized(en: "Recognizing visible reading text...", zh: "正在识别当前可见阅读文本...", ja: "表示中の読書テキストを認識しています...", ko: "보이는 읽기 텍스트를 인식 중...", es: "Reconociendo el texto visible...", fr: "Reconnaissance du texte visible...", de: "Sichtbaren Lesetext erkennen..."),
        "status.sendingAnswer": localized(en: "Sending recognized text and answer to OpenAI...", zh: "正在将识别文本和答案发送给 OpenAI...", ja: "認識したテキストと回答を OpenAI に送信しています...", ko: "인식한 텍스트와 답안을 OpenAI로 보내는 중...", es: "Enviando texto reconocido y respuesta a OpenAI...", fr: "Envoi du texte reconnu et de la réponse à OpenAI...", de: "Erkannten Text und Antwort an OpenAI senden..."),
        "status.sendingSelection": localized(en: "Sending recognized text and selected answer to OpenAI...", zh: "正在将识别文本和选中答案发送给 OpenAI...", ja: "認識したテキストと選択した回答を OpenAI に送信しています...", ko: "인식한 텍스트와 선택한 답안을 OpenAI로 보내는 중...", es: "Enviando texto reconocido y respuesta seleccionada a OpenAI...", fr: "Envoi du texte reconnu et de la réponse sélectionnée à OpenAI...", de: "Erkannten Text und ausgewählte Antwort an OpenAI senden..."),
        "status.checkComplete": localized(en: "Check complete. AI feedback was added below the current answer.", zh: "检查完成，AI 反馈已添加到当前答案下方。", ja: "チェック完了。AI フィードバックを現在の回答の下に追加しました。", ko: "검사 완료. AI 피드백이 현재 답안 아래에 추가되었습니다.", es: "Revisión completa. Los comentarios de IA se añadieron bajo la respuesta actual.", fr: "Vérification terminée. Le retour IA a été ajouté sous la réponse actuelle.", de: "Prüfung abgeschlossen. KI-Feedback wurde unter der aktuellen Antwort hinzugefügt."),
        "status.selectionCheckComplete": localized(en: "Check complete. Selected text feedback was added.", zh: "检查完成，选区反馈已添加。", ja: "チェック完了。選択テキストのフィードバックを追加しました。", ko: "검사 완료. 선택한 텍스트 피드백이 추가되었습니다.", es: "Revisión completa. Se añadieron comentarios del texto seleccionado.", fr: "Vérification terminée. Le retour sur le texte sélectionné a été ajouté.", de: "Prüfung abgeschlossen. Feedback zum ausgewählten Text wurde hinzugefügt."),
        "error.unsupportedDocument": localized(en: "Only PDF and DRM-free EPUB files are supported.", zh: "仅支持 PDF 和无 DRM 的 EPUB 文件。", ja: "PDF と DRM なし EPUB ファイルのみ対応しています。", ko: "PDF 및 DRM 없는 EPUB 파일만 지원됩니다.", es: "Solo se admiten archivos PDF y EPUB sin DRM.", fr: "Seuls les fichiers PDF et EPUB sans DRM sont pris en charge.", de: "Nur PDF- und DRM-freie EPUB-Dateien werden unterstützt."),
        "error.missingAPIKey": localized(en: "Add your OpenAI API key in Settings first.", zh: "请先在设置中添加 OpenAI API Key。", ja: "まず設定で OpenAI API キーを追加してください。", ko: "먼저 설정에서 OpenAI API 키를 추가하세요.", es: "Añade primero tu clave API de OpenAI en Ajustes.", fr: "Ajoutez d'abord votre clé API OpenAI dans les réglages.", de: "Fügen Sie zuerst Ihren OpenAI-API-Schlüssel in den Einstellungen hinzu."),
        "error.missingDocumentCapture": localized(en: "Could not capture the current reading view.", zh: "无法捕获当前阅读视图。", ja: "現在の読書ビューをキャプチャできませんでした。", ko: "현재 읽기 보기를 캡처할 수 없습니다.", es: "No se pudo capturar la vista de lectura actual.", fr: "Impossible de capturer la vue de lecture actuelle.", de: "Die aktuelle Leseansicht konnte nicht erfasst werden."),
        "error.missingRecognizedText": localized(en: "Could not recognize readable text from the current view.", zh: "无法从当前视图识别出可读文本。", ja: "現在のビューから読み取り可能なテキストを認識できませんでした。", ko: "현재 보기에서 읽을 수 있는 텍스트를 인식할 수 없습니다.", es: "No se pudo reconocer texto legible en la vista actual.", fr: "Impossible de reconnaître du texte lisible dans la vue actuelle.", de: "Aus der aktuellen Ansicht konnte kein lesbarer Text erkannt werden."),
        "error.emptyAnswer": localized(en: "Write an answer before checking.", zh: "请先填写答案再检查。", ja: "チェックする前に回答を書いてください。", ko: "검사하기 전에 답안을 작성하세요.", es: "Escribe una respuesta antes de revisar.", fr: "Rédigez une réponse avant de vérifier.", de: "Schreiben Sie vor dem Prüfen eine Antwort."),
        "error.epubExtractionFailed": localized(en: "Could not open this EPUB: %@", zh: "无法打开此 EPUB：%@", ja: "この EPUB を開けませんでした: %@", ko: "이 EPUB을 열 수 없습니다: %@", es: "No se pudo abrir este EPUB: %@", fr: "Impossible d'ouvrir cet EPUB : %@", de: "Dieses EPUB konnte nicht geöffnet werden: %@"),
        "error.openAIResponseMissingText": localized(en: "OpenAI returned a response without readable text.", zh: "OpenAI 返回的响应中没有可读文本。", ja: "OpenAI の応答に読み取り可能なテキストがありません。", ko: "OpenAI 응답에 읽을 수 있는 텍스트가 없습니다.", es: "OpenAI devolvió una respuesta sin texto legible.", fr: "OpenAI a renvoyé une réponse sans texte lisible.", de: "OpenAI hat eine Antwort ohne lesbaren Text zurückgegeben."),

        "answer.aiFeedback": localized(en: "AI Feedback", zh: "AI 反馈", ja: "AI フィードバック", ko: "AI 피드백", es: "Comentarios de IA", fr: "Retour IA", de: "KI-Feedback"),
        "answer.aiFeedbackSelection": localized(en: "AI Feedback - Selection", zh: "AI 反馈 - 选区", ja: "AI フィードバック - 選択範囲", ko: "AI 피드백 - 선택 영역", es: "Comentarios de IA - selección", fr: "Retour IA - sélection", de: "KI-Feedback - Auswahl"),
        "answer.checkSelection": localized(en: "Check Selection", zh: "检查选区", ja: "選択範囲をチェック", ko: "선택 영역 검사", es: "Revisar selección", fr: "Vérifier la sélection", de: "Auswahl prüfen"),
        "answer.expandFeedback": localized(en: "Expand feedback", zh: "展开反馈", ja: "フィードバックを展開", ko: "피드백 펼치기", es: "Expandir comentarios", fr: "Développer le retour", de: "Feedback erweitern"),
        "answer.collapseFeedback": localized(en: "Collapse feedback", zh: "收起反馈", ja: "フィードバックを折りたたむ", ko: "피드백 접기", es: "Contraer comentarios", fr: "Réduire le retour", de: "Feedback einklappen")
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
