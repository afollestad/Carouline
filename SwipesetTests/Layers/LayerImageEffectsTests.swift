//
//  LayerImageEffectsTests.swift
//  SwipesetTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Swipeset

struct LayerImageEffectsTests {
    /// An image's alpha, a row at a time from the top, at `size` or its own.
    private struct AlphaMap {
        let width: Int
        let height: Int
        let values: [UInt8]

        init(_ image: CGImage, size: CGSize? = nil) throws {
            width = Int(size?.width ?? CGFloat(image.width))
            height = Int(size?.height ?? CGFloat(image.height))
            let (width, height) = (width, height)
            var buffer = [UInt8](repeating: 0, count: width * height)
            let isDrawn = buffer.withUnsafeMutableBytes { bytes in
                guard let context = CGContext(
                    data: bytes.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
                ) else {
                    return false
                }
                context.interpolationQuality = .high
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            try #require(isDrawn)
            values = buffer
        }

        subscript(x: Int, y: Int) -> UInt8 {
            values[y * width + x]
        }
    }

    /// A `width` by `height` image with `fill` painted over a clear background.
    private func image(width: Int, height: Int, fill: (CGContext) -> Void) throws -> CGImage {
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
        fill(context)
        return try #require(context.makeImage())
    }

    /// Clear on its left half and opaque on its right, its shape's edge a straight line down.
    private func halfClear(width: Int = 400, height: Int = 200) throws -> CGImage {
        try image(width: width, height: height) { context in
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
            context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        }
    }

    @Test(arguments: [4.0, 12.0, 60.0])
    func growsAStraightEdgeByItsWidth(width: Double) throws {
        let source = try halfClear()
        let outline = try #require(LayerImageEffects.outline(of: source, width: width, color: .white))
        let alpha = try AlphaMap(outline)

        #expect(alpha.width == 400 + 2 * Int(width))
        #expect(alpha.height == 200 + 2 * Int(width))
        // The shape's edge sits `width` in, past the canvas's growth, so its outline starts 200 in.
        let row = alpha.height / 2
        let start = try #require((0..<alpha.width).first { alpha[$0, row] >= 128 })
        #expect(abs(start - 200) <= 1)
        // And it fills the shape, out to within a pixel of the canvas's far edge.
        #expect(alpha[alpha.width / 2 + 10, row] == 255)
        let end = try #require((0..<alpha.width).last { alpha[$0, row] >= 128 })
        #expect(end >= alpha.width - 2)
    }

    @Test func leavesTheRestOfTheCanvasClear() throws {
        let outline = try #require(LayerImageEffects.outline(of: halfClear(), width: 12, color: .white))
        let alpha = try AlphaMap(outline)

        for x in [0, 50, 150, 195] {
            #expect(alpha[x, alpha.height / 2] == 0)
            #expect(alpha[x, 0] == 0)
        }
    }

    /// A drop shadow or soft edge too faint to read as the picture's shape doesn't swell the
    /// outline: it follows the opaque square, not the haze around it.
    @Test func ignoresAFaintHaze() throws {
        let source = try image(width: 200, height: 200) { context in
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.3))
            context.fill(CGRect(x: 40, y: 40, width: 120, height: 120))
            context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 80, y: 80, width: 40, height: 40))
        }
        let outline = try #require(LayerImageEffects.outline(of: source, width: 6, color: .white))
        let alpha = try AlphaMap(outline)

        // The square starts 80 in, plus the canvas's 6, so its outline starts at 80, well inside
        // the haze, which starts at 46.
        #expect(alpha[82, 106] == 255)
        #expect(alpha[77, 106] == 0)
        #expect(alpha[60, 106] == 0)
    }

    /// A stroke far thinner than the border, as in a logo's lettering, is outlined all the way
    /// out, not just a little.
    @Test func outlinesAThinStroke() throws {
        let source = try image(width: 200, height: 100) { context in
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 99, y: 0, width: 3, height: 100))
        }
        let outline = try #require(LayerImageEffects.outline(of: source, width: 12, color: .white))
        let alpha = try AlphaMap(outline)

        // The stroke spans 111 to 114 on the outline's canvas, so its outline 99 to 126.
        #expect(alpha[102, 62] >= 128)
        #expect(alpha[123, 62] >= 128)
        #expect(alpha[94, 62] == 0)
        #expect(alpha[131, 62] == 0)
    }

    /// The outline keeps the picture's way up: a shape along the top is outlined along the top.
    @Test func keepsThePictureUpright() throws {
        let source = try image(width: 100, height: 100) { context in
            // Core Graphics counts up from the bottom, so this is the picture's top 20 rows.
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 80, width: 100, height: 20))
        }
        let outline = try #require(LayerImageEffects.outline(of: source, width: 10, color: .white))
        let alpha = try AlphaMap(outline)

        #expect(alpha[60, 20] == 255)
        #expect(alpha[60, 100] == 0)
    }

    /// An outline is a share of the picture's size, so a small render scaled up matches a large one.
    @Test func matchesAtAnyResolution() throws {
        let id = UUID()
        let picture = ImageLayer(image: PlacedImage(assetIdentifier: nil, pixelWidth: 800, pixelHeight: 800, fileFormat: .png), borderWidth: 0.05)
        let large = try #require(SampleImages.sticker(for: id, width: 800, height: 800))
        let small = try #require(SampleImages.sticker(for: id, width: 400, height: 400))
        let largeOutline = try #require(LayerImageEffects.outline(of: large, for: picture))
        let smallOutline = try #require(LayerImageEffects.outline(of: small, for: picture))
        #expect(largeOutline.width == 880)
        #expect(smallOutline.width == 440)

        let scaledDown = try AlphaMap(largeOutline, size: CGSize(width: 440, height: 440))
        let smallAlpha = try AlphaMap(smallOutline)
        var difference = 0
        for (scaled, small) in zip(scaledDown.values, smallAlpha.values) {
            difference += abs(Int(scaled) - Int(small))
        }
        #expect(Double(difference) / Double(smallAlpha.values.count) < 2)
    }

    @Test func drawsNothingWithoutABorder() throws {
        #expect(LayerImageEffects.outline(of: try halfClear(), width: 0, color: .white) == nil)
    }
}
