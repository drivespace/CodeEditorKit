import AppKit

/// Appearance and behaviour of `CodeEditor`.
public struct CodeEditorConfiguration: Equatable {
    /// PostScript name of the font. `nil` = SF Mono (system monospaced font).
    public var fontName: String?
    public var fontSize: CGFloat
    /// Line height multiple (1.0 = default).
    public var lineSpacing: CGFloat
    public var theme: CodeTheme
    public var tabWidth: Int
    /// Indent with spaces instead of tab characters.
    public var useSpaces: Bool
    public var highlightCurrentLine: Bool
    public var wrapLines: Bool
    public var showLineNumbers: Bool
    /// Auto-close brackets and quotes, wrap a selection in them.
    public var autoClosePairs: Bool
    /// HTML / PHP / XML: typing `>` after an opening tag inserts the closing tag.
    public var autoCloseTags: Bool

    public init(fontName: String? = nil,
                fontSize: CGFloat = 13,
                lineSpacing: CGFloat = 1.15,
                theme: CodeTheme = .system,
                tabWidth: Int = 4,
                useSpaces: Bool = false,
                highlightCurrentLine: Bool = true,
                wrapLines: Bool = false,
                showLineNumbers: Bool = true,
                autoClosePairs: Bool = true,
                autoCloseTags: Bool = true) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.theme = theme
        self.tabWidth = tabWidth
        self.useSpaces = useSpaces
        self.highlightCurrentLine = highlightCurrentLine
        self.wrapLines = wrapLines
        self.showLineNumbers = showLineNumbers
        self.autoClosePairs = autoClosePairs
        self.autoCloseTags = autoCloseTags
    }

    var font: NSFont {
        if let fontName, let font = NSFont(name: fontName, size: fontSize) { return font }
        return .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    var indentString: String {
        useSpaces ? String(repeating: " ", count: max(1, tabWidth)) : "\t"
    }

    func paragraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineSpacing
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        style.tabStops = []
        style.defaultTabInterval = spaceWidth * CGFloat(max(1, tabWidth))
        return style
    }
}
