# StudyReaderMac

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
- Das Standardmodell ist `gpt-4o` (bei Verwendung von OpenAI); ändern Sie dies in den Einstellungen, falls Ihr API-Konto ein anderes Modell erfordert.
