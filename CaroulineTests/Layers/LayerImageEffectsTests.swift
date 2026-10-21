//
//  LayerImageEffectsTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

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

    /// `loop`'s area, positive where it runs clockwise on screen, as an outline does with its
    /// shape on its right, and negative round a hole.
    private func area(of loop: [CGPoint]) -> CGFloat {
        zip(loop, loop.dropFirst() + loop.prefix(1)).reduce(0) { $0 + ($1.0.x * $1.1.y - $1.1.x * $1.0.y) } / 2
    }

    /// `loop`, in shares of a canvas `side` pixels square, in pixels.
    private func pixels(_ loop: [CGPoint], side: CGFloat) -> [CGPoint] {
        loop.map { CGPoint(x: $0.x * side, y: $0.y * side) }
    }

    /// A disk's outline traces as one loop round it, as far out as the outline reaches.
    @Test func tracesADisksOutline() throws {
        let source = try image(width: 200, height: 200) { context in
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
            context.fillEllipse(in: CGRect(x: 50, y: 50, width: 100, height: 100))
        }
        let contour = try #require(LayerImageEffects.contour(of: source, width: 20))

        #expect(contour.outline.count == 1)
        let loop = pixels(try #require(contour.outline.first), side: 240)
        // A blur reaches a little less far round a curve than past a straight edge.
        #expect(loop.allSatisfy { abs(hypot($0.x - 120, $0.y - 120) - 69) < 2.5 })
        #expect(area(of: loop) > 0)
        #expect(abs(contour.borderWidth - 0.1) < 1e-9)
        // It starts at its top, where the grid's read first, so a pattern cut along it starts
        // there on every launch.
        let top = loop.map(\.y).min() ?? 0
        #expect(abs((loop.first?.y ?? .infinity) - top) < 1.5)
    }

    /// A ring's hole traces as a loop of its own, running the other way, so a fill leaves it open.
    @Test func tracesAHoleTheOtherWay() throws {
        let source = try image(width: 200, height: 200) { context in
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
            context.addEllipse(in: CGRect(x: 20, y: 20, width: 160, height: 160))
            context.addEllipse(in: CGRect(x: 60, y: 60, width: 80, height: 80))
            context.fillPath(using: .evenOdd)
        }
        let contour = try #require(LayerImageEffects.contour(of: source, width: 10))
        let areas = contour.outline.map { area(of: pixels($0, side: 220)) }.sorted()

        #expect(areas.count == 2)
        #expect(areas.first ?? 0 < 0)
        #expect(areas.last ?? 0 > 0)
    }

    /// The trace keeps the picture's way up: a shape along the top traces along the top.
    @Test func tracesThePictureUpright() throws {
        let source = try image(width: 100, height: 100) { context in
            // Core Graphics counts up from the bottom, so this is the picture's top 20 rows.
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 80, width: 100, height: 20))
        }
        let contour = try #require(LayerImageEffects.contour(of: source, width: 10))
        let loop = pixels(try #require(contour.outline.first), side: 120)

        // The band spans 10 to 30 down the canvas, and its outline 0 to 40.
        #expect(loop.allSatisfy { $0.y < 41 })
        #expect(loop.contains { $0.y < 2 })
        #expect(loop.contains { $0.y > 38 })
    }

    /// A trace is in shares of the picture, so a small one matches a large one.
    @Test func tracesAlikeAtAnyResolution() throws {
        let id = UUID()
        let picture = ImageLayer(image: PlacedImage(assetIdentifier: nil, pixelWidth: 800, pixelHeight: 800, fileFormat: .png), borderWidth: 0.05)
        let largeSticker = try #require(SampleImages.sticker(for: id, width: 800, height: 800))
        let smallSticker = try #require(SampleImages.sticker(for: id, width: 400, height: 400))
        let large = try #require(LayerImageEffects.contour(of: largeSticker, for: picture))
        let small = try #require(LayerImageEffects.contour(of: smallSticker, for: picture))
        func bounds(_ contour: StickerContour) -> CGRect {
            let points = contour.outline.flatMap(\.self)
            let across = points.map(\.x)
            let down = points.map(\.y)
            let minX = across.min() ?? 0
            let minY = down.min() ?? 0
            return CGRect(x: minX, y: minY, width: (across.max() ?? 0) - minX, height: (down.max() ?? 0) - minY)
        }

        #expect(large.outline.count == small.outline.count)
        let difference = [bounds(large).minX - bounds(small).minX, bounds(large).minY - bounds(small).minY, bounds(large).width - bounds(small).width]
        #expect(difference.allSatisfy { abs($0) < 0.005 }, "\(difference)")
    }

    /// A thin stroke's core still rings it, though its outline reaches less than the border round
    /// it, so a styled edge never cuts the stroke's outline away.
    @Test func keepsACoreRoundAThinStroke() throws {
        let source = try image(width: 200, height: 100) { context in
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 99, y: 0, width: 3, height: 100))
        }
        let contour = try #require(LayerImageEffects.contour(of: source, width: 12))
        let core = CGMutablePath()
        for loop in contour.core {
            core.addLines(between: loop.map { CGPoint(x: $0.x * 224, y: $0.y * 124) })
            core.closeSubpath()
        }

        // The stroke spans 111 to 114 on the outline's canvas.
        #expect(core.contains(CGPoint(x: 112.5, y: 62)))
        #expect(core.boundingBox.width > 5)
        #expect(!core.contains(CGPoint(x: 105, y: 62)))
    }
}
