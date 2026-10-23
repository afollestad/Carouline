//
//  ProjectTourTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

/// The tour's rules, apart from TipKit, which only the app configures.
@MainActor
struct ProjectTourTests {
    private let canvas = LayerCanvas(size: CGSize(width: 300, height: 375), span: 1)

    /// Doing what a step shows finishes it even ahead of the tour, so an early tap skips only its
    /// own tip, but selecting a layer only while the tour is there, for the move hint after it.
    @Test func finishesAStepAheadOfTheTourButSelectingALayer() {
        for step in TourStep.allCases where step != .selectLayer {
            #expect(TourVisit.finishes(step, at: .addPhotos))
            #expect(TourVisit.finishes(step, at: step))
        }
        #expect(TourVisit.finishes(.selectLayer, at: .selectLayer))
        #expect(!TourVisit.finishes(.selectLayer, at: .addPhotos))
        #expect(!TourVisit.finishes(.selectLayer, at: .layers))
    }

    @Test func offersTheTourStepOnceTheScreenSettles() {
        var visit = TourVisit()
        #expect(!visit.offersSettledTip(.addPhotos, current: .addPhotos))

        visit.isSettled = true
        #expect(visit.offersSettledTip(.addPhotos, current: .addPhotos))
        #expect(!visit.offersSettledTip(.addPhotos, current: .placePhoto))
        #expect(!visit.offersSettledTip(.addPhotos, current: nil))
    }

    /// Each settled tip waits for something on the screen to point at.
    @Test func offersEachStepOnlyWithSomethingToPointAt() {
        var visit = TourVisit()
        visit.isSettled = true
        for step in [TourStep.placePhoto, .framePhoto, .changeLayout, .slideMenu, .layers, .selectLayer, .moveLayer, .share] {
            #expect(!visit.offersSettledTip(step, current: step))
        }

        visit.targets.hasTrayPhotos = true
        visit.targets.canPointAtPhoto = true
        visit.targets.frontSlideID = UUID()
        visit.targets.canPointAtLayer = true
        visit.targets.hasSlides = true
        for step in [TourStep.placePhoto, .framePhoto, .changeLayout, .slideMenu, .layers, .selectLayer, .share] {
            #expect(visit.offersSettledTip(step, current: step))
        }
        // It waits for a layer to be selected rather than the screen to settle.
        #expect(!visit.offersSettledTip(.moveLayer, current: .moveLayer))
    }

    @Test func showsTheMoveHintOnlyWithRoomAndNothingOpen() {
        #expect(TourVisit.offersMoveTip(current: .moveLayer, isPresenting: false, isCompactHeight: false))
        #expect(!TourVisit.offersMoveTip(current: .moveLayer, isPresenting: true, isCompactHeight: false))
        #expect(!TourVisit.offersMoveTip(current: .moveLayer, isPresenting: false, isCompactHeight: true))
        #expect(!TourVisit.offersMoveTip(current: .share, isPresenting: false, isCompactHeight: false))
    }

    /// Reaching a step with nothing to show it on skips it rather than holding back the rest: the
    /// move hint with nothing selected, as when the layer tip is closed, placing a photo with an
    /// empty tray, and framing one with none on a slide.
    @Test func skipsAStepWithNothingToShowItOn() {
        var targets = TourTargets()
        #expect(TourVisit.stepSkipped(at: .moveLayer, isLayerSelected: false, targets: targets) == .moveLayer)
        #expect(TourVisit.stepSkipped(at: .moveLayer, isLayerSelected: true, targets: targets) == nil)
        #expect(TourVisit.stepSkipped(at: .placePhoto, isLayerSelected: false, targets: targets) == .placePhoto)
        #expect(TourVisit.stepSkipped(at: .framePhoto, isLayerSelected: false, targets: targets) == .framePhoto)
        #expect(TourVisit.stepSkipped(at: .selectLayer, isLayerSelected: false, targets: targets) == nil)

        targets.hasTrayPhotos = true
        targets.hasPhotoToFrame = true
        #expect(TourVisit.stepSkipped(at: .placePhoto, isLayerSelected: false, targets: targets) == nil)
        #expect(TourVisit.stepSkipped(at: .framePhoto, isLayerSelected: false, targets: targets) == nil)
    }

    /// Photos gathered before any slide leave the tray to point at, and no slide.
    @Test func findsTheTrayWithoutSlides() throws {
        let coastline = try #require(SampleProjects.all.first { $0.name == "Coastline" })
        let targets = TourTargets(project: coastline, frontSlide: nil)
        #expect(targets.hasTrayPhotos)
        #expect(!targets.hasSlides)
        #expect(targets.frontSlideID == nil)
        #expect(!targets.canPointAtPhoto)
        #expect(!targets.hasPhotoToFrame)
    }

    /// A panorama runs past the screen's sides, where a tip over its photo or layers can fall off
    /// screen.
    @Test func pointsAtPhotosAndLayersOnlyOnSlidesOfTheirOwn() throws {
        let lisbon = try #require(SampleProjects.all.first { $0.name == "Lisbon" })
        let split = lisbon.slides[1]
        let panorama = try #require(lisbon.slides.first { $0.layout == .panorama })

        let onSplit = TourTargets(project: lisbon, frontSlide: split)
        #expect(onSplit.frontSlideID == split.id)
        #expect(onSplit.hasSlides)
        #expect(onSplit.canPointAtPhoto)
        #expect(!onSplit.canPointAtLayer)

        let onPanorama = TourTargets(project: lisbon, frontSlide: panorama)
        #expect(!onPanorama.canPointAtPhoto)
        #expect(!onPanorama.canPointAtLayer)
        #expect(onPanorama.hasPhotoToFrame)
    }

    @Test func pointsAtTheMiddleOfASlidesPhoto() throws {
        let slide = Slide(layout: .single, cells: [Cell(image: photo())])
        let target = try #require(TourTargets.photoTarget(on: slide, canvas: canvas))
        let frame = try #require(SlideGeometry.cellFrames(for: .single, in: canvas.size, style: slide.style).first)
        #expect(target.midX == frame.midX)
        #expect(target.midY == frame.midY)
        #expect(target.width == LayerGeometry.minimumTarget)
    }

    /// A tap where a layer lies selects the layer, so the tip points at a photo clear of one.
    @Test func pointsAtAPhotoNoLayerTakes() throws {
        let cover = Layer(
            content: .image(ImageLayer(image: photo())),
            placement: LayerPlacement(centerX: 0.25, centerY: 0.25, scale: 0.2)
        )
        let slide = Slide(layout: .grid, cells: [Cell(image: photo()), Cell(image: photo()), Cell(), Cell()], layers: [cover])
        let frames = SlideGeometry.cellFrames(for: .grid, in: canvas.size, style: slide.style)
        let target = try #require(TourTargets.photoTarget(on: slide, canvas: canvas))
        #expect(target.midX == frames[1].midX)
        #expect(target.midY == frames[1].midY)
    }

    @Test func pointsAtNoPhotoOnAnEmptySlide() {
        #expect(TourTargets.photoTarget(on: Slide(layout: .grid), canvas: canvas) == nil)
    }

    private func photo() -> PlacedImage {
        PlacedImage(assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 1536)
    }
}
