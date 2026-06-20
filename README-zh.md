# StudyReaderMac

[English](README.md) | [简体中文](README-zh.md) | [日本語](README-ja.md) | [한국어](README-ko.md) | [Español](README-es.md) | [Français](README-fr.md) | [Deutsch](README-de.md)

StudyReaderMac 是一款专为学生和学习者设计的 macOS 原生学习工具。它让你能够方便地在 Mac 上学习 PDF 教材或无 DRM 的 EPUB 书籍，完全不再需要厚重的实体纸质书。

## 为什么选择 StudyReaderMac？
传统的学习往往需要你在纸质书、笔记本和参考资料之间来回切换。StudyReaderMac 通过提供双窗格界面极大地简化了这一过程：
- **左侧窗格（阅读）：** 直接阅读你的 PDF 或 EPUB 教材。
- **右侧窗格（作答）：** 写下你的答案、笔记或解题步骤。
- **AI 智能校验：** 完成作答后，应用会截取你当前正在阅读的教材内容以及你的答案，发送给 OpenAI（或兼容的 DeepSeek/Ollama API），以检验你的正确性并提供即时反馈。

这让学习和验证答案变得无缝、高效且完全无纸化——非常适合准备考试的学生或任何学习新知识的人。

## 功能特色
- **无纸化学习：** 抛弃沉重的纸质书和笔记本。阅读、作答、校验，一切都在一个应用内完成。
- **AI 即时反馈：** 根据当前教材可见内容，获取 AI 对你书面答案的即时批改和解释。
- **连续滚动与同步：** 阅读窗格和答题纸自动同步，防止迷失进度。
- **多 API 厂商支持：** 预设 OpenAI、DeepSeek 和 Ollama，或使用你自己的自定义接口。
- **多语言支持：** 界面支持英文、中文、日文、韩文、西班牙文、法文和德文。

## API 配置指南
StudyReaderMac 允许你使用不同的 AI 模型来检验你的答案。请在**设置**中配置你喜欢的 API 厂商：

- **OpenAI:** 
  - 在 API 厂商列表中选择“OpenAI”。
  - 填入你的 OpenAI API Key。
  - 默认模型为 `gpt-5.5`。
- **DeepSeek:**
  - 选择“DeepSeek”。
  - 填入你的 DeepSeek API Key。
  - 默认模型为 `deepseek-v4-flash`。
- **Ollama (本地大模型):**
  - 请确保你的电脑上正在运行 Ollama。
  - 选择“Ollama”，API 地址会自动填充为 `http://localhost:11434/v1/chat/completions`。
  - 默认模型为 `llama3`（请确保你已经在终端运行过 `ollama run llama3`）。
  - **注意：** 应用要求必须填写 API Key，对于 Ollama，你只需随意输入任意字符（例如 `ollama`）即可。
- **自定义 / LM Studio:**
  - 选择“自定义”。
  - 填入兼容的接口地址（例如使用 LM Studio 时填入 `http://localhost:1234/v1/chat/completions`）。
  - 填入准确的模型名称。
  - 填入你的 API Key（如果是无验证的本地模型，填入任意占位符即可）。

## 运行

```bash
swift run StudyReaderMac
```

## 打包为 macOS 应用

```bash
sh Scripts/package-app.sh
open dist/StudyReaderMac.app
```

## 注意事项

- 本应用不会截取其他应用的窗口，因此不需要“屏幕录制”权限。
- 不支持受 DRM 保护的 Kindle 或 Apple Books 文件。
- 默认模型为 `gpt-5.5`（使用 OpenAI 时）；如果您的 API 账号需要其他模型，请在设置中进行更改。
