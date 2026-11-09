import AppKit

/// Kind of text the highlighter recognises – the actual colour comes from the theme.
public enum CodeTokenKind: Hashable, CaseIterable, Sendable {
    case keyword, string, comment, number, variable, function, tag, attribute, property, delimiter
}

/// Colour theme of the editor. Use one of the built-in themes or create your own.
public struct CodeTheme: Hashable, Identifiable {
    public var name: String
    public var background: NSColor
    public var text: NSColor
    public var currentLine: NSColor
    public var gutterBackground: NSColor
    public var gutterText: NSColor
    public var tokens: [CodeTokenKind: NSColor]

    public var id: String { name }

    public init(name: String, background: NSColor, text: NSColor, currentLine: NSColor,
                gutterBackground: NSColor, gutterText: NSColor, tokens: [CodeTokenKind: NSColor]) {
        self.name = name
        self.background = background
        self.text = text
        self.currentLine = currentLine
        self.gutterBackground = gutterBackground
        self.gutterText = gutterText
        self.tokens = tokens
    }

    /// Colour for a token kind (falls back to the text colour).
    public func color(for kind: CodeTokenKind) -> NSColor { tokens[kind] ?? text }

    /// All built-in themes.
    public static let all: [CodeTheme] = [.system, .classic, .solarizedLight, .solarizedDark, .monokai, .dracula]

    /// Follows the system light / dark appearance.
    public static let system = CodeTheme(
        name: "System",
        background: .textBackgroundColor,
        text: .textColor,
        currentLine: NSColor.controlAccentColor.withAlphaComponent(0.08),
        gutterBackground: .textBackgroundColor,
        gutterText: .secondaryLabelColor,
        tokens: [
            .keyword: .systemPink, .string: .systemRed, .comment: .systemGray,
            .number: .systemPurple, .variable: .systemTeal, .function: .systemBlue,
            .tag: .systemBlue, .attribute: .systemOrange, .property: .systemTeal,
            .delimiter: .systemOrange,
        ])

    /// Classic light theme inspired by PSPad.
    public static let classic = CodeTheme(
        name: "Classic",
        background: .hex(0xFFFFFF), text: .hex(0x000000), currentLine: .hex(0xFFFBD6),
        gutterBackground: .hex(0xF0F0F0), gutterText: .hex(0x808080),
        tokens: [
            .keyword: .hex(0x0000C8), .string: .hex(0xC80000), .comment: .hex(0x008000),
            .number: .hex(0xFF0000), .variable: .hex(0x800080), .function: .hex(0x000080),
            .tag: .hex(0x000080), .attribute: .hex(0xC80000), .property: .hex(0x0000C8),
            .delimiter: .hex(0xFF0000),
        ])

    public static let solarizedLight = CodeTheme(
        name: "Solarized Light",
        background: .hex(0xFDF6E3), text: .hex(0x586E75), currentLine: .hex(0xEEE8D5),
        gutterBackground: .hex(0xEEE8D5), gutterText: .hex(0x93A1A1),
        tokens: [
            .keyword: .hex(0x859900), .string: .hex(0x2AA198), .comment: .hex(0x93A1A1),
            .number: .hex(0xD33682), .variable: .hex(0x268BD2), .function: .hex(0x268BD2),
            .tag: .hex(0x268BD2), .attribute: .hex(0xB58900), .property: .hex(0xCB4B16),
            .delimiter: .hex(0xDC322F),
        ])

    public static let solarizedDark = CodeTheme(
        name: "Solarized Dark",
        background: .hex(0x002B36), text: .hex(0x93A1A1), currentLine: .hex(0x073642),
        gutterBackground: .hex(0x073642), gutterText: .hex(0x586E75),
        tokens: [
            .keyword: .hex(0x859900), .string: .hex(0x2AA198), .comment: .hex(0x586E75),
            .number: .hex(0xD33682), .variable: .hex(0x268BD2), .function: .hex(0x268BD2),
            .tag: .hex(0x268BD2), .attribute: .hex(0xB58900), .property: .hex(0xCB4B16),
            .delimiter: .hex(0xDC322F),
        ])

    public static let monokai = CodeTheme(
        name: "Monokai",
        background: .hex(0x272822), text: .hex(0xF8F8F2), currentLine: .hex(0x3E3D32),
        gutterBackground: .hex(0x272822), gutterText: .hex(0x90908A),
        tokens: [
            .keyword: .hex(0xF92672), .string: .hex(0xE6DB74), .comment: .hex(0x75715E),
            .number: .hex(0xAE81FF), .variable: .hex(0xFD971F), .function: .hex(0xA6E22E),
            .tag: .hex(0xF92672), .attribute: .hex(0xA6E22E), .property: .hex(0x66D9EF),
            .delimiter: .hex(0xFD971F),
        ])

    public static let dracula = CodeTheme(
        name: "Dracula",
        background: .hex(0x282A36), text: .hex(0xF8F8F2), currentLine: .hex(0x44475A),
        gutterBackground: .hex(0x282A36), gutterText: .hex(0x6272A4),
        tokens: [
            .keyword: .hex(0xFF79C6), .string: .hex(0xF1FA8C), .comment: .hex(0x6272A4),
            .number: .hex(0xBD93F9), .variable: .hex(0xFFB86C), .function: .hex(0x50FA7B),
            .tag: .hex(0xFF79C6), .attribute: .hex(0x50FA7B), .property: .hex(0x8BE9FD),
            .delimiter: .hex(0xFFB86C),
        ])
}

extension NSColor {
    /// Colour from a 0xRRGGBB value.
    static func hex(_ value: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1)
    }
}
