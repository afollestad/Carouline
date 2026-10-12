//
//  DiskImageLoaderTests.swift
//  SwipesetTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Swipeset

struct DiskImageLoaderTests {
    private let temporary = TemporaryDirectory("DiskImageLoaderTests")

    private var paths: ProjectPaths {
        ProjectPaths(root: temporary.url, temporary: temporary.url.appending(path: "tmp", directoryHint: .isDirectory))
    }

    @Test func decodesACopyNoLargerThanAsked() async throws {
        let projectID = UUID()
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 3000, pixelHeight: 2000)
        try FileManager.default.createDirectory(at: paths.imagesFolder(for: projectID), withIntermediateDirectories: true)
        try TestImages.writeJPEG(width: 3000, height: 2000, to: paths.imageFile(image.id, in: projectID))
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
}
