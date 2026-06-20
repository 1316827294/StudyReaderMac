# StudyReaderMac

[English](README.md) | [简体中文](README-zh.md) | [日本語](README-ja.md) | [한국어](README-ko.md) | [Español](README-es.md) | [Français](README-fr.md) | [Deutsch](README-de.md)

StudyReaderMac은 학생과 학습자를 위해 특별히 설계된 네이티브 macOS 학습 도구입니다. 무거운 종이책 없이도 Mac에서 PDF 교재나 DRM이 없는 EPUB 책을 편리하게 학습할 수 있도록 해줍니다.

## 왜 StudyReaderMac인가요?
기존의 학습 방식은 종이책, 노트, 참고 자료를 번갈아 봐야 하는 번거로움이 있었습니다. StudyReaderMac은 이중 창 인터페이스를 제공하여 이 과정을 크게 단순화합니다:
- **왼쪽 창 (읽기):** PDF나 EPUB 교재를 직접 읽습니다.
- **오른쪽 창 (답변):** 답변, 노트 또는 풀이 과정을 작성합니다.
- **AI 검증:** 답변 작성을 마치면, 앱이 현재 읽고 있는 교재 화면과 작성한 답변을 캡처하여 OpenAI(또는 DeepSeek/Ollama 등 호환 API)로 보내 정확성을 검증하고 즉각적인 피드백을 제공합니다.

이를 통해 학습과 답변 검증이 매끄럽고 효율적이며 완벽한 페이퍼리스(Paperless)로 이루어집니다. 시험을 준비하는 학생이나 새로운 지식을 배우는 모든 사람에게 완벽한 도구입니다.

## 주요 기능
- **페이퍼리스 학습:** 무거운 종이책과 노트를 버리세요. 읽고, 답하고, 검증하는 모든 것을 하나의 앱에서 처리합니다.
- **즉각적인 AI 피드백:** 보이는 교재 내용을 바탕으로 작성한 답변에 대해 AI로부터 즉각적인 수정 및 설명을 받을 수 있습니다.
- **연속 스크롤 및 동기화:** 읽기 창과 답안지가 자동으로 동기화되어 학습 위치를 놓치지 않습니다.
- **다중 API 제공업체:** OpenAI, DeepSeek, Ollama가 기본 설정되어 있으며, 사용자 지정 엔드포인트도 사용할 수 있습니다.
- **다국어 지원:** 인터페이스는 영어, 중국어, 일본어, 한국어, 스페인어, 프랑스어, 독일어로 제공됩니다.

## API 설정 가이드
StudyReaderMac을 사용하면 다양한 AI 모델을 사용하여 답변을 확인할 수 있습니다. **설정**에서 선호하는 API 제공업체를 구성하세요:

- **OpenAI:** 
  - API 제공자 목록에서 "OpenAI"를 선택합니다.
  - OpenAI API 키를 입력합니다.
  - 기본 모델은 `gpt-5.5`입니다.
- **DeepSeek:**
  - "DeepSeek"을 선택합니다.
  - DeepSeek API 키를 입력합니다.
  - 기본 모델은 `deepseek-v4-flash`입니다.
- **Ollama (로컬 모델):**
  - Ollama가 로컬에서 실행 중인지 확인하세요.
  - "Ollama"를 선택하면 API 주소가 `http://localhost:11434/v1/chat/completions`로 자동 채워집니다.
  - 기본 모델은 `llama3`입니다(미리 `ollama run llama3`를 실행해 두세요).
  - **참고:** 앱에서는 API 키를 반드시 입력해야 합니다. Ollama의 경우 `ollama`와 같은 더미 텍스트를 입력하면 됩니다.
- **사용자 지정 / LM Studio:**
  - "사용자 지정"을 선택합니다.
  - 호환되는 엔드포인트 URL을 입력합니다(예: LM Studio의 경우 `http://localhost:1234/v1/chat/completions`).
  - 정확한 모델 이름을 입력합니다.
  - API 키를 입력합니다(인증이 없는 로컬 모델인 경우 더미 키 입력).

## 실행

```bash
swift run StudyReaderMac
```

## macOS 앱으로 패키징

```bash
sh Scripts/package-app.sh
open dist/StudyReaderMac.app
```

## 참고 사항

- 이 앱은 다른 앱의 창을 캡처하지 않으므로 '화면 기록' 권한이 필요하지 않습니다.
- DRM으로 보호된 Kindle이나 Apple Books 파일은 지원되지 않습니다.
- 기본 모델은 `gpt-5.5`입니다(OpenAI 사용 시). 사용하는 API 계정에 다른 모델이 필요한 경우 설정에서 변경하세요.
