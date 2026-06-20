# StudyReaderMac

[English](README.md) | [简体中文](README-zh.md) | [日本語](README-ja.md) | [한국어](README-ko.md) | [Español](README-es.md) | [Français](README-fr.md) | [Deutsch](README-de.md)

StudyReaderMac ist ein natives macOS-Lerntool, das speziell für Schüler, Studenten und Lernende entwickelt wurde. Es ermöglicht das bequeme Lernen mit PDF-Lehrbüchern oder DRM-freien EPUB-Büchern auf Ihrem Mac, ganz ohne physische Papierbücher.

## Warum StudyReaderMac?
Herkömmliches Lernen erfordert oft ein ständiges Hin und Her zwischen physischen Büchern, Notizheften und Referenzmaterialien. StudyReaderMac vereinfacht dies durch eine Zwei-Fenster-Ansicht:
- **Linkes Fenster (Lesen):** Lesen Sie Ihre PDF- oder EPUB-Lehrbücher direkt.
- **Rechtes Fenster (Antworten):** Notieren Sie Ihre Antworten, Notizen oder Lösungswege.
- **KI-Überprüfung:** Sobald Sie eine Frage beantwortet haben, erfasst die App Ihre aktuelle Leseansicht und Ihre Antwort und sendet sie an OpenAI (oder kompatible APIs wie DeepSeek/Ollama), um Ihre Richtigkeit zu überprüfen und sofortiges Feedback zu geben.

Das macht das Lernen und Validieren Ihrer Antworten nahtlos, effizient und komplett papierlos – perfekt für Studenten, die sich auf Prüfungen vorbereiten, oder jeden, der neue Fächer lernt.

## Funktionen
- **Papierloses Lernen:** Verabschieden Sie sich von schweren Papierbüchern und Notizheften. Lesen, beantworten und überprüfen Sie alles in einer einzigen App.
- **Sofortiges KI-Feedback:** Erhalten Sie auf Basis des sichtbaren Lehrbuchinhalts sofortige Korrekturen und Erklärungen von der KI für Ihre geschriebenen Antworten.
- **Kontinuierliches Scrollen & Synchronisieren:** Das Lesefenster und Ihr Antwortbogen werden automatisch synchronisiert, damit Sie immer wissen, wo Sie sind.
- **Mehrere API-Anbieter:** Vorkonfiguriert mit OpenAI, DeepSeek und Ollama, oder verwenden Sie Ihren eigenen benutzerdefinierten Endpunkt.
- **Mehrsprachige Unterstützung:** Die Benutzeroberfläche ist in Englisch, Chinesisch, Japanisch, Koreanisch, Spanisch, Französisch und Deutsch verfügbar.

## API-Konfigurationsanleitung
StudyReaderMac ermöglicht es Ihnen, verschiedene KI-Modelle zur Überprüfung Ihrer Antworten zu verwenden. Gehen Sie zu den **Einstellungen**, um Ihren bevorzugten API-Anbieter zu konfigurieren:

- **OpenAI:** 
  - Wählen Sie "OpenAI" aus der Liste der API-Anbieter.
  - Geben Sie Ihren OpenAI-API-Schlüssel ein.
  - Das Standardmodell ist `gpt-5.5`.
- **DeepSeek:**
  - Wählen Sie "DeepSeek".
  - Geben Sie Ihren DeepSeek-API-Schlüssel ein.
  - Das Standardmodell ist `deepseek-v4-flash`.
- **Ollama (Lokale Modelle):**
  - Stellen Sie sicher, dass Ollama lokal ausgeführt wird.
  - Wählen Sie "Ollama". Die API-Adresse wird automatisch auf `http://localhost:11434/v1/chat/completions` gesetzt.
  - Das Standardmodell ist `llama3` (stellen Sie sicher, dass Sie `ollama run llama3` ausgeführt haben).
  - **Hinweis:** Die App erfordert die Eingabe eines API-Schlüssels. Geben Sie für Ollama einfach einen Dummy-Text wie `ollama` ein.
- **Benutzerdefiniert / LM Studio:**
  - Wählen Sie "Benutzerdefiniert".
  - Geben Sie Ihre kompatible Endpunkt-URL ein (z. B. `http://localhost:1234/v1/chat/completions` für LM Studio).
  - Geben Sie den genauen Modellnamen ein.
  - Geben Sie Ihren API-Schlüssel ein (oder einen Dummy-Schlüssel bei lokaler Ausführung ohne Authentifizierung).

## Ausführen

```bash
swift run StudyReaderMac
```

## Als macOS-App verpacken

```bash
sh Scripts/package-app.sh
open dist/StudyReaderMac.app
```

## Hinweise

- Die App zeichnet keine Fenster anderer Apps auf und erfordert daher keine Berechtigung für "Bildschirmaufnahme".
- DRM-geschützte Dateien aus Kindle / Apple Books werden nicht unterstützt.
- Das Standardmodell ist `gpt-5.5` (bei Verwendung von OpenAI); ändern Sie dies in den Einstellungen, falls Ihr API-Konto ein anderes Modell erfordert.
