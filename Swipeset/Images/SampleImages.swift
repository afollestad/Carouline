//
//  SampleImages.swift
//  Swipeset
//

import CoreGraphics
import Foundation

/// Stand-in photos drawn in code, the same for the same ID every time, for previews, snapshots
/// and the debug sample store.
nonisolated enum SampleImages {
    /// Pairs of colors, a sky over a horizon.
    private static let palettes: [(top: RGBColor, bottom: RGBColor)] = [
        (RGBColor(red: 0.98, green: 0.62, blue: 0.38), RGBColor(red: 0.47, green: 0.34, blue: 0.91)),
        (RGBColor(red: 0.38, green: 0.78, blue: 0.92), RGBColor(red: 0.13, green: 0.32, blue: 0.55)),
        (RGBColor(red: 0.99, green: 0.85, blue: 0.45), RGBColor(red: 0.89, green: 0.36, blue: 0.42)),
        (RGBColor(red: 0.62, green: 0.89, blue: 0.71), RGBColor(red: 0.16, green: 0.45, blue: 0.42)),
        (RGBColor(red: 0.93, green: 0.67, blue: 0.86), RGBColor(red: 0.36, green: 0.27, blue: 0.83))
    ]

    /// A gradient with a sun low over it, so a pan or zoom shows which part is in view, drawn at
    /// `width` by `height` scaled down to `maxPixelSize`.
    static func image(for id: UUID, width: Int, height: Int, maxPixelSize: Int = .max) -> CGImage? {
        let scale = min(1, Double(maxPixelSize) / Double(max(width, height, 1)))
        let pixelWidth = max(1, Int((Double(width) * scale).rounded()))
        let pixelHeight = max(1, Int((Double(height) * scale).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else {
            return nil
        }
        let palette = palettes[Int(id.uuid.15) % palettes.count]
        let colors = [palette.top, palette.bottom].map { CGColor(srgbRed: $0.red, green: $0.green, blue: $0.blue, alpha: 1) }
        if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: pixelHeight), end: .zero, options: [])
        }
        let radius = Double(min(pixelWidth, pixelHeight)) * 0.18
        context.setFillColor(CGColor(srgbRed: 1, green: 0.96, blue: 0.86, alpha: 0.9))
        context.fillEllipse(in: CGRect(
            x: Double(pixelWidth) * 0.62 - radius,
            y: Double(pixelHeight) * 0.38 - radius,
            width: radius * 2,
            height: radius * 2
        ))
        context.setFillColor(CGColor(srgbRed: 0.08, green: 0.1, blue: 0.2, alpha: 0.35))
        context.fill(CGRect(x: 0, y: 0, width: Double(pixelWidth), height: Double(pixelHeight) * 0.22))
        return context.makeImage()
    }
}
