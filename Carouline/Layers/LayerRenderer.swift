//
//  LayerRenderer.swift
//  Carouline
//

import CoreText
import UIKit

/// Draws layers with Core Graphics: text for the screen and the export alike, and whole layers
/// for the export, laid out by `LayerGeometry`.
nonisolated enum LayerRenderer {
    /// A text shadow's offset down and its blur, as fractions of the type size: soft and close,
    /// so it lifts the letters off a busy photo without reading as a second copy of them.
    static let shadowOffset: CGFloat = 0.05
    static let shadowBlur: CGFloat = 0.16
    /// Text's shadow and a picture's alike.
    static let shadowOpacity: CGFloat = 0.55
    /// Core Graphics' shadow blur for a Gaussian of sigma 1, as a picture's shadow is measured
    /// and SwiftUI's `shadow(radius:)` takes it: Core Graphics blurs a straight edge's 10–90%
    /// rise across 1.2 times its blur, and a Gaussian across 2.563 sigmas.
    static let shadowBlurPerSigma: CGFloat = 2.136

    /// A picture layer's picture decoded at the size it's drawn, blurred when it is, with the
    /// outline its border traces when it's transparent, made once however many of a panorama's
    /// pieces it crosses.
    struct Picture {
        let image: CGImage
        let outline: CGImage?
        /// How far a transparent picture's blur spreads past its edges, as a share of its size.
        let spread: CGSize

        init(_ decoded: CGImage, for picture: ImageLayer) {
            let isTransparent = picture.image.fileFormat == .png
            // From the picture before its blur, so the outline stays crisp.
            outline = isTransparent ? LayerImageEffects.outline(of: decoded, for: picture) : nil
            let size = CGSize(width: decoded.width, height: decoded.height)
            let sigma = LayerGeometry.blurRadius(of: picture, pictureSize: size)
            if sigma > 0, isTransparent, let blurred = LayerImageEffects.blurredOut(decoded, sigma: sigma) {
                image = blurred
                spread = CGSize(
                    width: CGFloat(blurred.width - decoded.width) / 2 / size.width,
                    height: CGFloat(blurred.height - decoded.height) / 2 / size.height
                )
            } else if sigma > 0, let blurred = LayerImageEffects.render(
                LayerImageEffects.blurredInPlace(decoded, sigma: sigma),
                from: CGRect(origin: .zero, size: size)
            ) {
                image = blurred
                spread = .zero
            } else {
                image = decoded
                spread = .zero
            }
        }
    }

    /// Draws `layer` on a canvas of `canvas` spanning `span` slides, turned about its center.
    /// `picture` is its picture decoded, or nil when the copy is missing, which draws nothing.
    static func draw(_ layer: Layer, picture: Picture?, in context: CGContext, canvas: CGSize, span: Int) {
        let frame = LayerGeometry.frame(of: layer, canvas: canvas, span: span)
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: frame.midX, y: frame.midY)
        context.rotate(by: layer.placement.rotation)
        let box = CGRect(x: -frame.width / 2, y: -frame.height / 2, width: frame.width, height: frame.height)
        switch layer.content {
        case .text(let text):
            drawText(text, in: context, box: box)
        case .image(let content):
            if let picture {
                drawPicture(content, decoded: picture, in: context, box: box)
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
            setShadow(in: context, offset: shadowOffset * layout.fontSize, blur: shadowBlur * layout.fontSize)
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

    /// Sets a shadow falling `offset` down with a Core Graphics `blur`, both in the context's
    /// current space, so it scales and turns with the layer. A shadow's offset is given outside
    /// that space, and positive runs down the screen, so it's carried out through the current
    /// transform, then flipped back where the transform flips the context over a base that runs
    /// up, as UIKit's does and a SwiftUI canvas's doesn't.
    private static func setShadow(in context: CGContext, offset down: CGFloat, blur: CGFloat) {
        let transform = context.ctm
        let scale = hypot(transform.a, transform.b)
        let isFlipped = transform.a * transform.d - transform.b * transform.c < 0
        context.setShadow(
            offset: CGSize(width: transform.c * down, height: (isFlipped ? -1 : 1) * transform.d * down),
            blur: blur * scale,
            color: UIColor.black.withAlphaComponent(shadowOpacity).cgColor
        )
    }

    /// Draws a picture into `box` inside its border: over a ring of its border color for an opaque
    /// picture, and over an outline tracing its shape for a transparent one.
    private static func drawPicture(_ picture: ImageLayer, decoded: Picture, in context: CGContext, box: CGRect) {
        let border = LayerGeometry.borderWidth(of: picture, inFrame: box.size)
        let frame = box.insetBy(dx: border, dy: border)
        let shadow = LayerGeometry.shadow(of: picture, pictureSize: frame.size)
        if let shadow {
            setShadow(in: context, offset: shadow.offset, blur: shadow.radius * shadowBlurPerSigma)
            // One shadow for the picture and its border together, rather than one each.
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        }
        defer {
            if shadow != nil {
                context.endTransparencyLayer()
            }
        }
        if border > 0 {
            if picture.image.fileFormat == .jpeg {
                context.setFillColor(picture.borderColor.uiColor.cgColor)
                context.fill(box)
            } else if let outline = decoded.outline {
                UIImage(cgImage: outline).draw(in: box)
            }
        }
        UIImage(cgImage: decoded.image).draw(in: frame.insetBy(dx: -decoded.spread.width * frame.width, dy: -decoded.spread.height * frame.height))
    }
}
