import AppKit

/// One rule: a regular expression + colour. If the pattern has capture groups,
/// each group is coloured (colors[0] = group 1, …), otherwise the whole match.
struct SyntaxRule {
    let regex: NSRegularExpression
    let colors: [CodeTokenKind]

    init?(_ pattern: String, _ colors: CodeTokenKind..., options: NSRegularExpression.Options = []) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            assertionFailure("Invalid regex: \(pattern)")
            return nil
        }
        self.regex = regex
        self.colors = colors
    }
}

/// Nested region with a different grammar (e.g. <?php … ?> or <style> inside HTML).
struct SyntaxRegion {
    let regex: NSRegularExpression   // group 1 = region content
    let grammar: SyntaxGrammar
    let delimiterColor: CodeTokenKind?
}

final class SyntaxGrammar {
    let rules: [SyntaxRule]
    let regions: [SyntaxRegion]

    init(rules: [SyntaxRule?], regions: [SyntaxRegion] = []) {
        self.rules = rules.compactMap { $0 }
        self.regions = regions
    }
}

/// Token kinds – the actual colour comes from the theme (CodeTheme).
typealias SyntaxColor = CodeTokenKind

final class SyntaxHighlighter {
    /// Larger files are not highlighted to keep the editor fast.
    static let maxLength = 1_500_000

    private let grammar: SyntaxGrammar?

    init(language: CodeLanguage) {
        grammar = Grammars.grammar(for: language)
    }

    /// Applies font, line spacing and colours of the theme to the whole text.
    func highlight(_ storage: NSTextStorage, theme: CodeTheme, font: NSFont, paragraph: NSParagraphStyle) {
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.addAttributes([
            .font: font,
            .paragraphStyle: paragraph,
            .foregroundColor: theme.text,
        ], range: full)
        if let grammar, full.length <= Self.maxLength {
            apply(grammar, to: storage, in: full, text: storage.string, theme: theme)
        }
        storage.endEditing()
    }

    private func apply(_ grammar: SyntaxGrammar, to storage: NSTextStorage, in range: NSRange,
                       text: String, theme: CodeTheme) {
        storage.addAttribute(.foregroundColor, value: theme.text, range: range)

        for rule in grammar.rules {
            rule.regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match else { return }
                if match.numberOfRanges > 1 {
                    for group in 1..<match.numberOfRanges where group - 1 < rule.colors.count {
                        let groupRange = match.range(at: group)
                        if groupRange.location != NSNotFound, groupRange.length > 0 {
                            storage.addAttribute(.foregroundColor, value: theme.color(for: rule.colors[group - 1]),
                                                 range: groupRange)
                        }
                    }
                } else if let kind = rule.colors.first {
                    storage.addAttribute(.foregroundColor, value: theme.color(for: kind), range: match.range)
                }
            }
        }

        for region in grammar.regions {
            region.regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match else { return }
                if let kind = region.delimiterColor {
                    storage.addAttribute(.foregroundColor, value: theme.color(for: kind), range: match.range)
                }
                let inner = match.range(at: 1)
                if inner.location != NSNotFound, inner.length > 0 {
                    apply(region.grammar, to: storage, in: inner, text: text, theme: theme)
                }
            }
        }
    }
}

/// Language definitions.
enum Grammars {
    static func grammar(for language: CodeLanguage) -> SyntaxGrammar? {
        switch language {
        case .php: return php
        case .html: return html
        case .css: return css
        case .javascript: return javascript
        case .json: return json
        case .apache: return apache
        case .sql: return sql
        case .xml: return xml
        case .markdown: return markdown
        case .plain: return nil
        }
    }

    private static func regex(_ pattern: String, _ options: NSRegularExpression.Options = []) -> NSRegularExpression {
        // Patterns are hard-coded – an invalid one shows up immediately during development.
        try! NSRegularExpression(pattern: pattern, options: options)
    }

