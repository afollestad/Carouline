//
//  ImageImporterTests.swift
//  SwipesetTests
//

import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import Swipeset

struct ImageImporterTests {
    private let temporary = TemporaryDirectory("ImageImporterTests")
    /// A cell's and a panorama's copies, for a portrait project's 1350-pixel-tall slides.
    private let cell = ImageImporter.CopyLimit(slideHeight: 1350, isPanorama: false)
    private let panorama = ImageImporter.CopyLimit(slideHeight: 1350, isPanorama: true)

    private func file(_ name: String) throws -> URL {
        try FileManager.default.createDirectory(at: temporary.url, withIntermediateDirectories: true)
        return temporary.url.appending(path: name)
    }

    @Test func shrinksALargePhotoToTheMaximumSize() async throws {
        let source = try file("large.jpg")
        try TestImages.writeJPEG(width: 6000, height: 4000, to: source)
        let copy = try file("copy.jpg")

        let size = try await ImageImporter.makeCopy(of: .file(source), at: copy, limit: cell).size

        #expect(size == CGSize(width: 3072, height: 2048))
        #expect(TestImages.pixelSize(of: copy) == size)
    }

    @Test func keepsMoreOfAPanoramasPhoto() async throws {
        let source = try file("photo.jpg")
        try TestImages.writeJPEG(width: 4000, height: 3000, to: source)

        let inCell = try await ImageImporter.makeCopy(of: .file(source), at: try file("cell.jpg"), limit: cell).size
        let inPanorama = try await ImageImporter.makeCopy(of: .file(source), at: try file("panorama.jpg"), limit: panorama).size

        #expect(inCell == CGSize(width: 3072, height: 2304))
        #expect(inPanorama == CGSize(width: 4000, height: 3000))
    }

    /// A photo too wide for a cell's copy to fill a panorama of the project's slides keeps more,
    /// so its slide can become a panorama.
    @Test func keepsMoreOfAWidePhotoInACell() async throws {
        let source = try file("wide.jpg")
        try TestImages.writeJPEG(width: 6000, height: 1500, to: source)

        let size = try await ImageImporter.makeCopy(of: .file(source), at: try file("copy.jpg"), limit: cell).size

        #expect(size == CGSize(width: 6000, height: 1500))
    }

    /// Stored wide but tagged to turn, the photo stands tall, which a cell's copy needs no more of.
    @Test func judgesAPhotosWidthUpright() async throws {
        let source = try file("turned.jpg")
        try TestImages.writeJPEG(width: 6000, height: 1500, orientation: 6, to: source)

        let size = try await ImageImporter.makeCopy(of: .file(source), at: try file("copy.jpg"), limit: cell).size

        #expect(size == CGSize(width: 768, height: 3072))
    }

    @Test func limitsACopyByThePanoramaItCouldFill() {
        // As wide as ten slides, for a photo wider than that.
        #expect(panorama.longestSide(width: 40000, height: 2000) == 10800)
        // About 24 megapixels, 5796 by 4140, for a photo nearer square.
        #expect(panorama.longestSide(width: 7000, height: 5000) == 5796)
        #expect(panorama.longestSide(width: 0, height: 0) == 10800)
        // A cell keeps more only of a photo too wide for its usual copy to fill a panorama.
        #expect(cell.longestSide(width: 7000, height: 5000) == ImageImporter.maximumPixelSize)
        #expect(cell.longestSide(width: 2000, height: 8000) == ImageImporter.maximumPixelSize)
        #expect(cell.longestSide(width: 8000, height: 2000) == 9797)
        #expect(cell.longestSide(width: 0, height: 0) == ImageImporter.maximumPixelSize)
        // Landscape slides are short enough for the usual copy to fill a panorama of them.
        let landscapeCell = ImageImporter.CopyLimit(slideHeight: 566, isPanorama: false)
        #expect(landscapeCell.longestSide(width: 8000, height: 2000) == ImageImporter.maximumPixelSize)
    }

