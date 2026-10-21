//
//  SlideRenderer.swift
//  Carouline
//

import CoreImage
import UIKit

/// Draws a slide as images for export, laid out by the same geometry as the screen.
nonisolated enum SlideRenderer {
    /// Images a render couldn't read, which it left out.
    struct MissingImages: Equatable, Sendable {
        /// Cells' photos, whose cells export as the background.
        var photos = 0
        /// Layers' images, which export as nothing.
        var layerImages = 0
    }

    /// `slide` as `slide.span` images of `size` pixels, handed to `piece` in order: the
    /// background, each cell's photo framed by its crop and clipped to the cell, then its layers
    /// bottom to top. A panorama lays out as one canvas, snapped to whole pixels, and each piece
    /// is a whole slide's width of it, so the pieces meet without a seam and a layer crossing one
    /// splits across them. `image` decodes a photo or picture at the size it's drawn, or returns
    /// nil when its copy is missing. Counts each missing image once however many pieces it crosses.
    static func render(
        _ slide: Slide,
        size: CGSize,
        image: (PlacedImage, CGSize) -> CGImage?,
        piece: (UIImage) throws -> Void
    ) rethrows -> MissingImages {
        let canvas = CGSize(width: size.width * CGFloat(slide.span), height: size.height)
        var missing = MissingImages()
        // Decoded once for every piece, rather than again for each piece a panorama crosses.
        let photos = decodedPhotos(of: slide, canvas: canvas, missing: &missing.photos, image: image)
        let pictures = decodedPictures(of: slide, canvas: canvas, missing: &missing.layerImages, image: image)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        // 8-bit sRGB, which every app takes, rather than the wide range the screen would pick.
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        for index in 0..<slide.span {
            // One piece's render at a time, rather than all of a panorama's at once.
            try autoreleasepool {
                let rendered = renderer.image { context in
                    context.cgContext.interpolationQuality = .high
                    slide.style.background.uiColor.setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                    context.cgContext.translateBy(x: -CGFloat(index) * size.width, y: 0)
                    let shown = CGRect(origin: CGPoint(x: CGFloat(index) * size.width, y: 0), size: size)
                    for photo in photos {
                        draw(photo, on: shown, canvas: canvas, in: context.cgContext)
                    }
                    for layer in slide.layers {
                        LayerRenderer.draw(layer, picture: pictures[layer.id], in: context.cgContext, canvas: canvas, span: slide.span)
                    }
                }
                try piece(rendered)
            }
        }
        return missing
    }

    /// Draws `photo` clipped to its cell, blurred when its slide is. A blurred one is scaled to
    /// the canvas by Core Image and only its pixels on `shown`, the canvas's piece being drawn,
    /// are rendered, so a panorama's photo never renders whole, and each piece takes its pixels
    /// from the one blurred photo, so the pieces meet without a seam.
    ///
    /// A few pixels past the piece are rendered too, and fall outside it, since Core Image
    /// scaling a part of an image holds its last few pixels at the part's edge.
    private static func draw(_ photo: DrawnPhoto, on shown: CGRect, canvas: CGSize, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: photo.cell)
        guard let blurred = photo.blurred else {
            UIImage(cgImage: photo.image).draw(in: photo.frame)
            return
        }
        let visible = photo.frame.intersection(photo.cell).intersection(shown).integral
        guard !visible.isEmpty else {
            return
        }
        // Core Image measures up from the bottom, so the canvas is flipped for it.
        let placed = blurred.transformed(by: CGAffineTransform(
            translationX: photo.frame.minX,
            y: canvas.height - photo.frame.maxY
        ).scaledBy(x: photo.frame.width / CGFloat(photo.image.width), y: photo.frame.height / CGFloat(photo.image.height)))
        let drawn = visible.insetBy(dx: -Self.renderMargin, dy: -Self.renderMargin)
        let flipped = CGRect(x: drawn.minX, y: canvas.height - drawn.maxY, width: drawn.width, height: drawn.height)
        if let rendered = LayerImageEffects.render(placed, from: flipped) {
            UIImage(cgImage: rendered).draw(in: drawn)
        }
    }

    /// Each cell's photo decoded at the size its crop draws it, counting those missing.
    private static func decodedPhotos(
        of slide: Slide,
        canvas: CGSize,
        missing: inout Int,
        image: (PlacedImage, CGSize) -> CGImage?
    ) -> [DrawnPhoto] {
        let cells = SlideGeometry.cellFrames(for: slide.layout, in: canvas, style: slide.style, span: slide.span, pixelScale: 1)
        let sigma = LayerGeometry.blurRadius(slide.blur, slideWidth: LayerGeometry.slideWidth(canvas: canvas, span: slide.span))
        return zip(slide.cells, cells).compactMap { cell, rect in
            guard let placed = cell.image else {
                return nil
            }
            let frame = CropGeometry.frame(imageSize: placed.pixelSize, cellSize: rect.size, crop: placed.crop)
            guard let decoded = image(placed, frame.size) else {
                missing += 1
                return nil
            }
            // In the decode's own pixels, which can be fewer than it's drawn across.
            let blurred = sigma > 0 ? LayerImageEffects.blurredInPlace(decoded, sigma: sigma * CGFloat(decoded.width) / frame.width) : nil
            return DrawnPhoto(image: decoded, blurred: blurred, frame: frame.offsetBy(dx: rect.minX, dy: rect.minY), cell: rect)
        }
    }

    /// Each picture layer's picture decoded at the size it's drawn, with its outline or the trace
    /// a styled one's cut along, by layer, counting those missing.
    private static func decodedPictures(
        of slide: Slide,
        canvas: CGSize,
        missing: inout Int,
        image: (PlacedImage, CGSize) -> CGImage?
    ) -> [UUID: LayerRenderer.Picture] {
        let slideWidth = LayerGeometry.slideWidth(canvas: canvas, span: slide.span)
        var pictures: [UUID: LayerRenderer.Picture] = [:]
        for layer in slide.layers {
            guard case .image(let picture) = layer.content else {
                continue
            }
            let size = LayerGeometry.pictureSize(of: picture.image, scale: layer.placement.scale, slideWidth: slideWidth)
            if let decoded = image(picture.image, size) {
                let side = CGFloat(LayerImageEffects.contourSide)
                let source = picture.hasStyledOutline ? image(picture.image, CGSize(width: side, height: side)) : nil
                pictures[layer.id] = LayerRenderer.Picture(decoded, contourSource: source, for: picture)
            } else {
                missing += 1
            }
        }
        return pictures
    }

    /// Past the three pixels Core Image holds at the edge of a part of an image it scales,
    /// counted in the pixels it renders, as measured at a photo drawn 5.4 times its decode.
    private static let renderMargin: CGFloat = 8

    /// A decoded photo, blurred when its slide is, where it draws on the canvas, and the cell
    /// it's clipped to.
    private struct DrawnPhoto {
        let image: CGImage
        /// The photo blurred, as a recipe each piece renders only its own part of.
        let blurred: CIImage?
        let frame: CGRect
        let cell: CGRect
    }
}
