# StudyReaderMac

[English](README.md) | [简体中文](README-zh.md) | [日本語](README-ja.md) | [한국어](README-ko.md) | [Español](README-es.md) | [Français](README-fr.md) | [Deutsch](README-de.md)

StudyReaderMac is a native macOS study tool designed specifically for students and learners. It allows you to study PDF textbooks or DRM-free EPUB books conveniently on your Mac without the need for physical paper books.

## Why StudyReaderMac?
Traditional studying often requires you to juggle between physical books, notebooks, and reference materials. StudyReaderMac simplifies this by providing a dual-pane interface:
- **Left Pane (Read):** Read your PDF or EPUB textbooks directly.
- **Right Pane (Answer):** Write down your answers, notes, or solutions.
- **AI Verification:** Once you've answered a question, the app captures your current reading view and your answer, sending it to OpenAI (or compatible APIs like DeepSeek/Ollama) to verify your correctness and provide instant feedback. 

This makes studying and validating your answers seamless, efficient, and entirely paperless—perfect for students preparing for exams or anyone learning new subjects.

## Features
- **Paperless Studying:** Ditch the heavy paper books and notebooks. Read, answer, and verify everything within one app.
- **Instant AI Feedback:** Get immediate corrections and explanations from AI for your written answers based on the visible textbook content.
- **Continuous Scrolling & Sync:** The reading pane and your answer sheet sync automatically to keep your place.
- **Multiple API Providers:** Pre-configured with OpenAI, DeepSeek, and Ollama, or use your own custom endpoint.
- **Multi-language Support:** Interface available in English, Chinese, Japanese, Korean, Spanish, French, and German.

## API Configuration Guide
StudyReaderMac allows you to use various AI models to verify your answers. Go to **Settings** to configure your preferred API provider:

- **OpenAI:** 
  - Select "OpenAI" from the API Provider list.
  - Enter your OpenAI API Key.
  - Default model is `gpt-4o`.
- **DeepSeek:**
  - Select "DeepSeek" from the API Provider list.
  - Enter your DeepSeek API Key.
  - Default model is `deepseek-chat`.
- **Ollama (Local Models):**
  - Make sure you have Ollama running locally.
  - Select "Ollama". The API Address will auto-fill to `http://localhost:11434/v1/chat/completions`.
  - Default model is `llama3` (make sure you have run `ollama run llama3`).
  - **Note:** The app requires an API Key to be filled in. For Ollama, just enter any dummy text like `ollama`.
- **Custom / LM Studio:**
  - Select "Custom".
  - Enter your compatible endpoint URL (e.g., `http://localhost:1234/v1/chat/completions` for LM Studio).
  - Enter the exact model name.
  - Enter your API Key (or a dummy key if running locally without authentication).

## Run

```bash
swift run StudyReaderMac
```

## Package as a macOS app

```bash
sh Scripts/package-app.sh
open dist/StudyReaderMac.app
```

## Notes

- The app does not capture other apps' windows, so it does not require Screen Recording permission.
- DRM-protected Kindle/Apple Books files are not supported.
- The default model is `gpt-4o` (when using OpenAI); change it in Settings if your API account requires another model.
