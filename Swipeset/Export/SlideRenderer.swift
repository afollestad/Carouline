//
//  SlideRenderer.swift
//  Swipeset
//

import UIKit

/// Draws a slide as images for export, laid out by the same geometry as the screen.
nonisolated enum SlideRenderer {
    /// `slide` as `slide.span` images of `size` pixels, handed to `piece` in order: the
    /// background, then each cell's photo framed by its crop and clipped to the cell. A panorama
    /// lays out as one canvas, snapped to whole pixels, and each piece is a whole slide's width of
    /// it, so the pieces meet without a seam. `image` decodes a photo at the size it's drawn, or
    /// returns nil when its copy is missing, which leaves the cell the background's color.
    /// Returns how many photos were missing, counting one once however many pieces it crosses.
    static func render(
        _ slide: Slide,
        style: SlideStyle,
        size: CGSize,
        image: (PlacedImage, CGSize) -> CGImage?,
        piece: (UIImage) throws -> Void
    ) rethrows -> Int {
        let canvas = CGSize(width: size.width * CGFloat(slide.span), height: size.height)
        let cells = SlideGeometry.cellFrames(for: slide.layout, in: canvas, style: style, span: slide.span, pixelScale: 1)
        var missingPhotos = 0
        // Decoded once for every piece, rather than again for each piece a panorama crosses.
        let photos: [DrawnPhoto] = zip(slide.cells, cells).compactMap { cell, rect in
            guard let placed = cell.image else {
                return nil
            }
            let frame = CropGeometry.frame(imageSize: placed.pixelSize, cellSize: rect.size, crop: placed.crop)
            guard let decoded = image(placed, frame.size) else {
                missingPhotos += 1
                return nil
            }
            return DrawnPhoto(image: decoded, frame: frame.offsetBy(dx: rect.minX, dy: rect.minY), cell: rect)
        }

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
                }
                try piece(rendered)
            }
        }
        return missingPhotos
    }

    /// A decoded photo, where it draws on the canvas, and the cell it's clipped to.
    private struct DrawnPhoto {
        let image: CGImage
        let frame: CGRect
        let cell: CGRect
    }
}
