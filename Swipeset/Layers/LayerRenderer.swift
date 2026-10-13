//
//  LayerRenderer.swift
//  Swipeset
//

import CoreText
import UIKit

/// Draws layers with Core Graphics: text for the screen and the export alike, and whole layers
/// for the export, laid out by `LayerGeometry`.
nonisolated enum LayerRenderer {
    /// A shadow's offset down and its blur, as fractions of the type size: soft and close, so it
    /// lifts the letters off a busy photo without reading as a second copy of them.
    static let shadowOffset: CGFloat = 0.05
    static let shadowBlur: CGFloat = 0.16
    static let shadowOpacity: CGFloat = 0.55

    /// Draws `layer` on a canvas of `canvas` spanning `span` slides, turned about its center.
    /// `image` is its picture decoded, or nil when the copy is missing, which draws nothing.
    static func draw(_ layer: Layer, image: CGImage?, in context: CGContext, canvas: CGSize, span: Int) {
        let frame = LayerGeometry.frame(of: layer, canvas: canvas, span: span)
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: frame.midX, y: frame.midY)
        context.rotate(by: layer.placement.rotation)
        let box = CGRect(x: -frame.width / 2, y: -frame.height / 2, width: frame.width, height: frame.height)
        switch layer.content {
        case .text(let text):
            drawText(text, in: context, box: box)
        case .image(let picture):
            if let image {
                drawPicture(picture, image: image, in: context, box: box)
            }
        }
    }

    /// Draws `text`'s layout scaled into `box`, its frame in `context`'s coordinates, which run
    /// down from the top as UIKit's do. The shadow is set in the layer's own space, so it turns
    /// with the layer here and on screen alike.
    static func drawText(_ text: TextLayer, in context: CGContext, box: CGRect) {
        let layout = TextLayerLayout.make(for: text)
        let reference = layout.boxSize(isHighlighted: text.isHighlighted)
        guard !layout.lines.isEmpty, reference.width > 0, box.width > 0 else {
            return
        }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: box.minX, y: box.minY)
        context.scaleBy(x: box.width / reference.width, y: box.height / reference.height)
        if text.hasShadow {
            setShadow(in: context, fontSize: layout.fontSize)
            // One shadow for the highlight and letters together, rather than one each.
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        }
        defer {
            if text.hasShadow {
                context.endTransparencyLayer()
            }
        }
        var origin = CGPoint.zero
        if text.isHighlighted {
            let radius = TextLayerLayout.highlightCornerRadius * layout.fontSize
            context.setFillColor(text.color.uiColor.cgColor)
            context.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: reference), cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.fillPath()
            origin = CGPoint(
                x: TextLayerLayout.highlightPadding.width * layout.fontSize,
                y: TextLayerLayout.highlightPadding.height * layout.fontSize
            )
        }
        context.setFillColor(text.letterColor.uiColor.cgColor)
        context.textMatrix = .identity
        for (index, entry) in layout.lines.enumerated() {
            let slack = layout.textSize.width - entry.width
            let x = switch layout.alignment {
            case .leading: origin.x
            case .center: origin.x + slack / 2
            case .trailing: origin.x + slack
            }
            context.saveGState()
            // Core Text draws upward from a baseline, in a context that runs down the page.
            context.translateBy(x: x, y: origin.y + CGFloat(index) * layout.lineHeight + layout.ascent)
            context.scaleBy(x: 1, y: -1)
            context.textPosition = .zero
            CTLineDraw(entry.line, context)
            context.restoreGState()
        }
    }

    /// Sets the text shadow for type `fontSize` in the context's current space, so it scales and
    /// turns with the layer. A shadow's offset is given outside that space, and positive runs down
    /// the screen, so it's carried out through the current transform, then flipped back where the
    /// transform flips the context over a base that runs up, as UIKit's does and a SwiftUI
    /// canvas's doesn't.
    private static func setShadow(in context: CGContext, fontSize: CGFloat) {
        let transform = context.ctm
        let down = shadowOffset * fontSize
        let scale = hypot(transform.a, transform.b)
        let isFlipped = transform.a * transform.d - transform.b * transform.c < 0
        context.setShadow(
            offset: CGSize(width: transform.c * down, height: (isFlipped ? -1 : 1) * transform.d * down),
            blur: shadowBlur * fontSize * scale,
            color: UIColor.black.withAlphaComponent(shadowOpacity).cgColor
        )
    }

    /// Draws a picture into `box` inside its border, which an opaque picture fills as a ring of
    /// its border color, and a transparent one leaves clear.
    private static func drawPicture(_ picture: ImageLayer, image: CGImage, in context: CGContext, box: CGRect) {
        let border = LayerGeometry.borderWidth(of: picture, inFrame: box.size)
        if picture.image.fileFormat == .jpeg, border > 0 {
            context.setFillColor(picture.borderColor.uiColor.cgColor)
            context.fill(box)
        }
        UIImage(cgImage: image).draw(in: box.insetBy(dx: border, dy: border))
    }
}
