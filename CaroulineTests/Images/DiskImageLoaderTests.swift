//
//  DiskImageLoaderTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

struct DiskImageLoaderTests {
    private let temporary = TemporaryDirectory("DiskImageLoaderTests")

    private var paths: ProjectPaths {
        ProjectPaths(root: temporary.url, temporary: temporary.url.appending(path: "tmp", directoryHint: .isDirectory))
    }

    @Test func decodesACopyNoLargerThanAsked() async throws {
        let projectID = UUID()
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 3000, pixelHeight: 2000)
        try FileManager.default.createDirectory(at: paths.imagesFolder(for: projectID), withIntermediateDirectories: true)
        try TestImages.writeJPEG(width: 3000, height: 2000, to: paths.imageFile(named: image.fileName, in: projectID))
        let loader = DiskImageLoader(paths: paths)
        let request = ImageRequest(projectID: projectID, image: image, displayedPixels: 400)

        let decoded = try #require(await loader.image(request))

        #expect(request.maxPixelSize == 512)
        #expect(max(decoded.width, decoded.height) == 512)
        #expect(loader.cachedImage(request) != nil)
    }

    @Test func reportsAMissingCopyAsNothing() async {
        let image = PlacedImage(assetIdentifier: "A/B", pixelWidth: 10, pixelHeight: 10)
        let loader = DiskImageLoader(paths: paths)

        #expect(await loader.image(ImageRequest(projectID: UUID(), image: image, displayedPixels: 100)) == nil)
    }

    /// A slide's cell is never wider than a preset's cell copy, so a zoomed photo in one decodes
    /// no larger than the copy, as it always has.
    @Test func capsACellsDecodeAtACellCopy() {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 9000, pixelHeight: 1500)

        #expect(ImageRequest(projectID: UUID(), image: image, displayedPixels: 5000, cellPixels: 1236).maxPixelSize == 3072)
    }

    /// A panorama's cell is several slides wide, so its photo decodes as wide as it's shown, in
    /// steps of about half again.
    @Test func decodesAPanoramaAsWideAsItsCell() {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 9000, pixelHeight: 1500)

        #expect(ImageRequest(projectID: UUID(), image: image, displayedPixels: 4950, cellPixels: 4950).maxPixelSize == 6144)
        #expect(ImageRequest(projectID: UUID(), image: image, displayedPixels: 9900, cellPixels: 4950).maxPixelSize == 6144)
        #expect(ImageRequest(projectID: UUID(), image: image, displayedPixels: 20_000, cellPixels: 20_000).maxPixelSize == 12_288)
    }
}
