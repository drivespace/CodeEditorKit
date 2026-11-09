import AppKit

/// NSTextView that highlights the line with the cursor.
final class CodeNSTextView: NSTextView {
    var currentLineColor: NSColor? {
        didSet { needsDisplay = true }
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let color = currentLineColor, let layoutManager,
              selectedRange().length == 0 else { return }

        let location = selectedRange().location
        let length = textStorage?.length ?? 0
        var lineRect: NSRect
        if location < length {
            lineRect = layoutManager.lineFragmentRect(forGlyphAt: layoutManager.glyphIndexForCharacter(at: location),
                                                      effectiveRange: nil)
        } else {
            lineRect = layoutManager.extraLineFragmentRect
            if lineRect.isEmpty && length > 0 {
                lineRect = layoutManager.lineFragmentRect(forGlyphAt: layoutManager.glyphIndexForCharacter(at: length - 1),
                                                          effectiveRange: nil)
            }
        }
        guard !lineRect.isEmpty else { return }
        lineRect.origin.x = 0
        lineRect.origin.y += textContainerOrigin.y
        lineRect.size.width = bounds.width
        color.setFill()
        lineRect.intersection(rect).fill()
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        if currentLineColor != nil { needsDisplay = true }
    }
}

/// Line numbers on the left side of the editor.
final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private var lineStarts: [Int] = [0]
    var theme = CodeTheme.system {
        didSet { needsDisplay = true }
    }

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        recalculateLines()
        if let clipView = textView.enclosingScrollView?.contentView {
            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(redraw),
                                                   name: NSView.boundsDidChangeNotification, object: clipView)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var isFlipped: Bool { true }

    @objc private func redraw() {
        needsDisplay = true
    }

    func textDidChange() {
        recalculateLines()
        needsDisplay = true
    }

    private var labelFont: NSFont {
        let size = max(9, min(14, (textView?.font?.pointSize ?? 13) - 2))
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
    }

    private func recalculateLines() {
        guard let textView else { return }
        var starts = [0]
        var index = 0
        for unit in textView.string.utf16 {
            index += 1
            if unit == 10 { starts.append(index) }
        }
        lineStarts = starts
        let digits = max(3, String(starts.count).count)
        let thickness = CGFloat(digits) * 7 + 18
        if abs(ruleThickness - thickness) > 0.5 {
            ruleThickness = thickness
        }
    }

    /// Line and column (1-based) for a location in the text.
    func position(for location: Int) -> (line: Int, column: Int) {
        let line = lineIndex(atOrBefore: location)
        return (line + 1, location - lineStarts[line] + 1)
    }

    private func lineIndex(atOrBefore location: Int) -> Int {
        var low = 0
        var high = lineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lineStarts[mid] <= location { low = mid } else { high = mid - 1 }
        }
        return low
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        theme.gutterBackground.setFill()
        bounds.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()

        guard let textView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        let length = textView.textStorage?.length ?? 0
        let glyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let yOffset = convert(NSPoint.zero, from: textView).y + textView.textContainerOrigin.y
        let attributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: theme.gutterText,
        ]

        var line = lineIndex(atOrBefore: charRange.location)
        while line < lineStarts.count {
            let start = lineStarts[line]
            if start > NSMaxRange(charRange) { break }
            let fragment: NSRect
            if start < length {
                let glyph = layoutManager.glyphIndexForCharacter(at: start)
                fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            } else {
                fragment = layoutManager.extraLineFragmentRect
            }
            let label = "\(line + 1)" as NSString
            let size = label.size(withAttributes: attributes)
            let y = yOffset + fragment.minY + (fragment.height - size.height) / 2
            label.draw(at: NSPoint(x: ruleThickness - size.width - 8, y: y), withAttributes: attributes)
            line += 1
        }
    }
}
