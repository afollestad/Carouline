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