    private static let number = SyntaxRule(#"\b\d+(?:\.\d+)?\b"#, SyntaxColor.number)
    private static let functionCall = SyntaxRule(#"\b([A-Za-z_][A-Za-z0-9_]*)(?=\s*\()"#, SyntaxColor.function)

    // MARK: HTML / XML

    private static let markupRules: [SyntaxRule?] = [
        SyntaxRule(#"</?[A-Za-z][\w:.-]*|(?<![-=])/?>"#, SyntaxColor.tag),
        SyntaxRule(#"\s([A-Za-z_:@][\w:.@-]*)(?=\s*=)"#, SyntaxColor.attribute),
        SyntaxRule(#"=\s*("[^"]*"|'[^']*')"#, SyntaxColor.string),
        SyntaxRule(#"&[A-Za-z0-9#]+;"#, SyntaxColor.number),
        SyntaxRule(#"<!DOCTYPE[^>]*>|<!\[CDATA\[|\]\]>"#, SyntaxColor.keyword, options: [.caseInsensitive]),
        SyntaxRule(#"<!--[\s\S]*?-->"#, SyntaxColor.comment),
    ]

    private static var embeddedRegions: [SyntaxRegion] {
        [
            SyntaxRegion(regex: regex(#"<style\b[^>]*>([\s\S]*?)(?=</style>|\z)"#, [.caseInsensitive]),
                         grammar: css, delimiterColor: nil),
            SyntaxRegion(regex: regex(#"<script\b[^>]*>([\s\S]*?)(?=</script>|\z)"#, [.caseInsensitive]),
                         grammar: javascript, delimiterColor: nil),
        ]
    }

    static let html = SyntaxGrammar(rules: markupRules, regions: embeddedRegions)
    static let xml = SyntaxGrammar(rules: markupRules)

    // MARK: PHP

    private static let phpCode = SyntaxGrammar(rules: [
        number,
        functionCall,
        SyntaxRule(#"\b(?:abstract|and|array|as|break|callable|case|catch|class|clone|const|continue|declare|default|do|echo|else|elseif|empty|enddeclare|endfor|endforeach|endif|endswitch|endwhile|enum|extends|final|finally|fn|for|foreach|function|global|goto|if|implements|include|include_once|instanceof|insteadof|interface|isset|list|match|namespace|new|or|print|private|protected|public|readonly|require|require_once|return|static|switch|throw|trait|try|unset|use|var|while|xor|yield|true|false|null|self|parent)\b"#,
                   SyntaxColor.keyword, options: [.caseInsensitive]),
        SyntaxRule(#"\$[A-Za-z_][A-Za-z0-9_]*"#, SyntaxColor.variable),
        // strings and comments in one pass – whichever starts first wins
        SyntaxRule(#"("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')|(//[^\n]*?(?=\?>|\n|\z)|#(?!\[)[^\n]*?(?=\?>|\n|\z)|/\*[\s\S]*?\*/)"#,
                   SyntaxColor.string, SyntaxColor.comment),
    ])

    static let php = SyntaxGrammar(rules: markupRules, regions: embeddedRegions + [
        SyntaxRegion(regex: regex(#"<\?(?:php\b|=)?([\s\S]*?)(?:\?>|\z)"#), grammar: phpCode, delimiterColor: SyntaxColor.delimiter),
    ])

    // MARK: CSS

    static let css = SyntaxGrammar(rules: [
        SyntaxRule(#"-?\b\d+(?:\.\d+)?(?:px|em|rem|%|vh|vw|vmin|vmax|s|ms|deg|fr|ch|ex|pt)?\b"#, SyntaxColor.number),
        SyntaxRule(#"#[0-9a-fA-F]{3,8}\b(?![\w-]*\s*[{,])"#, SyntaxColor.number),
        SyntaxRule(#"([A-Za-z-]+)(?=\s*:[^{};]*[;}])"#, SyntaxColor.property),
        SyntaxRule(#"@[\w-]+|!important"#, SyntaxColor.keyword),
        SyntaxRule(#"("[^"\n]*"|'[^'\n]*')|(/\*[\s\S]*?\*/)"#, SyntaxColor.string, SyntaxColor.comment),
    ])

    // MARK: JavaScript

    static let javascript = SyntaxGrammar(rules: [
        number,
        functionCall,
        SyntaxRule(#"\b(?:async|await|break|case|catch|class|const|continue|debugger|default|delete|do|else|export|extends|finally|for|from|function|if|import|in|instanceof|let|new|of|return|super|switch|this|throw|try|typeof|var|void|while|with|yield|true|false|null|undefined)\b"#,
                   SyntaxColor.keyword),
        SyntaxRule(#"("(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\]|\\.)*`)|(//[^\n]*|/\*[\s\S]*?\*/)"#,
                   SyntaxColor.string, SyntaxColor.comment),
    ])

    // MARK: JSON

    static let json = SyntaxGrammar(rules: [
        number,
        SyntaxRule(#"\b(?:true|false|null)\b"#, SyntaxColor.keyword),
        SyntaxRule(#""(?:[^"\\]|\\.)*""#, SyntaxColor.string),
        SyntaxRule(#"("(?:[^"\\]|\\.)*")(?=\s*:)"#, SyntaxColor.attribute),
    ])

    // MARK: Apache (.htaccess)

    static let apache = SyntaxGrammar(rules: [
        SyntaxRule(#"^\s*([A-Za-z][A-Za-z0-9]*)"#, SyntaxColor.keyword, options: [.anchorsMatchLines]),
        SyntaxRule(#"</?[A-Za-z]+[^>\n]*>"#, SyntaxColor.tag),
        SyntaxRule(#"\[[A-Za-z0-9,=_: -]+\]$"#, SyntaxColor.attribute, options: [.anchorsMatchLines]),
        SyntaxRule(#"%\{[A-Za-z_:]+\}|\$\d"#, SyntaxColor.variable),
        SyntaxRule(#"("[^"\n]*")|(^\s*#[^\n]*)"#, SyntaxColor.string, SyntaxColor.comment, options: [.anchorsMatchLines]),
    ])

    // MARK: SQL

    static let sql = SyntaxGrammar(rules: [
        number,
        SyntaxRule(#"\b(?:select|from|where|and|or|not|insert|into|values|update|set|delete|create|table|drop|alter|add|index|primary|key|foreign|references|join|left|right|inner|outer|on|as|order|by|group|having|limit|offset|distinct|null|is|in|like|between|exists|union|all|default|auto_increment|engine|charset|collate|if|unique|int|integer|bigint|varchar|text|longtext|datetime|timestamp|date|decimal|float|double|tinyint|boolean|enum|unsigned|not)\b"#,
                   SyntaxColor.keyword, options: [.caseInsensitive]),
        SyntaxRule(#"`[^`\n]*`"#, SyntaxColor.attribute),
        SyntaxRule(#"('(?:[^'\\]|\\.|'')*'|"(?:[^"\\]|\\.)*")|(--[^\n]*|#[^\n]*|/\*[\s\S]*?\*/)"#,
                   SyntaxColor.string, SyntaxColor.comment),
    ])

    // MARK: Markdown

    static let markdown = SyntaxGrammar(rules: [
        SyntaxRule(#"^#{1,6}[^\n]*"#, SyntaxColor.keyword, options: [.anchorsMatchLines]),
        SyntaxRule(#"\*\*[^*\n]+\*\*|__[^_\n]+__"#, SyntaxColor.attribute),
        SyntaxRule(#"\[[^\]\n]*\]\([^)\n]*\)"#, SyntaxColor.tag),
        SyntaxRule(#"`[^`\n]+`|^```[\s\S]*?^```"#, SyntaxColor.string, options: [.anchorsMatchLines]),
        SyntaxRule(#"^\s*(?:[-*+]|\d+\.)\s"#, SyntaxColor.number, options: [.anchorsMatchLines]),
    ])
}
