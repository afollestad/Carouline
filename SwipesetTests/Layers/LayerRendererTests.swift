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
    /// its right half and clear on its left, but those in `drawn` as given, and that finds no
    /// copy for `missing`.
    private func exporter(missing: Set<UUID> = [], drawn: [UUID: CGImage] = [:]) -> SlideExporter {
        SlideExporter(paths: paths) { image, _, _ in
            guard !missing.contains(image.id) else {
                return nil
            }
            if let given = drawn[image.id] {
                return given
            }
            return image.fileFormat == .png ? Self.halfClear : Self.red
        }
    }

    /// Red on one side and blue on the other: its left and right halves, or its top and bottom.
    private static func redAndBlue(width: Int = 400, height: Int = 400, stacked: Bool = false) throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        // Core Graphics counts up from the bottom, so the top half is the upper one here.
        let red = stacked ? CGRect(x: 0, y: height / 2, width: width, height: height / 2) : CGRect(x: 0, y: 0, width: width / 2, height: height)
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(red)
        return try #require(context.makeImage())
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

    private func picture(
        _ format: ImageFileFormat = .jpeg,
        border: Double = 0,
        blur: Double = 0,
        placement: LayerPlacement = LayerPlacement()
    ) -> Layer {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 400, fileFormat: format)
        return Layer(content: .image(ImageLayer(image: image, borderWidth: border, borderColor: .black, blur: blur)), placement: placement)
    }

    /// The slides exported from a project of `slides` in `style`, decoded, on square 1080-pixel
    /// slides.
    private func export(
        _ slides: [Slide],
        style: SlideStyle = .standard,
        missing: Set<UUID> = [],
        drawn: [UUID: CGImage] = [:]
    ) async throws -> (images: [CGImage], result: ExportResult) {
        let project = Project(name: "Layers", aspectRatio: .square, style: style, slides: slides)
        let result = try await exporter(missing: missing, drawn: drawn).export(project)
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

    private func isBlue(_ pixel: TestImages.Pixel) -> Bool {
        pixel.red < 30 && pixel.green < 30 && pixel.blue > 230
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

    /// A transparent picture's border outlines its shape, rather than ringing its box, and its
    /// clear parts show the slide through them.
    @Test func outlinesATransparentPicture() async throws {
        let image = try await export([Slide(layout: .single, layers: [picture(.png, border: 0.1)])]).images[0]

        // A 540-pixel picture from 270 to 810, opaque from 540, and a 54-pixel outline around that.
        #expect(isRed(try pixel(image, 680, 540)))
        #expect(isBlack(try pixel(image, 515, 540)))
        #expect(isBlack(try pixel(image, 680, 243)))
        #expect(isWhite(try pixel(image, 400, 540)))
        #expect(isWhite(try pixel(image, 240, 540)))
    }

    /// A blurred slide softens its photos inside their cells, while their edges against the
    /// slide's border stay sharp, as on screen.
    @Test func blursACellInsideItsEdges() async throws {
        let photo = PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 400)
        let slide = Slide(layout: .single, cells: [Cell(image: photo)], blur: 0.02)
        let style = SlideStyle(spacing: 0, border: 0.05, background: .white)
        let image = try await export([slide], style: style, drawn: [photo.id: Self.redAndBlue()]).images[0]

        // Red then blue, split at 540, inside a 54-pixel border.
        let middle = try pixel(image, 540, 540)
        #expect((60...200).contains(middle.red) && (60...200).contains(middle.blue))
        #expect(isRed(try pixel(image, 56, 540)))
        #expect(isWhite(try pixel(image, 51, 540)))
    }

    /// A blurred photo framed off its middle keeps its way up and its place.
    @Test func blursAPhotoWhereItsFramed() async throws {
        // A tall photo, red over blue, framed a little above its middle.
        let photo = PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 800, crop: ImageCrop(centerY: 0.4))
        let slide = Slide(layout: .single, cells: [Cell(image: photo)], blur: 0.02)
        let style = SlideStyle(spacing: 0, border: 0.05, background: .white)
        let image = try await export([slide], style: style, drawn: [photo.id: Self.redAndBlue(height: 800, stacked: true)]).images[0]

        // Drawn 972 by 1944 across a 972-pixel cell, so its middle falls 194 below the cell's, at 734.
        #expect(isRed(try pixel(image, 540, 600)))
        #expect(isBlue(try pixel(image, 540, 900)))
    }

    /// A blurred panorama's photo blurs as one, so its pieces meet without a seam.
    @Test func blursAPanoramaAcrossItsCuts() async throws {
        let photo = PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 400)
        let slide = Slide(layout: .panorama, span: 2, cells: [Cell(image: photo)], blur: 0.02)
        let style = SlideStyle(spacing: 0, border: 0, background: .white)
        let images = try await export([slide], style: style, drawn: [photo.id: Self.redAndBlue()]).images

        // Red then blue, split at the cut, which a sharp photo would meet at in full red and blue.
        let left = try pixel(images[0], 1079, 540)
        let right = try pixel(images[1], 0, 540)
        #expect((60...200).contains(left.red) && (60...200).contains(right.blue))
        #expect(abs(left.red - right.red) < 16 && abs(left.blue - right.blue) < 16)
    }

    /// An opaque picture's blur stays sharp at its edges and in its frame, as on screen.
    @Test func blursAnOpaquePictureInItsFrame() async throws {
        let image = try await export([Slide(layout: .single, layers: [picture(blur: 0.05)])]).images[0]

        // A 540-pixel picture from 270 to 810.
        #expect(isRed(try pixel(image, 273, 540)))
        #expect(isWhite(try pixel(image, 266, 540)))
    }

    /// A transparent picture's blur spreads past its edges, as a soft-edged cutout's would.
    @Test func spreadsATransparentPicturesBlur() async throws {
        let image = try await export([Slide(layout: .single, layers: [picture(.png, blur: 0.05)])]).images[0]

        // Red from 540 to the picture's edge at 810, and a 27-pixel blur past it.
        let past = try pixel(image, 816, 540)
        #expect(past.red > 240 && past.green < 200)
        #expect(isWhite(try pixel(image, 1000, 540)))
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
