import CodeEditorKit

/// Sample code for each language.
enum Samples {
    static func text(for language: CodeLanguage) -> String {
        switch language {
        case .php: php
        case .html: html
        case .css: css
        case .javascript: javascript
        case .json: json
        case .apache: apache
        case .sql: sql
        case .xml: xml
        case .markdown: markdown
        case .plain: plain
        }
    }

    static let php = #"""
    <?php
    /**
     * Simple contact form handler
     */
    declare(strict_types=1);

    function sendMessage(string $name, string $email, string $message): bool
    {
        if (empty($name) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            return false;
        }
        $body = "Message from {$name} <{$email}>:\n\n" . $message;
        return mail('info@example.com', 'New message', $body);
    }

    $sent = sendMessage($_POST['name'] ?? '', $_POST['email'] ?? '', $_POST['message'] ?? '');
    ?>
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <title>Contact</title>
        <style>
            .notice { color: #2e7d32; font-weight: 600; }
        </style>
    </head>
    <body>
        <?php if ($sent): ?>
            <p class="notice">Thank you, we will get back to you soon.</p>
        <?php endif; ?>
    </body>
    </html>
    """#

    static let html = #"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Hotel in the Old Town</title>
        <link rel="stylesheet" href="style.css">
    </head>
    <body>
        <!-- Main navigation -->
        <header class="site-header">
            <nav>
                <a href="/" class="logo">Old Town Hotel</a>
                <a href="/rooms">Rooms</a>
                <a href="/contact">Contact</a>
            </nav>
        </header>
        <main>
            <h1>Welcome &amp; enjoy your stay</h1>
            <button type="button" onclick="book()">Book now</button>
        </main>
        <script>
            function book() {
                alert('Thank you for your interest!');
            }
        </script>
    </body>
    </html>
    """#

    static let css = #"""
    /* Header */
    @import url("fonts.css");

    :root {
        --accent: #3a6ea5;
        --radius: 8px;
    }

    .site-header {
        display: flex;
        align-items: center;
        gap: 1.5rem;
        padding: 16px 24px;
        background: #ffffff;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
    }

    .button {
        color: #fff !important;
        background: var(--accent);
        border-radius: var(--radius);
        transition: transform 200ms ease;
    }

    @media (max-width: 768px) {
        .site-header { flex-direction: column; }
    }
    """#

    static let javascript = #"""
    // Lazy-load images when they enter the viewport
    const images = document.querySelectorAll('img[data-src]');

    const observer = new IntersectionObserver((entries) => {
        for (const entry of entries) {
            if (!entry.isIntersecting) continue;
            const img = entry.target;
            img.src = img.dataset.src;
            observer.unobserve(img);
        }
    }, { rootMargin: '200px' });

    images.forEach((img) => observer.observe(img));

    async function loadRooms() {
        const response = await fetch(`/api/rooms?limit=${10}`);
        return response.ok ? response.json() : [];
    }
    """#

    static let json = #"""
    {
        "name": "CodeEditorKit",
        "version": 1.0,
        "platforms": ["macOS 14"],
        "lineNumbers": true,
        "themes": ["System", "Classic", "Solarized", "Monokai", "Dracula"],
        "license": null
    }
    """#

    static let apache = #"""
    # Redirect to HTTPS and www
    RewriteEngine On
    RewriteCond %{HTTPS} off [OR]
    RewriteCond %{HTTP_HOST} !^www\. [NC]
    RewriteRule ^(.*)$ https://www.example.com/$1 [L,R=301]

    <IfModule mod_expires.c>
        ExpiresActive On
        ExpiresByType image/webp "access plus 1 year"
    </IfModule>
    """#

    static let sql = #"""
    -- Most booked rooms this year
    SELECT r.name, COUNT(b.id) AS bookings
    FROM `rooms` r
    LEFT JOIN `bookings` b ON b.room_id = r.id
    WHERE b.created_at >= '2026-01-01'
    GROUP BY r.id
    ORDER BY bookings DESC
    LIMIT 10;
    """#

    static let xml = #"""
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <!-- Home page -->
        <url>
            <loc>https://www.example.com/</loc>
            <priority>1.0</priority>
        </url>
    </urlset>
    """#

    static let markdown = #"""
    # CodeEditorKit

    A **SwiftUI code editor** for macOS with line numbers and syntax highlighting.

    - Line numbers
    - Themes
    - Auto-closing of `brackets` and HTML tags

    [Website](https://www.drivespace.cz)
    """#

    static let plain = """
    Plain text – no highlighting, just line numbers and a monospaced font.

    Try switching the language, theme and font size above.
    """
}
