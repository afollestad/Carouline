//
//  TestImages.swift
//  CaroulineTests
//

import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Carouline

/// Image files drawn in code, so tests need no binary fixtures.
enum TestImages {
    /// A JPEG of `width` by `height` pixels at `url`, tagged with EXIF `orientation`, where 6
    /// means a viewer turns it a quarter clockwise.
    static func writeJPEG(width: Int, height: Int, orientation: Int = 1, to url: URL) throws {
        let image = try #require(SampleImages.image(for: UUID(), width: width, height: height))
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
    }

    /// A PNG of `width` by `height` pixels at `url`, with an alpha channel, clear on its left half
    /// and opaque blue on its right, as a sticker or a logo cut out of its background is, or blue
    /// all over when `isOpaque`, as a screenshot is.
    static func writePNG(width: Int, height: Int, isOpaque: Bool = false, to url: URL) throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        let clearWidth = isOpaque ? 0 : width / 2
        context.fill(CGRect(x: clearWidth, y: 0, width: width - clearWidth, height: height))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }

    /// The image at `url`, decoded whole.
    static func decode(_ url: URL) -> CGImage? {
        CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
    }

    /// An 8-bit sRGB color, premultiplied by its alpha.
    struct Pixel: Equatable {
        let red: Int
        let green: Int
        let blue: Int
        let alpha: Int
    }

    /// The color at `point` in `image`, measured from the top-left.
    static func pixel(of image: CGImage, at point: CGPoint) -> Pixel? {
        var bytes = [UInt8](repeating: 0, count: 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        let height = CGFloat(image.height)
        context.draw(image, in: CGRect(x: -point.x, y: point.y - height + 1, width: CGFloat(image.width), height: height))
        return Pixel(red: Int(bytes[0]), green: Int(bytes[1]), blue: Int(bytes[2]), alpha: Int(bytes[3]))
    }

    /// The pixel size of the image at `url`, as stored.
    static func pixelSize(of url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
}
