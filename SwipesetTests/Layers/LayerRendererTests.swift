//
//  LayerRendererTests.swift
//  SwipesetTests
//

import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Swipeset

/// Layers as the export draws them, read back pixel by pixel.
struct LayerRendererTests {
    private let temporary = TemporaryDirectory("LayerRendererTests")

    private var paths: ProjectPaths {
        ProjectPaths(root: temporary.url, temporary: temporary.url.appending(path: "tmp", directoryHint: .isDirectory))
    }

    /// An exporter that draws every opaque picture solid red, and every transparent one red on
    /// its right half and clear on its left, and that finds no copy for `missing`.
    private func exporter(missing: Set<UUID> = []) -> SlideExporter {
        SlideExporter(paths: paths) { image, _, _ in
            guard !missing.contains(image.id) else {
                return nil
            }
            return image.fileFormat == .png ? Self.halfClear : Self.red
        }
    }

    private static let red = solid(red: 1, green: 0, blue: 0)

    private static func solid(red: Double, green: Double, blue: Double) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            return nil
        }
        context.setFillColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        return context.makeImage()
    }

    private static let halfClear: CGImage? = {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 20, y: 0, width: 20, height: 40))
        return context.makeImage()
    }()

    private func picture(_ format: ImageFileFormat = .jpeg, border: Double = 0, placement: LayerPlacement = LayerPlacement()) -> Layer {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 400, fileFormat: format)
        return Layer(content: .image(ImageLayer(image: image, borderWidth: border, borderColor: .black)), placement: placement)
    }

    /// The slides exported from a project of `slides`, decoded, on square 1080-pixel slides.
    private func export(_ slides: [Slide], missing: Set<UUID> = []) async throws -> (images: [CGImage], result: ExportResult) {
        let result = try await exporter(missing: missing).export(Project(name: "Layers", aspectRatio: .square, slides: slides))
        return (try result.files.map { try #require(TestImages.decode($0)) }, result)
    }

    private func pixel(_ image: CGImage, _ x: CGFloat, _ y: CGFloat) throws -> TestImages.Pixel {
        try #require(TestImages.pixel(of: image, at: CGPoint(x: x, y: y)))
    }

    private func isRed(_ pixel: TestImages.Pixel) -> Bool {
        pixel.red > 230 && pixel.green < 30 && pixel.blue < 30
    }

    private func isWhite(_ pixel: TestImages.Pixel) -> Bool {
        pixel.red > 240 && pixel.green > 240 && pixel.blue > 240
    }

    private func isBlack(_ pixel: TestImages.Pixel) -> Bool {
        pixel.red < 25 && pixel.green < 25 && pixel.blue < 25
    }

    /// A picture at natural size is half a slide across, centered, over the background.
    @Test func drawsAPictureWhereItSits() async throws {
        let image = try await export([Slide(layout: .single, layers: [picture()])]).images[0]

        #expect(isRed(try pixel(image, 540, 540)))
        #expect(isRed(try pixel(image, 280, 540)))
        #expect(isWhite(try pixel(image, 260, 540)))
    }

    /// An opaque picture's border is a ring of its color around it, a share of its longer side.
    @Test func ringsAnOpaquePicture() async throws {
        let image = try await export([Slide(layout: .single, layers: [picture(border: 0.1)])]).images[0]

        // A 540-pixel picture with a 54-pixel ring: 216 to 270 either side.
        #expect(isBlack(try pixel(image, 240, 540)))
        #expect(isRed(try pixel(image, 300, 540)))
        #expect(isWhite(try pixel(image, 200, 540)))
    }

    /// A transparent picture's clear parts show the slide through them, and it draws no ring.
    @Test func showsTheSlideThroughATransparentPicture() async throws {
        let image = try await export([Slide(layout: .single, layers: [picture(.png, border: 0.1)])]).images[0]

        #expect(isWhite(try pixel(image, 400, 540)))
        #expect(isRed(try pixel(image, 680, 540)))
        #expect(isWhite(try pixel(image, 240, 540)))
    }

    /// A layer across a panorama's cut is split between the slides either side of it, each half
    /// where it sat on the whole.
    @Test func splitsALayerAcrossAPanoramasCut() async throws {
        let crossing = picture(placement: LayerPlacement(centerX: 1))
        let images = try await export([Slide(layout: .panorama, span: 3, layers: [crossing])]).images

        #expect(images.count == 3)
        // Half a slide wide, centered on the first cut: the last 270 pixels of the first slide
        // and the first 270 of the second.
        #expect(isRed(try pixel(images[0], 1070, 540)))
        #expect(isRed(try pixel(images[0], 820, 540)))
        #expect(isWhite(try pixel(images[0], 800, 540)))
        #expect(isRed(try pixel(images[1], 10, 540)))
        #expect(isRed(try pixel(images[1], 260, 540)))
        #expect(isWhite(try pixel(images[1], 280, 540)))
        #expect(isWhite(try pixel(images[2], 540, 540)))
    }

    /// A positive turn goes clockwise, as it does on screen.
    @Test func turnsClockwise() async throws {
        // A thin strip, which a quarter turn stands on end.
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 40)
        let strip = Layer(content: .image(ImageLayer(image: image)), placement: LayerPlacement(centerX: 0.5, centerY: 0.5, rotation: .pi / 2))
        let rendered = try await export([Slide(layout: .single, layers: [strip])]).images[0]

        #expect(isRed(try pixel(rendered, 540, 300)))
        #expect(isWhite(try pixel(rendered, 300, 540)))
    }

    /// Drawn at two sizes, text matches once scaled, highlight and all, so the screen, which draws
    /// it small, shows what the export draws large.
    @Test func drawsTextAlikeAtEverySize() throws {
        let text = TextLayer(text: "Hello there", color: .black, isHighlighted: true)
        let reference = TextLayerLayout.make(for: text).boxSize(isHighlighted: true)
        let small = try render(text, box: CGSize(width: (reference.width / 4).rounded(), height: (reference.height / 4).rounded()))
        let large = try render(text, box: reference)

        let shrunk = try reds(of: large, width: small.width, height: small.height)
        let drawn = try reds(of: small, width: small.width, height: small.height)
        let difference = zip(shrunk, drawn).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) } / drawn.count
        // Antialiasing differs along the letters' edges; their shapes and the box match.
        #expect(difference < 16)
    }

    /// A shadow falls below the letters: the shadow's weight sits lower than the letters' own.
    @Test func castsAShadowBelowTheLetters() throws {
        let box = TextLayerLayout.make(for: TextLayer(text: "Hello")).boxSize(isHighlighted: false)
        // White letters on white leave only their shadow to see; black ones, only the letters.
        let shadow = try render(TextLayer(text: "Hello", color: .white, hasShadow: true), box: box, padding: 80)
        let letters = try render(TextLayer(text: "Hello", color: .black), box: box, padding: 80)

        let drop = try darkCenterY(of: shadow) - darkCenterY(of: letters)
        let offset = LayerRenderer.shadowOffset * TextLayerLayout.make(for: TextLayer(text: "Hello")).fontSize
        #expect(abs(drop - offset) < 1.5, "drop \(drop), offset \(offset)")
    }

    /// The screen draws text in a SwiftUI canvas, whose context differs from the export's, and
    /// whose shadow must fall the same way.
    @MainActor
    @Test func castsTheSameShadowOnScreen() throws {
        let box = TextLayerLayout.make(for: TextLayer(text: "Hello")).boxSize(isHighlighted: false)
        let shadow = try renderOnScreen(TextLayer(text: "Hello", color: .white, hasShadow: true), size: box)
        let letters = try renderOnScreen(TextLayer(text: "Hello", color: .black), size: box)

        let drop = try darkCenterY(of: shadow) - darkCenterY(of: letters)
        let offset = LayerRenderer.shadowOffset * TextLayerLayout.make(for: TextLayer(text: "Hello")).fontSize
        #expect(abs(drop - offset) < 1.5, "drop \(drop), offset \(offset)")
    }

    @Test func leavesOutAMissingPicture() async throws {
        let missing = picture()
        let (images, result) = try await export([Slide(layout: .single, layers: [missing])], missing: [try #require(missing.image?.id)])

        #expect(result.missingLayerImages == 1)
        #expect(result.missingPhotos == 0)
        #expect(isWhite(try pixel(images[0], 540, 540)))
    }

    /// `text` drawn by `LayerRenderer.drawText` into `box`, with `padding` around it.
    private func render(_ text: TextLayer, box: CGSize, padding: CGFloat = 0, background: UIColor = .white) throws -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: box.width + 2 * padding, height: box.height + 2 * padding)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            LayerRenderer.drawText(text, in: context.cgContext, box: CGRect(origin: CGPoint(x: padding, y: padding), size: box))
        }
        return try #require(image.cgImage)
    }

    /// The red channel of `image` drawn at `width` by `height`, row by row.
    private func reds(of image: CGImage, width: Int, height: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 0, to: bytes.count, by: 4).map { bytes[$0] }
    }

    /// How far down `image` its darkness sits on average, weighted by how dark each pixel is.
    private func darkCenterY(of image: CGImage) throws -> CGFloat {
        let reds = try reds(of: image, width: image.width, height: image.height)
        var weight = 0.0
        var sum = 0.0
        for (index, red) in reds.enumerated() {
            let darkness = Double(255 - Int(red))
            weight += darkness
            sum += darkness * (Double(index / image.width) + 0.5)
        }
        return CGFloat(sum / max(weight, 1))
    }

    /// `text` as the slide on screen draws it, at the reference size, on white.
    @MainActor
    private func renderOnScreen(_ text: TextLayer, size: CGSize) throws -> CGImage {
        let view = LayerContentView(layer: Layer(content: .text(text)), projectID: UUID(), background: .white, size: size)
            .padding(80)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try #require(renderer.cgImage)
    }
}
