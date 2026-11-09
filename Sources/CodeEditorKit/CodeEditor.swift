import SwiftUI
import AppKit

/// SwiftUI code editor for macOS – line numbers, syntax highlighting, themes,
/// current line highlight, auto-indent and auto-closing of brackets and HTML tags.
///
/// ```swift
/// @State private var code = "<?php echo 'Hello'; ?>"
///
/// CodeEditor(text: $code, language: .php,
///            configuration: .init(fontSize: 14, theme: .dracula))
/// ```
public struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var language: CodeLanguage
    var configuration: CodeEditorConfiguration
    var onCursorChange: ((_ line: Int, _ column: Int) -> Void)?
    var onReady: ((NSTextView) -> Void)?

    /// - Parameters:
    ///   - text: Edited text.
    ///   - language: Language for syntax highlighting (`CodeLanguage(fileName:)` detects it from a file name).
    ///   - configuration: Font, theme, indentation and behaviour.
    ///   - onCursorChange: Cursor line and column (1-based) – handy for a status bar.
    ///   - onReady: Gives access to the underlying `NSTextView` (find bar, undo, custom commands).
    public init(text: Binding<String>,
                language: CodeLanguage = .plain,
                configuration: CodeEditorConfiguration = CodeEditorConfiguration(),
                onCursorChange: ((_ line: Int, _ column: Int) -> Void)? = nil,
                onReady: ((NSTextView) -> Void)? = nil) {
        self._text = text
        self.language = language
        self.configuration = configuration
        self.onCursorChange = onCursorChange
        self.onReady = onReady
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        // TextKit 1 – needed for the line number ruler and current line highlight
        let textView = CodeNSTextView(usingTextLayoutManager: false)
        textView.drawsBackground = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width, .height]

        textView.string = text
        textView.delegate = context.coordinator
        scrollView.documentView = textView

        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = configuration.showLineNumbers

        let coordinator = context.coordinator
        coordinator.textView = textView
        coordinator.ruler = ruler
        coordinator.apply(configuration)
        coordinator.reportCursor()
        onReady?(textView)
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        let languageChanged = coordinator.parent.language != language
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }
        if languageChanged {
            coordinator.setLanguage(language)
        }
        if textView.string != text {
            textView.string = text
            coordinator.ruler?.textDidChange()
            coordinator.highlightNow()
        } else if languageChanged {
            coordinator.highlightNow()
        }
        if coordinator.configuration != configuration {
            coordinator.apply(configuration)
        }
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        weak var textView: NSTextView?
        weak var ruler: LineNumberRulerView?
        private(set) var configuration: CodeEditorConfiguration?
        private var theme = CodeTheme.system
        private var paragraph = NSParagraphStyle.default
        private var highlighter: SyntaxHighlighter
        private var pendingHighlight: DispatchWorkItem?

        init(_ parent: CodeEditor) {
            self.parent = parent
            self.highlighter = SyntaxHighlighter(language: parent.language)
        }

        func setLanguage(_ language: CodeLanguage) {
            highlighter = SyntaxHighlighter(language: language)
        }

        // MARK: Appearance

        func apply(_ newConfiguration: CodeEditorConfiguration) {
            let previous = configuration
            configuration = newConfiguration
            guard let textView else { return }

            theme = newConfiguration.theme
            paragraph = newConfiguration.paragraphStyle()
            let font = newConfiguration.font

            textView.backgroundColor = theme.background
            textView.insertionPointColor = theme.text
            textView.font = font
            textView.defaultParagraphStyle = paragraph
            textView.typingAttributes = [.font: font, .foregroundColor: theme.text, .paragraphStyle: paragraph]
            (textView as? CodeNSTextView)?.currentLineColor = newConfiguration.highlightCurrentLine ? theme.currentLine : nil
            textView.enclosingScrollView?.rulersVisible = newConfiguration.showLineNumbers

            if previous?.wrapLines != newConfiguration.wrapLines {
                applyWrap(newConfiguration.wrapLines)
            }
            ruler?.theme = theme
            highlightNow()
            ruler?.needsDisplay = true
            textView.needsDisplay = true
        }

        private func applyWrap(_ wrap: Bool) {
            guard let textView, let scrollView = textView.enclosingScrollView,
                  let container = textView.textContainer else { return }
            if wrap {
                scrollView.hasHorizontalScroller = false
                textView.isHorizontallyResizable = false
                container.widthTracksTextView = true
                textView.frame.size.width = scrollView.contentSize.width
            } else {
                scrollView.hasHorizontalScroller = true
                textView.isHorizontallyResizable = true
                container.widthTracksTextView = false
                container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                 height: CGFloat.greatestFiniteMagnitude)
            }
        }

        // MARK: Text changes

        public func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            ruler?.textDidChange()
            scheduleHighlight()
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            reportCursor()
        }

        func reportCursor() {
            guard let textView, let ruler, let callback = parent.onCursorChange else { return }
            let position = ruler.position(for: textView.selectedRange().location)
            DispatchQueue.main.async { callback(position.line, position.column) }
        }

        func highlightNow() {
            pendingHighlight?.cancel()
            guard let textView, let storage = textView.textStorage else { return }
            let font = configuration?.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
            highlighter.highlight(storage, theme: theme, font: font, paragraph: paragraph)
        }

        private func scheduleHighlight() {
            pendingHighlight?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.highlightNow() }
            pendingHighlight = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }

        // MARK: Auto-closing brackets, quotes and HTML tags

        private static let pairs: [String: String] = ["(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'", "`": "`"]
        private static let closers: Set<String> = [")", "]", "}", "\"", "'", "`"]
        private static let voidTags: Set<String> = ["area", "base", "br", "col", "embed", "hr", "img", "input",
                                                    "link", "meta", "source", "track", "wbr"]
        private static let openTagRegex = try! NSRegularExpression(pattern: #"<([A-Za-z][A-Za-z0-9-]*)(?:\s[^<>]*)?$"#)

        private var autoClosePairs: Bool { configuration?.autoClosePairs ?? true }

        public func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString string: String?) -> Bool {
            guard let string, string.count == 1, !textView.hasMarkedText(),
                  parent.language != .plain, parent.language != .markdown else { return true }
            let text = textView.string as NSString
            let location = range.location
            let next = location < text.length ? text.substring(with: NSRange(location: location, length: 1)) : nil
            let previous = location > 0 ? text.substring(with: NSRange(location: location - 1, length: 1)) : nil

            if autoClosePairs {
                // Closing character already right after the cursor → just step over it
                if range.length == 0, Self.closers.contains(string), next == string {
                    textView.setSelectedRange(NSRange(location: location + 1, length: 0))
                    return false
                }

                if let close = Self.pairs[string] {
                    // Selection → wrap it
                    if range.length > 0 {
                        let selected = text.substring(with: range)
                        textView.insertText(string + selected + close, replacementRange: range)
                        textView.setSelectedRange(NSRange(location: location + 1, length: (selected as NSString).length))
                        return false
                    }
                    let isQuote = string == close
                    // Apostrophe inside a word (it's) – do not pair
                    if isQuote, let previous, previous.rangeOfCharacter(from: .alphanumerics) != nil { return true }
                    let nextAllows = next == nil || next!.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
                        || ")]}>,;:".contains(next!)
                    guard nextAllows else { return true }
                    textView.insertText(string + close, replacementRange: range)
                    textView.setSelectedRange(NSRange(location: location + 1, length: 0))
                    return false
                }
            }

            // HTML: typing ">" after an opening tag inserts the closing tag
            if configuration?.autoCloseTags ?? true, string == ">", range.length == 0,
               [.html, .php, .xml].contains(parent.language) {
                let lineStart = text.lineRange(for: NSRange(location: location, length: 0)).location
                let before = text.substring(with: NSRange(location: lineStart, length: location - lineStart))
                if !before.hasSuffix("/"), !before.hasSuffix("-"), !before.hasSuffix("?"),
                   let match = Self.openTagRegex.firstMatch(in: before, range: NSRange(location: 0, length: (before as NSString).length)) {
                    let tag = (before as NSString).substring(with: match.range(at: 1))
                    if !Self.voidTags.contains(tag.lowercased()) {
                        textView.insertText("></" + tag + ">", replacementRange: range)
                        textView.setSelectedRange(NSRange(location: location + 1, length: 0))
                        return false
                    }
                }
            }
            return true
        }

        // MARK: Keys – Return, Backspace, Tab, Shift-Tab

        public func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let indent = configuration?.indentString ?? "\t"
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                // Return keeps the indentation of the current line
                let content = textView.string as NSString
                let selection = textView.selectedRange()
                let lineRange = content.lineRange(for: NSRange(location: selection.location, length: 0))
                let beforeCursor = content.substring(with: NSRange(location: lineRange.location,
                                                                   length: selection.location - lineRange.location))
                let leading = String(beforeCursor.prefix { $0 == " " || $0 == "\t" })
                // Between {} / [] / () / <div></div> → cursor on a new indented line
                if autoClosePairs, selection.length == 0, selection.location > 0,
                   selection.location < content.length {
                    let previous = content.substring(with: NSRange(location: selection.location - 1, length: 1))
                    let next = content.substring(with: NSRange(location: selection.location, length: 1))
                    let between = (previous == "{" && next == "}") || (previous == "[" && next == "]")
                        || (previous == "(" && next == ")") || (previous == ">" && next == "<"
                            && content.length > selection.location + 1
                            && content.substring(with: NSRange(location: selection.location + 1, length: 1)) == "/")
                    if between {
                        textView.insertText("\n" + leading + indent + "\n" + leading, replacementRange: selection)
                        let cursor = selection.location + 1 + (leading as NSString).length + (indent as NSString).length
                        textView.setSelectedRange(NSRange(location: cursor, length: 0))
                        return true
                    }
                }
                textView.insertText("\n" + leading, replacementRange: selection)
                return true

            case #selector(NSResponder.deleteBackward(_:)):
                // Backspace inside an empty pair deletes both halves: (|) → |
                let content = textView.string as NSString
                let selection = textView.selectedRange()
                guard autoClosePairs, selection.length == 0, selection.location > 0,
                      selection.location < content.length else { return false }
                let previous = content.substring(with: NSRange(location: selection.location - 1, length: 1))
                let next = content.substring(with: NSRange(location: selection.location, length: 1))
                if let close = Self.pairs[previous], close == next {
                    textView.insertText("", replacementRange: NSRange(location: selection.location - 1, length: 2))
                    return true
                }
                return false

            case #selector(NSResponder.insertTab(_:)):
                // Tab with a multi-line selection indents the lines, otherwise inserts a tab / spaces
                let content = textView.string as NSString
                let selection = textView.selectedRange()
                if selection.length > 0, content.substring(with: selection).contains("\n") {
                    Indentation.shift(textView, indent: indent, outdent: false)
                } else {
                    textView.insertText(indent, replacementRange: selection)
                }
                return true

            case #selector(NSResponder.insertBacktab(_:)):
                Indentation.shift(textView, indent: indent, outdent: true)
                return true

            default:
                return false
            }
        }
    }
}

/// Indent / outdent of the selected lines (undoable).
enum Indentation {
    static func shift(_ textView: NSTextView, indent: String, outdent: Bool) {
        let content = textView.string as NSString
        let lineRange = content.lineRange(for: textView.selectedRange())
        let block = content.substring(with: lineRange)
        let endsWithNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if endsWithNewline { lines.removeLast() }

        let width = indent == "\t" ? 4 : indent.count
        let changed = lines.map { line -> String in
            if !outdent { return line.isEmpty ? line : indent + line }
            if line.hasPrefix("\t") { return String(line.dropFirst()) }
            let spaces = line.prefix { $0 == " " }.count
            return String(line.dropFirst(min(spaces, width)))
        }
        let result = changed.joined(separator: "\n") + (endsWithNewline ? "\n" : "")
        guard textView.shouldChangeText(in: lineRange, replacementString: result) else { return }
        textView.replaceCharacters(in: lineRange, with: result)
        textView.didChangeText()
        let length = (result as NSString).length - (endsWithNewline ? 1 : 0)
        textView.setSelectedRange(NSRange(location: lineRange.location, length: max(0, length)))
    }
}
