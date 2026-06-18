# StudyReaderMac

Native macOS study reader for reading a PDF or DRM-free EPUB on the left, writing an answer on the right, and sending the current reading screenshot plus the visible answer text to OpenAI for feedback.

## Run

```bash
swift run StudyReaderMac
```

## Package as a macOS app

```bash
sh Scripts/package-app.sh
open dist/StudyReaderMac.app
```

## Current MVP

- Opens PDF files with PDFKit.
- Opens common DRM-free EPUB files by extracting spine XHTML and rendering it in WebKit.
- Synchronizes left and right scroll positions continuously.
- Stores the OpenAI API key in macOS Keychain.
- Sends the current reader viewport image plus the currently visible answer text to the OpenAI Responses API.
- Saves answer text and analysis history locally in Application Support.
- Version `0.3.0` shows a scrolling answer block list and auto-scrolls it to the current PDF page or EPUB position.
- Version `0.4.0` shows only the current page/position answer while preserving separate saved answers per page.
- Version `0.5.0` quits the app process automatically when the last window is closed.
- Version `0.6.0` uses a continuous answer sheet, so partial PDF page transitions show adjacent answer sections naturally.
- Version `0.7.0` supports dragging PDF/EPUB files from Finder into the app window.
- Version `0.8.0` makes the answer sheet visually continuous and supports clicking lower blank lines to type.
- Version `0.9.0` syncs the answer sheet by current page plus within-page position instead of global scroll percentage.
- Version `0.10.0` adds an explicit window-close observer to terminate the process when no app windows remain.
- Version `0.11.0` adds bidirectional page-based sync and filters stale out-of-range PDF answer pages.
- Version `0.12.0` stabilizes bidirectional sync by preventing feedback loops and aligning reader-driven answers to the current page top.
- Version `0.13.0` keeps each answer page at least viewport-height and restores smooth within-page sync without exposing the next page early.
- Version `0.14.0` fixes right-to-left PDF scrolling by using document-view page frames instead of PDF page coordinate conversion.
- Version `0.15.0` speeds up large document opening and fixes answer-sheet page order/direction with manual top-to-bottom layout.
- Version `0.16.0` keeps the answer sheet on a full virtual document height so large right-side scrolls no longer snap back to page 1.
- Version `0.17.0` makes right-side wheel scrolling follow macOS scroll-direction settings across text and blank answer areas.
- Version `0.18.0` corrects the right-side wheel delta sign so direct answer scrolling matches the system direction.
- Version `0.19.0` aligns the direct right-side wheel movement with the left PDF reader while keeping page sync unchanged.
- Version `0.20.0` suppresses programmatic scroll feedback on both panes so sync updates no longer bounce back to page 1.
- Version `0.21.0` fixes the answer-to-PDF within-page direction so right-side scrolling moves the PDF in the same visual direction.
- Version `0.22.0` lets right-side scrolling escape the first-page edge instead of being clamped at the top.
- Version `0.23.0` scrolls the answer sheet clip view directly so the first page can move into later pages reliably.
- Version `0.24.0` lets the right answer sheet use native macOS scrolling first, with manual fallback only when the system does not move it.
- Version `0.25.0` routes wheel events inside answer text areas directly to the sheet scroller so page 1 can scroll into later pages.
- Version `0.26.0` prevents reader sync updates from immediately pulling the answer sheet back to page 1 during right-side scrolling.
- Version `0.27.0` gives right-side text and blank document areas a direct reference to the sheet scroller so first-page wheel events cannot be lost.
- Version `0.28.0` suppresses delayed PDFKit reader feedback after answer-sheet scrolling so the right side is not pulled back to page 1.
- Version `0.29.0` removes manual right-side wheel delta handling and virtual page swapping; the answer sheet now uses native continuous scrolling.
- Version `0.30.0` aligns right-side answer page heights to the PDF page pitch reported by PDFKit.
- Version `0.31.0` keeps PDF-aligned answer pages at the exact reported page pitch instead of letting text height stretch page boundaries.

## Notes

- The app does not capture other apps' windows, so it does not require Screen Recording permission.
- DRM-protected Kindle/Apple Books files are not supported.
- The default model is `gpt-5.5`; change it in Settings if your API account requires another model.
