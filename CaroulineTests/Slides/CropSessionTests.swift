//
//  CropSessionTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

@MainActor
struct CropSessionTests {
    /// Four times as wide as the square cell, so it has room to pan across.
    private let image = PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 100)

    private func session() -> CropSession {
        let session = CropSession()
        session.cellSize = CGSize(width: 100, height: 100)
        return session
    }

    private func panned(_ crop: ImageCrop, by x: CGFloat) -> ImageCrop {
        CropGeometry.panned(crop, by: CGSize(width: x, height: 0), imageSize: image.pixelSize, cellSize: CGSize(width: 100, height: 100))
    }

    /// A gesture reports how far it has moved in all, so each update builds on the crop it began
    /// from rather than the last update's.
    @Test func framesFromTheCropTheGestureBeganWith() {
        let session = session()

        session.frame(image, translation: CGSize(width: -50, height: 0), magnification: nil, anchor: .zero)
        session.frame(image, translation: CGSize(width: -100, height: 0), magnification: nil, anchor: .zero)

        #expect(session.liveCrop == panned(image.crop, by: -100))
    }

    @Test func endingAGestureHandsOverItsCropAndStartsTheNextAfresh() {
        let session = session()
        session.frame(image, translation: CGSize(width: -100, height: 0), magnification: nil, anchor: .zero)

        #expect(session.endFraming() == panned(image.crop, by: -100))
        #expect(session.liveCrop == nil)
        session.frame(image, translation: CGSize(width: -50, height: 0), magnification: nil, anchor: .zero)
        #expect(session.liveCrop == panned(image.crop, by: -50))
    }

    /// A gesture cut short by a new selection never ends, and mustn't frame the next photo.
    @Test func aNewSelectionForgetsAnUnfinishedGesture() {
        let session = session()
        session.frame(image, translation: CGSize(width: -100, height: 0), magnification: nil, anchor: .zero)
        let next = PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 100, crop: ImageCrop(scale: 2))

        session.selection = CellAddress(projectID: UUID(), slideID: UUID(), index: 0)
        session.liveCrop = nil
        session.frame(next, translation: CGSize(width: -50, height: 0), magnification: nil, anchor: .zero)

        #expect(session.liveCrop == panned(next.crop, by: -50))
    }

    /// A new selection's cell reports where to zoom about afresh, so the last one's can't stand.
    @Test func aNewSelectionForgetsTheLastZoomAnchor() {
        let session = session()
        session.zoomAnchorX = 40

        session.selection = CellAddress(projectID: UUID(), slideID: UUID(), index: 0)

        #expect(session.zoomAnchorX == nil)
    }

    /// A photo replacing the selected one starts from its own crop, whatever the last one was
    /// left at mid-gesture or by the zoom slider.
    @Test func discardingFramingStartsTheNextPhotoFromItsOwnCrop() {
        let session = session()
        session.frame(image, translation: CGSize(width: -100, height: 0), magnification: nil, anchor: .zero)
        let replacement = PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 100, crop: ImageCrop(scale: 2))

        session.discardFraming()

        #expect(session.endFraming() == nil)
        session.frame(replacement, translation: CGSize(width: -50, height: 0), magnification: nil, anchor: .zero)
        #expect(session.liveCrop == panned(replacement.crop, by: -50))
    }

    /// As the fingers change, the gesture carries on from the crop it's at, even where the
    /// photo's edge stopped it, rather than the one it began from.
    @Test func rebasingCarriesOnFromTheCropItsAt() {
        let session = session()
        session.frame(image, translation: CGSize(width: 200, height: 0), magnification: nil, anchor: .zero)

        session.rebase()
        session.frame(image, translation: CGSize(width: -50, height: 0), magnification: nil, anchor: .zero)

        #expect(session.liveCrop == panned(panned(image.crop, by: 200), by: -50))
    }

    @Test func leavesTheCropAloneUntilTheCellHasMeasuredItself() {
        let session = CropSession()

        session.frame(image, translation: CGSize(width: -50, height: 0), magnification: nil, anchor: .zero)

        #expect(session.liveCrop == nil)
        #expect(session.endFraming() == nil)
    }

    /// The zoom slider leaves its crop unsaved, and a drag after it carries on from there.
    @Test func framesFromACropTheSliderLeft() {
        let session = session()
        let zoomed = CropGeometry.zoomed(image.crop, to: 2, imageSize: image.pixelSize, cellSize: session.cellSize)
        session.liveCrop = zoomed

        session.frame(image, translation: CGSize(width: -30, height: 0), magnification: nil, anchor: .zero)

        #expect(session.liveCrop == panned(zoomed, by: -30))
    }

    /// A crop the zoom slider left unsaved, which nothing else ends, is saved to the selected
    /// photo and let go.
    @Test func savesACropTheSliderLeft() async throws {
        let library = ProjectLibrary(store: CountingStore(), projects: [])
        let projectID = library.createProject(aspectRatio: .portrait).id
        let slideID = try #require(library.addSlide(.single, to: projectID))
        let address = CellAddress(projectID: projectID, slideID: slideID, index: 0)
        library.update(projectID) { $0.slides[0].cells[0].image = image }
        let session = CropSession(selection: address)
        let zoomed = ImageCrop(scale: 2)
        session.liveCrop = zoomed

        session.saveLiveCrop(to: library)

        #expect(library.photo(at: address)?.crop == zoomed)
        #expect(session.liveCrop == nil)
        await library.flush()
    }
}
