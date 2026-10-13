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

    private func file(_ name: String) throws -> URL {
        try FileManager.default.createDirectory(at: temporary.url, withIntermediateDirectories: true)
        return temporary.url.appending(path: name)
    }

    @Test func shrinksALargePhotoToTheMaximumSize() async throws {
        let source = try file("large.jpg")
        try TestImages.writeJPEG(width: 6000, height: 4000, to: source)
        let copy = try file("copy.jpg")

        let size = try await ImageImporter.makeCopy(of: .file(source), at: copy)

        #expect(size == CGSize(width: 3072, height: 2048))
        #expect(TestImages.pixelSize(of: copy) == size)
    }

    @Test func keepsMoreOfAPanoramasPhoto() async throws {
        let source = try file("wide.jpg")
        try TestImages.writeJPEG(width: 6000, height: 1500, to: source)

        let cell = try await ImageImporter.makeCopy(of: .file(source), at: try file("cell.jpg"))
        let panorama = try await ImageImporter.makeCopy(of: .file(source), at: try file("panorama.jpg"), limit: .panorama)

        #expect(cell == CGSize(width: 3072, height: 768))
        #expect(panorama == CGSize(width: 6000, height: 1500))
    }

    @Test func limitsAPanoramasCopyByWidthAndByPixels() {
        // As wide as ten slides, for a photo wider than that.
        #expect(ImageImporter.CopyLimit.panorama.longestSide(width: 40000, height: 2000) == 10800)
        // About 24 megapixels, 5796 by 4140, for a photo nearer square.
        #expect(ImageImporter.CopyLimit.panorama.longestSide(width: 7000, height: 5000) == 5796)
        #expect(ImageImporter.CopyLimit.panorama.longestSide(width: 0, height: 0) == 10800)
        #expect(ImageImporter.CopyLimit.cell.longestSide(width: 7000, height: 5000) == ImageImporter.maximumPixelSize)
    }

    @Test func keepsASmallPhotoAtItsOwnSize() async throws {
        let source = try file("small.jpg")
        try TestImages.writeJPEG(width: 800, height: 600, to: source)

        let size = try await ImageImporter.makeCopy(of: .file(source), at: try file("copy.jpg"))

        #expect(size == CGSize(width: 800, height: 600))
    }

    /// A phone held upright saves a landscape sensor image tagged to turn, which the copy turns for good.
    @Test func turnsAPhotoUprightByItsOrientation() async throws {
        let source = try file("rotated.jpg")
        try TestImages.writeJPEG(width: 400, height: 200, orientation: 6, to: source)
        let copy = try file("copy.jpg")

        let size = try await ImageImporter.makeCopy(of: .file(source), at: copy)

        #expect(size == CGSize(width: 200, height: 400))
        #expect(TestImages.pixelSize(of: copy) == size)
    }

    @Test func turnsACameraCaptureUpright() async throws {
        let drawn = try #require(SampleImages.image(for: UUID(), width: 400, height: 200))
        let capture = UIImage(cgImage: drawn, scale: 1, orientation: .right)

        let size = try await ImageImporter.makeCopy(of: .image(capture), at: try file("copy.jpg"))

        #expect(size == CGSize(width: 200, height: 400))
    }

    @Test func refusesAFileThatIsntAnImage() async throws {
        let source = try file("note.jpg")
        try Data("not an image".utf8).write(to: source)

        await #expect(throws: ImageImporter.ImportError.self) {
            try await ImageImporter.makeCopy(of: .file(source), at: try file("copy.jpg"))
        }
    }
}
