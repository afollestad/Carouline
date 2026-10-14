//
//  CropGeometryTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

struct CropGeometryTests {
    /// A landscape photo in a portrait cell, so filling crops its sides.
    private let image = CGSize(width: 4000, height: 3000)
    private let cell = CGSize(width: 300, height: 400)

    @Test func theDefaultCropFillsTheCellCentered() {
        let frame = CropGeometry.frame(imageSize: image, cellSize: cell, crop: ImageCrop())
        #expect(abs(frame.height - 400) < 0.001)
        #expect(abs(frame.midX - 150) < 0.001)
        #expect(abs(frame.midY - 200) < 0.001)
    }

    @Test func aCenterPastTheEdgeStillCoversTheCell() {
        let crop = ImageCrop(scale: 1, centerX: 0, centerY: 1)
        let frame = CropGeometry.frame(imageSize: image, cellSize: cell, crop: crop)
        #expect(frame.minX == 0)
        #expect(frame.minY <= 0 && frame.maxY >= cell.height)
    }

    @Test func panningFollowsTheDragUntilTheEdge() {
        let start = ImageCrop()
        let before = CropGeometry.frame(imageSize: image, cellSize: cell, crop: start)
        let panned = CropGeometry.panned(start, by: CGSize(width: 50, height: 0), imageSize: image, cellSize: cell)
        let after = CropGeometry.frame(imageSize: image, cellSize: cell, crop: panned)
        #expect(abs(after.minX - (before.minX + 50)) < 0.001)

        let far = CropGeometry.panned(start, by: CGSize(width: 10_000, height: 10_000), imageSize: image, cellSize: cell)
        let pinned = CropGeometry.frame(imageSize: image, cellSize: cell, crop: far)
        #expect(abs(pinned.minX) < 0.001)
        #expect(abs(pinned.minY) < 0.001)
    }

    @Test func zoomingKeepsThePointUnderTheAnchorInPlace() {
        let start = ImageCrop()
        let anchor = CGPoint(x: 100, y: 120)
        let before = CropGeometry.frame(imageSize: image, cellSize: cell, crop: start)
        let zoomed = CropGeometry.zoomed(start, by: 2, about: anchor, imageSize: image, cellSize: cell)
        let after = CropGeometry.frame(imageSize: image, cellSize: cell, crop: zoomed)
        #expect(abs(zoomed.scale - 2) < 0.001)
        let unitBefore = (anchor.x - before.minX) / before.width
        let unitAfter = (anchor.x - after.minX) / after.width
        #expect(abs(unitBefore - unitAfter) < 0.0001)
    }

    @Test func zoomStaysBetweenFillingAndTheMaximum() {
        let center = CGPoint(x: 150, y: 200)
        let out = CropGeometry.zoomed(ImageCrop(), by: 0.2, about: center, imageSize: image, cellSize: cell)
        #expect(out.scale == 1)
        let deep = CropGeometry.zoomed(ImageCrop(), by: 50, about: center, imageSize: image, cellSize: cell)
        #expect(deep.scale == ImageCrop.maximumScale)
    }

    /// The screen and the export draw the same crop at different sizes, so the photo must land
    /// in proportionally the same place in both.
    @Test func framesScaleWithTheCell() {
        let crop = ImageCrop(scale: 2.5, centerX: 0.3, centerY: 0.65)
        let small = CropGeometry.frame(imageSize: image, cellSize: cell, crop: crop)
        let large = CropGeometry.frame(imageSize: image, cellSize: CGSize(width: 900, height: 1200), crop: crop)
        #expect(abs(large.minX - small.minX * 3) < 0.001)
        #expect(abs(large.minY - small.minY * 3) < 0.001)
        #expect(abs(large.width - small.width * 3) < 0.001)
    }
}
