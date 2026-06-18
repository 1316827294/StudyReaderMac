import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var syncFraction = 0.0
    @State private var currentAnchor = PositionAnchor.start
    @State private var answerScrollTarget = AnswerScrollTarget.start
    @State private var answerPageHeights: [String: CGFloat] = [:]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HSplitView {
                DocumentPane(syncFraction: $syncFraction)
                    .environmentObject(appModel)
                    .modifier(DocumentAnchorBinder(anchor: $currentAnchor))
                    .modifier(AnswerScrollTargetBinder(target: $answerScrollTarget))
                    .modifier(AnswerPageHeightsBinder(pageHeights: $answerPageHeights))
                    .frame(minWidth: 420)

                AnswerPane(
                    syncFraction: $syncFraction,
                    currentAnchor: $currentAnchor,
                    answerScrollTarget: $answerScrollTarget,
                    answerPageHeights: $answerPageHeights
                )
                    .environmentObject(appModel)
                    .frame(minWidth: 420)
            }
            Divider()
            statusBar
        }
        .sheet(isPresented: $appModel.showingSettings) {
            SettingsView()
                .environmentObject(appModel)
        }
        .onChange(of: appModel.answerText) {
            appModel.persistCurrentSession(readingFraction: syncFraction)
        }
        .onChange(of: syncFraction) {
            appModel.updateReadingPosition(fraction: syncFraction, anchor: currentAnchor)
        }
        .onChange(of: currentAnchor) {
            appModel.updateReadingPosition(fraction: syncFraction, anchor: currentAnchor)
        }
        .onChange(of: appModel.documentURL) {
                    syncFraction = appModel.restoredReadingFraction
                    currentAnchor = appModel.currentAnchor
                    answerScrollTarget = AnswerScrollTarget(anchor: appModel.currentAnchor, fractionWithinAnchor: 0)
                    answerPageHeights = [:]
                }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            appModel.handleDroppedProviders(providers)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                appModel.openDocument()
            } label: {
                Label("Open", systemImage: "folder")
            }
            .buttonStyle(.bordered)

            Button {
                appModel.runCheck(readingFraction: syncFraction)
            } label: {
                if appModel.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Check", systemImage: "checkmark.seal")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(appModel.documentURL == nil || appModel.isChecking)

            Button {
                appModel.showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("v0.31 Strict-align")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())

            Text(appModel.documentURL?.lastPathComponent ?? "No document")
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var statusBar: some View {
        HStack {
            Text(appModel.statusText)
                .lineLimit(1)
            Spacer()
            Text("\(Int(syncFraction * 100))%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(appModel.currentAnchor.label)
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

private struct DocumentPane: View {
    @EnvironmentObject private var appModel: AppModel
    @Binding var syncFraction: Double
    @Environment(\.documentAnchorBinding) private var anchor
    @Environment(\.answerScrollTargetBinding) private var answerScrollTarget
    @Environment(\.answerPageHeightsBinding) private var answerPageHeights

    var body: some View {
        VStack(spacing: 0) {
            paneHeader("Reading", systemImage: "book")

            Group {
                switch appModel.documentKind {
                case .pdf:
                    PDFReaderView(
                        url: appModel.documentURL,
                        syncFraction: $syncFraction,
                        currentAnchor: anchor,
                        answerScrollTarget: answerScrollTarget,
                        onAnchorsChanged: appModel.updateAvailableAnchors,
                        onPageHeightsChanged: { answerPageHeights.wrappedValue = $0 },
                        viewport: appModel.documentViewport
                    )
                case .epub:
                    EPUBReaderView(
                        url: appModel.documentURL,
                        syncFraction: $syncFraction,
                        currentAnchor: anchor,
                        answerScrollTarget: answerScrollTarget,
                        onAnchorsChanged: appModel.updateAvailableAnchors,
                        viewport: appModel.documentViewport
                    )
                case nil:
                    EmptyDocumentView()
                }
            }
        }
    }
}

private struct AnswerPane: View {
    @EnvironmentObject private var appModel: AppModel
    @Binding var syncFraction: Double
    @Binding var currentAnchor: PositionAnchor
    @Binding var answerScrollTarget: AnswerScrollTarget
    @Binding var answerPageHeights: [String: CGFloat]

    var body: some View {
        VStack(spacing: 0) {
            paneHeader("Answer Sheet - \(currentAnchor.label)", systemImage: "keyboard")
            SyncedAnswerSheetView(
                blocks: appModel.answerBlocks,
                currentAnchor: currentAnchor,
                scrollTarget: answerScrollTarget,
                pageHeights: appModel.documentKind == .pdf ? answerPageHeights : [:],
                onTextChanged: { anchor, text in
                    appModel.setAnswer(text, for: anchor, readingFraction: syncFraction)
                },
                onScrollTargetChanged: { target in
                    answerScrollTarget = target
                    currentAnchor = target.anchor
                }
            )
            .frame(minHeight: 520)
        }
    }
}

private struct DocumentAnchorBindingKey: EnvironmentKey {
    static let defaultValue: Binding<PositionAnchor> = .constant(.start)
}

private struct AnswerScrollTargetBindingKey: EnvironmentKey {
    static let defaultValue: Binding<AnswerScrollTarget> = .constant(.start)
}

private struct AnswerPageHeightsBindingKey: EnvironmentKey {
    static let defaultValue: Binding<[String: CGFloat]> = .constant([:])
}

private extension EnvironmentValues {
    var documentAnchorBinding: Binding<PositionAnchor> {
        get { self[DocumentAnchorBindingKey.self] }
        set { self[DocumentAnchorBindingKey.self] = newValue }
    }

    var answerScrollTargetBinding: Binding<AnswerScrollTarget> {
        get { self[AnswerScrollTargetBindingKey.self] }
        set { self[AnswerScrollTargetBindingKey.self] = newValue }
    }

    var answerPageHeightsBinding: Binding<[String: CGFloat]> {
        get { self[AnswerPageHeightsBindingKey.self] }
        set { self[AnswerPageHeightsBindingKey.self] = newValue }
    }
}

private struct DocumentAnchorBinder: ViewModifier {
    @Binding var anchor: PositionAnchor

    func body(content: Content) -> some View {
        content.environment(\.documentAnchorBinding, $anchor)
    }
}

private struct AnswerScrollTargetBinder: ViewModifier {
    @Binding var target: AnswerScrollTarget

    func body(content: Content) -> some View {
        content.environment(\.answerScrollTargetBinding, $target)
    }
}

private struct AnswerPageHeightsBinder: ViewModifier {
    @Binding var pageHeights: [String: CGFloat]

    func body(content: Content) -> some View {
        content.environment(\.answerPageHeightsBinding, $pageHeights)
    }
}

private func paneHeader(_ title: String, systemImage: String) -> some View {
    HStack {
        Label(title, systemImage: systemImage)
            .font(.headline)
        Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(.bar)
}

private struct EmptyDocumentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 54))
                .foregroundStyle(.secondary)
            Text("Open a PDF or DRM-free EPUB")
                .font(.title3)
            Text("The app reads documents inside this window so it can capture only the current reading viewport.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
