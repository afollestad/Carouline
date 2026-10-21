//
//  BorderStyleRenderingTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Carouline

/// Border styles as the export and the screen draw them, read back pixel by pixel.
@MainActor
struct BorderStyleRenderingTests {
    /// A 1080-pixel square slide's picture at natural size: 540 pixels square, centered.
    private let canvas = CGSize(width: 1080, height: 1080)
    /// A border of 0.06 of the picture's side.
    private let border: CGFloat = 32.4

    private static let red: CGImage? = {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            return nil
        }
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        return context.makeImage()
    }()

    /// A layer of the same id every run, since its id seeds a rough edge's randomness.
    private func layer(_ style: BorderStyle, color: RGBColor = .black) -> Layer {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 400)
        return Layer(
            id: UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)),
            content: .image(ImageLayer(image: image, borderWidth: 0.06, borderColor: color, borderStyle: style))
        )
    }

    /// `layer` drawn as the export draws it, a red picture over `background`.
    private func exported(_ layer: Layer, background: UIColor = .white) throws -> CGImage {
        let picture = LayerRenderer.Picture(try #require(Self.red), for: try #require(layer.picture))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return try #require(UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))
            LayerRenderer.draw(layer, picture: picture, in: context.cgContext, canvas: canvas, span: 1)
        }.cgImage)
    }

    /// The layer's frame, border included, on the canvas.
    private func box(of layer: Layer) -> CGRect {
        LayerGeometry.frame(of: layer, canvas: canvas, span: 1)
    }

    /// The pixels `depth` in from the top of `box`, across its middle, clear of its corners.
    private func row(of image: CGImage, in box: CGRect, depth: CGFloat) throws -> [TestImages.Pixel] {
        try stride(from: box.minX + 3 * border, through: box.maxX - 3 * border, by: 2).map { x in
            try #require(TestImages.pixel(of: image, at: CGPoint(x: x, y: box.minY + depth)))
        }
    }

    private func isBlack(_ pixel: TestImages.Pixel) -> Bool {
        pixel.red < 40 && pixel.green < 40 && pixel.blue < 40
    }

    private func isWhite(_ pixel: TestImages.Pixel) -> Bool {
        pixel.red > 215 && pixel.green > 215 && pixel.blue > 215
    }

    /// Each style cuts into its border's outer edge, showing the slide there, and leaves the rest
    /// of the border whole.
    @Test(arguments: [BorderStyle.jagged, .wavy, .scalloped, .torn, .postageStamp])
    func cutsTheBordersEdge(style: BorderStyle) throws {
        let layer = layer(style)
        let image = try exported(layer)

        let edge = try row(of: image, in: box(of: layer), depth: 0.12 * border)
        let inside = try row(of: image, in: box(of: layer), depth: 0.75 * border)
        #expect(edge.contains(where: isWhite), "\(style.name)")
        #expect(edge.contains(where: isBlack), "\(style.name)")
        #expect(inside.allSatisfy(isBlack), "\(style.name)")
    }

    /// A sticker's styled outline cuts in along its shape, and leaves the band round the sticker
    /// whole.
    @Test func cutsAStickersOutline() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 400, height: 400, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fillEllipse(in: CGRect(x: 80, y: 80, width: 240, height: 240))
        let disk = try #require(context.makeImage())
        let picture = ImageLayer(
            image: PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 400, fileFormat: .png),
            borderWidth: 0.06,
            borderColor: .black,
            borderStyle: .jagged
        )
        let layer = Layer(id: UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)), content: .image(picture))
        let decoded = LayerRenderer.Picture(disk, contourSource: disk, for: picture)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = try #require(UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))
            LayerRenderer.draw(layer, picture: decoded, in: context.cgContext, canvas: canvas, span: 1)
        }.cgImage)
        func ring(radius: CGFloat) throws -> [TestImages.Pixel] {
            try stride(from: 0, to: 2 * CGFloat.pi, by: .pi / 180).map { angle in
                try #require(TestImages.pixel(of: image, at: CGPoint(x: 540 + radius * cos(angle), y: 540 + radius * sin(angle))))
            }
        }

        // The disk is 162 pixels round, and its outline about 194, its teeth 16 deep.
        let tips = try ring(radius: 190)
        #expect(tips.contains(where: isWhite))
        #expect(tips.contains(where: isBlack))
        #expect(try ring(radius: 171).allSatisfy(isBlack))
    }

    /// An instant photo's frame is four borders deep below the picture.
    @Test func framesAnInstantPhotoDeeperBelow() throws {
        let layer = layer(.instant)
        let image = try exported(layer)
        let box = box(of: layer)

        #expect(abs(box.height - (540 + 5 * border)) < 0.5)
        let pictureBottom = box.minY + border + 540
        #expect(isBlack(try #require(TestImages.pixel(of: image, at: CGPoint(x: 540, y: pictureBottom + 2 * border)))))
        #expect(isWhite(try #require(TestImages.pixel(of: image, at: CGPoint(x: 540, y: box.maxY + 4)))))
        let picture = try #require(TestImages.pixel(of: image, at: CGPoint(x: 540, y: pictureBottom - 4)))
        #expect(picture.red > 230 && picture.green < 30)
    }

    /// A styled highlight cuts into its edge, but not through the padding over the letters, and
    /// leaves the rest of its box whole.
    @Test func cutsAHighlightsEdge() throws {
        let text = TextLayer(text: "HIGHLIGHTED", color: .black, isHighlighted: true, highlightStyle: .jagged)
        let layer = Layer(id: UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)), content: .text(text))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = try #require(UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))
            LayerRenderer.draw(layer, picture: nil, in: context.cgContext, canvas: canvas, span: 1)
        }.cgImage)
        // The padding above the letters, at the reference size, which fits a 1,080-pixel slide.
        let padding = TextLayerLayout.highlightPadding.height * TextLayerLayout.make(for: text).fontSize
        let box = box(of: layer)

        let edge = try stride(from: box.minX + 3 * padding, through: box.maxX - 3 * padding, by: 2).map { x in
            try #require(TestImages.pixel(of: image, at: CGPoint(x: x, y: box.minY + 0.12 * padding)))
        }
        let inside = try stride(from: box.minX + 3 * padding, through: box.maxX - 3 * padding, by: 2).map { x in
            try #require(TestImages.pixel(of: image, at: CGPoint(x: x, y: box.minY + 0.9 * padding)))
        }
        #expect(edge.contains(where: isWhite))
        #expect(edge.contains(where: isBlack))
        #expect(inside.allSatisfy(isBlack))
    }

    /// The screen cuts a highlight's edge from the layer's own randomness, as the export does.
    @Test func cutsAHighlightOnScreenAsTheExportDoes() throws {
        let text = TextLayer(text: "Torn", color: .black, isHighlighted: true, highlightStyle: .torn)
        let layer = Layer(content: .text(text))
        let size = LayerGeometry.frame(of: layer, canvas: CGSize(width: 800, height: 800), span: 1).size
        let view = LayerContentView(layer: layer, projectID: UUID(), background: .white, size: size)
            .frame(width: size.width, height: size.height)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let screen = try #require(renderer.cgImage)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let exported = try #require(UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            LayerRenderer.drawText(text, seed: layer.id, in: context.cgContext, box: CGRect(origin: .zero, size: size))
        }.cgImage)

        var compared = 0
        var differing = 0
        for y in stride(from: 1, to: size.height - 1, by: 2) {
            for x in stride(from: 1, to: size.width - 1, by: 3) {
                let onScreen = try #require(TestImages.pixel(of: screen, at: CGPoint(x: x, y: y)))
                let inExport = try #require(TestImages.pixel(of: exported, at: CGPoint(x: x, y: y)))
                compared += 1
                if abs(onScreen.red - inExport.red) > 64 {
                    differing += 1
                }
            }
        }
        // Pixels on a cut can be smoothed differently.
        #expect(differing <= compared / 25, "\(differing) of \(compared)")
    }

    /// A burnt border chars darker toward its edge, without cutting through to the slide there.
    @Test func charsABurntBorder() throws {
        let layer = layer(.burnt, color: .white)
        let image = try exported(layer, background: .blue)
        func brightness(_ pixels: [TestImages.Pixel]) -> Double {
            Double(pixels.reduce(0) { $0 + $1.red + $1.green + $1.blue }) / Double(3 * pixels.count)
        }

        let nearEdge = try row(of: image, in: box(of: layer), depth: 0.5 * border)
        let nearPicture = try row(of: image, in: box(of: layer), depth: 0.95 * border)
        #expect(!nearEdge.contains { $0.blue > 200 && $0.red < 60 })
        #expect(brightness(nearEdge) < brightness(nearPicture) - 20)
    }

    /// A rubber stamp's specks show the slide through its border, which is mostly inked.
    @Test func specksARubberStamp() throws {
        let layer = layer(.rubberStamp)
        let image = try exported(layer)

        let band = try row(of: image, in: box(of: layer), depth: 0.5 * border)
        #expect(band.contains(where: isWhite))
        #expect(Double(band.count(where: isBlack)) > 0.6 * Double(band.count))
    }

    /// The screen draws a styled border with the export's own code, so the two cut, char and
    /// speck it alike.
    @Test(arguments: [BorderStyle.burnt, .rubberStamp, .jagged])
    func drawsAStyledBorderOnScreenAsTheExportDoes(style: BorderStyle) throws {
        // Paper for a burnt edge, so its char shows, and ink for the rest.
        let layer = layer(style, color: style == .burnt ? RGBColor(red: 0.9, green: 0.85, blue: 0.7) : .black)
        // 336 points square at twice the scale, in the middle of a 400-point square.
        let view = LayerContentView(layer: layer, projectID: UUID(), background: .white, size: CGSize(width: 336, height: 336))
            .frame(width: 400, height: 400)
            .background(Color.white)
            .environment(\.imageLoader, SolidImageLoader(image: try #require(Self.red)))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let screen = try #require(renderer.cgImage)
        // The same 672 pixels, a 600-pixel picture and its border on a slide 1,200 wide, moved
        // onto an 800-pixel square.
        let decoded = LayerRenderer.Picture(try #require(Self.red), for: try #require(layer.picture))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let exported = try #require(UIGraphicsImageRenderer(size: CGSize(width: 800, height: 800), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 800))
            context.cgContext.translateBy(x: -200, y: 0)
            LayerRenderer.draw(layer, picture: decoded, in: context.cgContext, canvas: CGSize(width: 1200, height: 800), span: 1)
        }.cgImage)

        // Across the top border, from 64 pixels down for 36.
        var compared = 0
        var differing = 0
        for y in stride(from: 64, through: 100, by: 2) {
            for x in stride(from: 70, through: 730, by: 5) {
                let point = CGPoint(x: x, y: y)
                let onScreen = try #require(TestImages.pixel(of: screen, at: point))
                let inExport = try #require(TestImages.pixel(of: exported, at: point))
                compared += 1
                if max(abs(onScreen.red - inExport.red), abs(onScreen.green - inExport.green), abs(onScreen.blue - inExport.blue)) > 48 {
                    differing += 1
                }
            }
        }
        // Pixels on a cut can be smoothed differently.
        #expect(differing <= compared / 25, "\(style.name): \(differing) of \(compared)")
    }
}

private extension Layer {
    var picture: ImageLayer? {
        if case .image(let picture) = content {
            picture
        } else {
            nil
        }
    }
}
