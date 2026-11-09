import XCTest
import AppKit
@testable import CodeEditorKit

final class CodeLanguageTests: XCTestCase {
    func testDetectsLanguageFromFileName() {
        XCTAssertEqual(CodeLanguage(fileName: "index.php"), .php)
        XCTAssertEqual(CodeLanguage(fileName: ".htaccess"), .apache)
        XCTAssertEqual(CodeLanguage(fileName: "style.SCSS"), .css)
        XCTAssertEqual(CodeLanguage(fileName: "app.tsx"), .javascript)
        XCTAssertEqual(CodeLanguage(fileName: "README"), .plain)
    }
}

final class SyntaxHighlighterTests: XCTestCase {
    private func highlighted(_ code: String, as language: CodeLanguage) -> NSTextStorage {
        let storage = NSTextStorage(string: code)
        SyntaxHighlighter(language: language).highlight(
            storage, theme: .dracula,
            font: .monospacedSystemFont(ofSize: 12, weight: .regular),
            paragraph: .default)
        return storage
    }

    private func color(in storage: NSTextStorage, at index: Int) -> NSColor? {
        storage.attribute(.foregroundColor, at: index, effectiveRange: nil) as? NSColor
    }

    func testPHPVariableIsHighlighted() {
        let storage = highlighted("<?php $name = 'World'; ?>", as: .php)
        XCTAssertEqual(color(in: storage, at: 6), CodeTheme.dracula.color(for: .variable))   // $name
    }

    func testCSSCommentIsHighlighted() {
        let storage = highlighted("/* note */ body { color: red; }", as: .css)
        XCTAssertEqual(color(in: storage, at: 3), CodeTheme.dracula.color(for: .comment))
    }

    func testPlainTextHasNoColors() {
        let storage = highlighted("function test() {}", as: .plain)
        XCTAssertEqual(color(in: storage, at: 0), CodeTheme.dracula.text)
    }
}
