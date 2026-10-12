//
//  SlideExporterTests.swift
//  SwipesetTests
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Swipeset

struct SlideExporterTests {
    private let temporary = TemporaryDirectory("SlideExporterTests")

    private var paths: ProjectPaths {
        ProjectPaths(root: temporary.url, temporary: temporary.url.appending(path: "tmp", directoryHint: .isDirectory))
    }

    /// Draws every photo as a wide image, red on its left half and blue on its right.
    private var exporter: SlideExporter {
        SlideExporter(paths: paths) { _, _, _ in
            Self.halves
        }
    }

    private static let halves: CGImage? = {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            return nil
        }
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 100, y: 0, width: 100, height: 100))
        return context.makeImage()
    }()

    private func photo(centerX: Double = 0.5) -> Cell {
        Cell(image: PlacedImage(assetIdentifier: nil, pixelWidth: 200, pixelHeight: 100, crop: ImageCrop(centerX: centerX)))
    }

    @Test(arguments: AspectRatio.allCases)
    func writesEachSlideAtItsShapesSize(_ ratio: AspectRatio) async throws {
        let project = Project(name: "Size", aspectRatio: ratio, slides: [Slide(layout: .single, cells: [photo()])])

        let file = try #require(try await exporter.export(project).files.first)

        let image = try #require(Self.decode(file))
        #expect(CGSize(width: image.width, height: image.height) == ratio.exportSize)
        #expect(image.bitsPerComponent == 8)
        #expect(image.colorSpace?.name == CGColorSpace.sRGB)
    }

    @Test func namesFilesInOrderAfterTheProject() async throws {
        let slides = (0..<3).map { _ in Slide(layout: .single) }
        let project = Project(name: "Trip: Day/Night", aspectRatio: .square, slides: slides)

        let names = try await exporter.export(project).files.map(\.lastPathComponent)

        #expect(names == ["Trip- Day-Night 01.jpg", "Trip- Day-Night 02.jpg", "Trip- Day-Night 03.jpg"])
    }

    @Test func fillsGapsAndBorderWithTheBackground() async throws {
        let style = SlideStyle(spacing: 0.05, border: 0.05, background: RGBColor(red: 0, green: 1, blue: 0))
        let slide = Slide(layout: .twoColumns, cells: [photo(), photo()])
        let project = Project(name: "Style", aspectRatio: .square, style: style, slides: [slide])

        let file = try #require(try await exporter.export(project).files.first)

        let image = try #require(Self.decode(file))
        // The border's corner, and the middle of the gap between the two cells.
        for point in [CGPoint(x: 10, y: 10), CGPoint(x: 540, y: 540)] {
            let pixel = try #require(Self.pixel(of: image, at: point))
            #expect(pixel.green > 230 && pixel.red < 25 && pixel.blue < 25)
        }
    }

    /// A tall cell shows a slice of the wide photo; its crop decides which half.
    @Test func placesPhotosByTheirCrop() async throws {
        let style = SlideStyle(spacing: 0, border: 0, background: .white)
        let slide = Slide(layout: .twoColumns, cells: [photo(centerX: 0.25), photo(centerX: 0.75)])
        let project = Project(name: "Crop", aspectRatio: .square, style: style, slides: [slide])

        let file = try #require(try await exporter.export(project).files.first)

        let image = try #require(Self.decode(file))
        let left = try #require(Self.pixel(of: image, at: CGPoint(x: 270, y: 540)))
        let right = try #require(Self.pixel(of: image, at: CGPoint(x: 810, y: 540)))
        #expect(left.red > 230 && left.blue < 25)
        #expect(right.blue > 230 && right.red < 25)
    }

    @Test func countsEmptyCellsAndMissingPhotos() async throws {
        let project = Project(name: "Gaps", aspectRatio: .portrait, slides: [Slide(layout: .grid, cells: [photo(), Cell(), photo(), Cell()])])
        let missing = SlideExporter(paths: paths) { _, _, _ in nil }

        let result = try await missing.export(project)

        #expect(result.emptyCells == 2)
        #expect(result.missingPhotos == 2)
        #expect(result.slides.count == 1)
    }

    @Test func keepsOnlyTheLatestExport() async throws {
        let project = Project(name: "Again", aspectRatio: .square, slides: [Slide(layout: .single)])

        _ = try await exporter.export(project)
        let latest = try await exporter.export(project)

        let sessions = try FileManager.default.contentsOfDirectory(atPath: paths.exports.path(percentEncoded: false))
        #expect(sessions == [latest.files[0].deletingLastPathComponent().lastPathComponent])
    }

    // MARK: Helpers

    private static func decode(_ file: URL) -> CGImage? {
        CGImageSourceCreateWithURL(file as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
    }

    private struct Pixel {
        let red: Int
        let green: Int
        let blue: Int
    }

    /// The 8-bit sRGB color at `point`, measured from the top-left.
    private static func pixel(of image: CGImage, at point: CGPoint) -> Pixel? {
        var bytes = [UInt8](repeating: 0, count: 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            return nil
        }
        let height = CGFloat(image.height)
        context.draw(image, in: CGRect(x: -point.x, y: point.y - height + 1, width: CGFloat(image.width), height: height))
        return Pixel(red: Int(bytes[0]), green: Int(bytes[1]), blue: Int(bytes[2]))
    }
}
