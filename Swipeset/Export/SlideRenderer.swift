//
//  SlideRenderer.swift
//  Swipeset
//

import UIKit

/// Draws a slide as an image for export, laid out by the same geometry as the screen.
nonisolated enum SlideRenderer {
    /// `slide` at `size` pixels: the background, then each cell's photo framed by its crop and
    /// clipped to the cell. `image` decodes a photo at the size it's drawn, or returns nil when
    /// its copy is missing, which leaves the cell the background's color. Also returns how many
    /// photos were missing.
    static func render(
        _ slide: Slide,
        style: SlideStyle,
        size: CGSize,
        image: (PlacedImage, CGSize) -> CGImage?
    ) -> (image: UIImage, missingPhotos: Int) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        // 8-bit sRGB, which every app takes, rather than the wide range the screen would pick.
        format.preferredRange = .standard
        var missingPhotos = 0
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            style.background.uiColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let cells = SlideGeometry.cellFrames(for: slide.layout, in: size, style: style, pixelScale: 1)
            for (cell, rect) in zip(slide.cells, cells) {
                guard let placed = cell.image else {
                    continue
                }
                let frame = CropGeometry.frame(imageSize: placed.pixelSize, cellSize: rect.size, crop: placed.crop)
                guard let photo = image(placed, frame.size) else {
                    missingPhotos += 1
                    continue
                }
                context.cgContext.saveGState()
                context.cgContext.clip(to: rect)
                UIImage(cgImage: photo).draw(in: frame.offsetBy(dx: rect.minX, dy: rect.minY))
                context.cgContext.restoreGState()
            }
        }
        return (rendered, missingPhotos)
    }
}