    @Test func keepsASmallPhotoAtItsOwnSize() async throws {
        let source = try file("small.jpg")
        try TestImages.writeJPEG(width: 800, height: 600, to: source)

        let size = try await ImageImporter.makeCopy(of: .file(source), at: try file("copy.jpg"), limit: cell).size

        #expect(size == CGSize(width: 800, height: 600))
    }

    /// A phone held upright saves a landscape sensor image tagged to turn, which the copy turns for good.
    @Test func turnsAPhotoUprightByItsOrientation() async throws {
        let source = try file("rotated.jpg")
        try TestImages.writeJPEG(width: 400, height: 200, orientation: 6, to: source)
        let copy = try file("copy.jpg")

        let size = try await ImageImporter.makeCopy(of: .file(source), at: copy, limit: cell).size

        #expect(size == CGSize(width: 200, height: 400))
        #expect(TestImages.pixelSize(of: copy) == size)
    }

    @Test func turnsACameraCaptureUpright() async throws {
        let drawn = try #require(SampleImages.image(for: UUID(), width: 400, height: 200))
        let capture = UIImage(cgImage: drawn, scale: 1, orientation: .right)

        let size = try await ImageImporter.makeCopy(of: .image(capture), at: try file("copy.jpg"), limit: cell).size

        #expect(size == CGSize(width: 200, height: 400))
    }

    /// A cell's copy is a JPEG, which has no transparency, so a cut-out picture's clear parts
    /// turn white, as they show on most backgrounds, rather than black.
    @Test func flattensAClearPictureOntoWhite() async throws {
        let source = try file("cutout.png")
        try TestImages.writePNG(width: 200, height: 100, to: source)
        let copy = try file("copy.jpg")

        let made = try await ImageImporter.makeCopy(of: .file(source), at: copy, limit: cell)

        #expect(made.format == .jpeg)
        let image = try #require(TestImages.decode(copy))
        let clear = try #require(TestImages.pixel(of: image, at: CGPoint(x: 50, y: 50)))
        let opaque = try #require(TestImages.pixel(of: image, at: CGPoint(x: 150, y: 50)))
        #expect(clear.red > 250 && clear.green > 250 && clear.blue > 250)
        #expect(opaque.red < 5 && opaque.green < 5 && opaque.blue > 250)
    }

    @Test func keepsALayerPicturesTransparencyAsAPNG() async throws {
        let source = try file("cutout.png")
        try TestImages.writePNG(width: 200, height: 100, to: source)
        let copy = try file("layer")

        let made = try await ImageImporter.makeLayerCopy(of: .file(source), at: copy)

        #expect(made.format == .png)
        let image = try #require(TestImages.decode(copy))
        #expect(TestImages.pixel(of: image, at: CGPoint(x: 50, y: 50))?.alpha == 0)
        #expect(TestImages.pixel(of: image, at: CGPoint(x: 150, y: 50)) == TestImages.Pixel(red: 0, green: 0, blue: 255, alpha: 255))
    }

    /// An alpha channel with nothing clear in it, as screenshots have, keeps nothing a JPEG loses.
    @Test func copiesAnOpaquePNGLayerPictureAsAJPEG() async throws {
        let source = try file("screenshot.png")
        try TestImages.writePNG(width: 200, height: 100, isOpaque: true, to: source)
        let copy = try file("layer")

        let made = try await ImageImporter.makeLayerCopy(of: .file(source), at: copy)

        #expect(made.format == .jpeg)
        #expect(TestImages.decode(copy) != nil)
    }

    @Test func shrinksALayerPictureToTheLargestALayerDraws() async throws {
        let source = try file("large.jpg")
        try TestImages.writeJPEG(width: 4000, height: 3000, to: source)
        let copy = try file("layer")

        let made = try await ImageImporter.makeLayerCopy(of: .file(source), at: copy)

        #expect(made.size == CGSize(width: 2160, height: 1620))
        #expect(made.format == .jpeg)
    }

    @Test func refusesAFileThatIsntAnImage() async throws {
        let source = try file("note.jpg")
        try Data("not an image".utf8).write(to: source)

        await #expect(throws: ImageImporter.ImportError.self) {
            try await ImageImporter.makeCopy(of: .file(source), at: try file("copy.jpg"), limit: cell)
        }
    }
}
