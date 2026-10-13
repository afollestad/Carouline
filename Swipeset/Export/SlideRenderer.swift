//
//  SlideRenderer.swift
//  Swipeset
//

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
        style: SlideStyle,
        size: CGSize,
        image: (PlacedImage, CGSize) -> CGImage?,
        piece: (UIImage) throws -> Void
    ) rethrows -> MissingImages {
        let canvas = CGSize(width: size.width * CGFloat(slide.span), height: size.height)
        var missing = MissingImages()
        // Decoded once for every piece, rather than again for each piece a panorama crosses.
        let photos = decodedPhotos(of: slide, style: style, canvas: canvas, missing: &missing.photos, image: image)
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
                    style.background.uiColor.setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                    context.cgContext.translateBy(x: -CGFloat(index) * size.width, y: 0)
                    for photo in photos {
                        context.cgContext.saveGState()
                        context.cgContext.clip(to: photo.cell)
                        UIImage(cgImage: photo.image).draw(in: photo.frame)
                        context.cgContext.restoreGState()
                    }
                    for layer in slide.layers {
                        LayerRenderer.draw(layer, image: pictures[layer.id], in: context.cgContext, canvas: canvas, span: slide.span)
                    }
                }
                try piece(rendered)
            }
        }
        return missing
    }

    /// Each cell's photo decoded at the size its crop draws it, counting those missing.
    private static func decodedPhotos(
        of slide: Slide,
        style: SlideStyle,
        canvas: CGSize,
        missing: inout Int,
        image: (PlacedImage, CGSize) -> CGImage?
    ) -> [DrawnPhoto] {
        let cells = SlideGeometry.cellFrames(for: slide.layout, in: canvas, style: style, span: slide.span, pixelScale: 1)
        return zip(slide.cells, cells).compactMap { cell, rect in
            guard let placed = cell.image else {
                return nil
            }
            let frame = CropGeometry.frame(imageSize: placed.pixelSize, cellSize: rect.size, crop: placed.crop)
            guard let decoded = image(placed, frame.size) else {
                missing += 1
                return nil
            }
            return DrawnPhoto(image: decoded, frame: frame.offsetBy(dx: rect.minX, dy: rect.minY), cell: rect)
        }
    }

    /// Each picture layer's picture decoded at the size it's drawn, by layer, counting those missing.
    private static func decodedPictures(
        of slide: Slide,
        canvas: CGSize,
        missing: inout Int,
        image: (PlacedImage, CGSize) -> CGImage?
    ) -> [UUID: CGImage] {
        let slideWidth = LayerGeometry.slideWidth(canvas: canvas, span: slide.span)
        var pictures: [UUID: CGImage] = [:]
        for layer in slide.layers {
            guard case .image(let picture) = layer.content else {
                continue
            }
            let size = LayerGeometry.pictureSize(of: picture.image, scale: layer.placement.scale, slideWidth: slideWidth)
            if let decoded = image(picture.image, size) {
                pictures[layer.id] = decoded
            } else {
                missing += 1
            }
        }
        return pictures
    }

    /// A decoded photo, where it draws on the canvas, and the cell it's clipped to.
    private struct DrawnPhoto {
        let image: CGImage
        let frame: CGRect
        let cell: CGRect
    }
}
