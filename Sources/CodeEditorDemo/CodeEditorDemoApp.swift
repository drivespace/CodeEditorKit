import SwiftUI
import AppKit
import CodeEditorKit

/// Demo app – open Package.swift in Xcode, choose the "CodeEditorDemo" scheme and press ⌘R.
@main
struct CodeEditorDemoApp: App {
    init() {
        // Started from Swift Package Manager → behave like a normal app with a Dock icon and a window
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApplication.shared.activate() }
    }

    var body: some Scene {
        WindowGroup("CodeEditorKit Demo") {
            DemoView()
                .frame(minWidth: 820, minHeight: 540)
        }
    }
}

struct DemoView: View {
    @State private var language: CodeLanguage = .php
    @State private var text = Samples.text(for: .php)
    @State private var theme: CodeTheme = .dracula
    @State private var fontSize: CGFloat = 14
    @State private var wrapLines = false
    @State private var highlightLine = true
    @State private var line = 1
    @State private var column = 1

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Picker("Language", selection: $language) {
                    ForEach(CodeLanguage.allCases) { Text($0.title).tag($0) }
                }
                .fixedSize()
                Picker("Theme", selection: $theme) {
                    ForEach(CodeTheme.all) { Text($0.name).tag($0) }
                }
                .fixedSize()
                Stepper("Font \(Int(fontSize)) pt", value: $fontSize, in: 9...28)
                    .fixedSize()
                Toggle("Wrap lines", isOn: $wrapLines)
                Toggle("Current line", isOn: $highlightLine)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            CodeEditor(text: $text,
                       language: language,
                       configuration: CodeEditorConfiguration(fontSize: fontSize,
                                                              theme: theme,
                                                              highlightCurrentLine: highlightLine,
                                                              wrapLines: wrapLines),
                       onCursorChange: { newLine, newColumn in
                           line = newLine
                           column = newColumn
                       })

            Divider()

            HStack {
                Text("Ln \(line), Col \(column)")
                Spacer()
                Text("\(language.title) · \(text.count) characters")
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .onChange(of: language) { _, newLanguage in
            text = Samples.text(for: newLanguage)
        }
    }
}
