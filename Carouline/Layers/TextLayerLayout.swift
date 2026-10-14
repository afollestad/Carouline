//
//  TextLayerLayout.swift
//  Carouline
//

import CoreText
import Foundation
import UIKit

/// A text layer's lines, laid out once at the reference slide width. Every renderer draws this
/// one layout scaled, so the screen and the export break lines and size boxes alike, whatever
/// the screen's size, a font's optical sizes, or the Bold Text setting.
nonisolated final class TextLayerLayout: @unchecked Sendable {
    /// Each line, without the trailing space or newline it broke at, with its width.
    let lines: [(line: CTLine, width: CGFloat)]
    let fontSize: CGFloat
    let ascent: CGFloat
    let lineHeight: CGFloat
    let alignment: TextLayerAlignment
    /// The letters' box, before any highlight's padding.
    let textSize: CGSize

    /// A highlight's padding across and down, and its corners, as fractions of the type size:
    /// enough to frame the letters without the box swallowing them.
    static let highlightPadding = CGSize(width: 0.35, height: 0.18)
    static let highlightCornerRadius: CGFloat = 0.28

    private init(text: TextLayer) {
        fontSize = LayerGeometry.fontSize * LayerGeometry.referenceSlideWidth
        alignment = text.alignment
        let font = text.font.uiFont(size: fontSize) as CTFont
        ascent = CTFontGetAscent(font)
        lineHeight = (CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)).rounded(.up)
        let string = text.text.trimmingCharacters(in: .newlines)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            // Colored when drawn, so one layout serves every color.
            kCTForegroundColorFromContextAttributeName: true
        ]
        let attributed = CFAttributedStringCreate(nil, string as CFString, attributes as CFDictionary)
        let length = CFAttributedStringGetLength(attributed)
        var lines: [(CTLine, CGFloat)] = []
        if let attributed, length > 0 {
            let typesetter = CTTypesetterCreateWithAttributedString(attributed)
            let wrap = Double(LayerGeometry.wrapWidth * LayerGeometry.referenceSlideWidth)
            var start = 0
            while start < length {
                let count = max(1, CTTypesetterSuggestLineBreak(typesetter, start, wrap))
                let line = CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count))
                let width = CTLineGetTypographicBounds(line, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(line)
                lines.append((line, CGFloat(max(0, width))))
                start += count
            }
        }
        self.lines = lines
        textSize = CGSize(width: lines.map(\.1).max() ?? 0, height: CGFloat(lines.count) * lineHeight)
    }

    /// The layer's box: the letters', with the highlight's padding around them when there is one.
    func boxSize(isHighlighted: Bool) -> CGSize {
        guard isHighlighted, !lines.isEmpty else {
            return textSize
        }
        return CGSize(
            width: textSize.width + 2 * Self.highlightPadding.width * fontSize,
            height: textSize.height + 2 * Self.highlightPadding.height * fontSize
        )
    }

    /// The layout of `text`, made once for each text, font and alignment.
    static func make(for text: TextLayer) -> TextLayerLayout {
        let key = "\(text.font.rawValue)\u{1F}\(text.alignment.rawValue)\u{1F}\(text.text)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let layout = TextLayerLayout(text: text)
        cache.setObject(layout, forKey: key)
        return layout
    }

    /// `NSCache` is safe to use from any thread, so the screen and an export share it.
    private static let cache: NSCache<NSString, TextLayerLayout> = {
        let cache = NSCache<NSString, TextLayerLayout>()
        cache.countLimit = 200
        return cache
    }()
}
