//
//  TestImages.swift
//  SwipesetTests
//

import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Swipeset

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
