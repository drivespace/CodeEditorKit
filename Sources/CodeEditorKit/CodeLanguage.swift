import Foundation

/// Languages supported by the syntax highlighter.
public enum CodeLanguage: String, CaseIterable, Identifiable, Sendable {
    case php, html, css, javascript, json, apache, sql, xml, markdown, plain

    public var id: String { rawValue }

    /// Detects the language from a file name – `index.php`, `.htaccess`, `style.scss`…
    public init(fileName: String) {
        let lower = fileName.lowercased()
        if lower == ".htaccess" || lower == ".htpasswd" || lower == ".user.ini" || lower.hasSuffix(".conf") {
            self = .apache
            return
        }
        switch (lower as NSString).pathExtension {
        case "php", "phtml", "inc", "module": self = .php
        case "html", "htm", "tpl", "latte", "twig", "vue", "svelte", "shtml": self = .html
        case "css", "scss", "sass", "less": self = .css
        case "js", "mjs", "cjs", "ts", "jsx", "tsx": self = .javascript
        case "json", "webmanifest": self = .json
        case "sql": self = .sql
        case "xml", "svg", "rss", "xsl", "plist": self = .xml
        case "md", "markdown": self = .markdown
        default: self = .plain
        }
    }

    /// Human readable name.
    public var title: String {
        switch self {
        case .php: "PHP"
        case .html: "HTML"
        case .css: "CSS"
        case .javascript: "JavaScript"
        case .json: "JSON"
        case .apache: "Apache (.htaccess)"
        case .sql: "SQL"
        case .xml: "XML"
        case .markdown: "Markdown"
        case .plain: "Plain text"
        }
    }
}
