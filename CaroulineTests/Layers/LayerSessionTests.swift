//
//  LayerSessionTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

@MainActor
struct LayerSessionTests {
    /// A slide 400 points square.
    private let canvas = LayerCanvas(size: CGSize(width: 400, height: 400), span: 1)
    private let layer = Layer(content: .text(TextLayer(text: "Hi")), placement: LayerPlacement(centerX: 0.25, centerY: 0.25))

    /// Where a layer with the default placement sits, in the middle of the slide.
    private let center = CGPoint(x: 200, y: 200)

    private func session(selecting layer: Layer? = nil) -> LayerSession {
        LayerSession(selection: LayerAddress(projectID: UUID(), slideID: UUID(), layerID: (layer ?? self.layer).id))
    }

    /// A drag across `x` and `y` points from `start`, by default the test layer's center, `pinched`
    /// of them since a second finger joined it.
    private func drag(_ x: CGFloat, _ y: CGFloat, from start: CGPoint = CGPoint(x: 100, y: 100), pinched: CGSize? = nil) -> LayerDrag {
        LayerDrag(start: start, translation: CGSize(width: x, height: y), pinchTranslation: pinched)
    }

    /// A gesture reports how far it has moved in all, so each update builds on the placement it
    /// began from rather than the last update's.
    @Test func movesFromThePlacementTheGestureBeganWith() {
        let session = session()

        session.move(layer, by: LayerGesture(drag: drag(20, 0)), on: canvas)
        session.move(layer, by: LayerGesture(drag: drag(40, -20)), on: canvas)

        #expect(session.livePlacement?.centerX == 0.35)
        #expect(session.livePlacement?.centerY == 0.2)
    }

    @Test func sizesAndTurnsTogether() {
        let session = session()

        session.move(layer, by: LayerGesture(magnification: 2, rotation: 0.5), on: canvas)

        #expect(session.livePlacement?.scale == 2)
        #expect(session.livePlacement?.rotation == 0.5)
    }

    @Test func keepsTheLayerInRange() {
        let session = session()

        session.move(layer, by: LayerGesture(drag: drag(-1000, 1000), magnification: 100), on: canvas)

        #expect(session.livePlacement == LayerPlacement(centerX: 0, centerY: 1, scale: LayerPlacement.scales.upperBound))
    }

    @Test func endingAGestureHandsOverItsPlacementAndStartsTheNextAfresh() {
        let session = session()
        session.move(layer, by: LayerGesture(drag: drag(40, 0)), on: canvas)

        #expect(session.endMoving()?.centerX == 0.35)
        #expect(session.livePlacement == nil)
        #expect(session.snap == LayerSnap())
        session.move(layer, by: LayerGesture(drag: drag(20, 0)), on: canvas)
        #expect(session.livePlacement?.centerX == 0.3)
    }

    /// A gesture still running when another layer is selected, as when an import selects its
    /// picture, leaves that layer alone, and its end saves nothing.
    @Test func aGestureStaysWithTheLayerItBeganOn() {
        let session = session()
        let other = Layer(content: .text(TextLayer(text: "Other")))
        session.move(layer, by: LayerGesture(drag: drag(40, 0)), on: canvas)

        session.selection = LayerAddress(projectID: UUID(), slideID: UUID(), layerID: other.id)
        session.livePlacement = nil
        session.move(other, by: LayerGesture(drag: drag(80, 0, from: center)), on: canvas)

        #expect(session.livePlacement == nil)
        #expect(session.endMoving() == nil)
    }

    @Test func snapsAndReportsTheGuide() {
        let session = session()

        // From a quarter across, 99 points right puts the center a point short of the middle.
        session.move(layer, by: LayerGesture(drag: drag(99, 0)), on: canvas)

        #expect(session.livePlacement?.centerX == 0.5)
        #expect(session.snap.guideX == 0.5)
    }

    /// A haptic marks each snap taking hold mid-gesture, but not one the layer sat in already.
    @Test func countsOnlySnapsTakingHoldMidGesture() {
        let centered = Layer(content: .text(TextLayer(text: "Hi")))
        let session = session(selecting: centered)

        session.move(centered, by: LayerGesture(drag: drag(2, 0, from: center)), on: canvas)
        #expect(session.snap.guideX == 0.5)
        #expect(session.snapsTaken == 0)
        session.move(centered, by: LayerGesture(drag: drag(40, 0, from: center)), on: canvas)
        #expect(session.snap.guideX == nil)
        session.move(centered, by: LayerGesture(drag: drag(3, 0, from: center)), on: canvas)
        #expect(session.snap.guideX == 0.5)
        #expect(session.snapsTaken == 1)
    }

    /// A twist that joins a drag partway holds the layer upright where it began, as one there from
    /// the start does, so it counts no snap taking hold.
    @Test func aTwistJoiningADragCountsNoSnapOnAnUprightLayer() {
        let session = session()

        session.move(layer, by: LayerGesture(drag: drag(40, 0)), on: canvas)
        session.move(layer, by: LayerGesture(drag: drag(40, 0), rotation: 0.02), on: canvas)

        #expect(session.livePlacement?.rotation == 0)
        #expect(session.snap.quarterTurn == 0)
        #expect(session.snapsTaken == 0)
    }

    /// A pinch or twist that isn't finite leaves the layer where the last update left it.
    @Test func aPinchOrTwistThatIsNotFiniteMovesNothing() {
        let session = session()

        session.move(layer, by: LayerGesture(magnification: .nan), on: canvas)
        #expect(session.livePlacement == nil)
        session.move(layer, by: LayerGesture(magnification: 0.5, rotation: 0.5), on: canvas)
        session.move(layer, by: LayerGesture(magnification: .nan, rotation: 0.6), on: canvas)
        session.move(layer, by: LayerGesture(magnification: 0.4, rotation: .infinity), on: canvas)

        #expect(session.livePlacement?.scale == 0.5)
        #expect(session.livePlacement?.rotation == 0.5)
    }

    @Test func aPinchStopsWhereTheLayerGoesNoSmaller() {
        let session = session()

        session.move(layer, by: LayerGesture(magnification: 0.01), on: canvas)

        #expect(session.livePlacement?.scale == LayerGeometry.scales(of: layer).lowerBound)
    }

    @Test func movesNothingUntilTheSlideHasMeasuredItself() {
        let session = session()

        session.move(layer, by: LayerGesture(drag: drag(40, 0)), on: LayerCanvas(size: .zero, span: 1))

        #expect(session.livePlacement == nil)
    }

    @Test func movesOnlyTheSelectedLayer() {
        let session = session()

        session.move(Layer(content: .text(TextLayer(text: "Other"))), by: LayerGesture(drag: drag(40, 0, from: center)), on: canvas)

        #expect(session.livePlacement == nil)
    }

    /// Once a second finger joins a drag that began off the layer, the fingers move it, as far as
    /// they've moved since.
    @Test func aDragOffTheLayerMovesItOnceASecondFingerJoins() {
        let session = session()

        session.move(layer, by: LayerGesture(drag: drag(99, 0, from: CGPoint(x: 300, y: 300), pinched: CGSize(width: 40, height: 0))), on: canvas)

        #expect(session.livePlacement?.centerX == 0.35)
    }

    /// A drag that began on the layer keeps moving it the whole way through a pinch.
    @Test func aDragOnTheLayerCarriesOnThroughAPinch() {
        let session = session()

        session.move(layer, by: LayerGesture(drag: drag(40, 0, pinched: CGSize(width: 10, height: 0)), magnification: 1), on: canvas)

        #expect(session.livePlacement?.centerX == 0.35)
    }

    /// A drag that begins off the layer moves it nowhere, and leaves nothing to redraw.
    @Test func aDragStartingOffTheLayerMovesNothing() {
        let session = session()

        session.move(layer, by: LayerGesture(drag: drag(40, 0, from: CGPoint(x: 300, y: 300))), on: canvas)

        #expect(session.livePlacement == nil)
        #expect(session.snap == LayerSnap())
    }

    /// The drag is judged where it began, so it keeps moving the layer once the layer has left
    /// the finger's start.
    @Test func aDragStartingOnTheLayerKeepsMovingIt() {
        let session = session()

        session.move(layer, by: LayerGesture(drag: drag(100, 0)), on: canvas)
        session.move(layer, by: LayerGesture(drag: drag(200, 0)), on: canvas)

        #expect(session.livePlacement?.centerX == 0.75)
    }

    /// A small layer takes a drag across a fingertip's target, which grows with the canvas's
    /// points on screen while the slides are scaled down.
    @Test func aSmallLayerTakesADragAcrossAFingertip() {
        let small = Layer(content: .text(TextLayer(text: "Hi")), placement: LayerPlacement(centerX: 0.25, centerY: 0.25, scale: 0.25))
        let session = session(selecting: small)
        let scaled = LayerCanvas(size: canvas.size, span: 1, screenPoint: 2)

        session.move(small, by: LayerGesture(drag: drag(40, 0, from: CGPoint(x: 120, y: 100))), on: canvas)
        #expect(session.livePlacement?.centerX == 0.35)
        _ = session.endMoving()
        session.move(small, by: LayerGesture(drag: drag(40, 0, from: CGPoint(x: 140, y: 100))), on: scaled)
        #expect(session.livePlacement?.centerX == 0.35)
    }

    /// Each gesture judges its own drag, after the last ends or another layer is selected.
    @Test func eachGestureJudgesItsDragAfresh() {
        let session = session()
        let selection = session.selection

        session.move(layer, by: LayerGesture(drag: drag(40, 0, from: CGPoint(x: 300, y: 300))), on: canvas)
        _ = session.endMoving()
        session.move(layer, by: LayerGesture(drag: drag(40, 0)), on: canvas)
        #expect(session.livePlacement?.centerX == 0.35)

        _ = session.endMoving()
        session.move(layer, by: LayerGesture(drag: drag(40, 0, from: CGPoint(x: 300, y: 300))), on: canvas)
        session.selection = nil
        session.selection = selection
        session.move(layer, by: LayerGesture(drag: drag(40, 0)), on: canvas)
        #expect(session.livePlacement?.centerX == 0.35)
    }

    /// A pinch after a drag that began off the layer moves it only as far as the fingers have
    /// moved since, so one whose fingers' middle holds still sizes it in place.
    @Test func aPinchWithADragOffTheLayerSizesItInPlace() {
        let session = session()

        session.move(layer, by: LayerGesture(drag: drag(99, 0, from: CGPoint(x: 300, y: 300), pinched: .zero), magnification: 2), on: canvas)

        #expect(session.livePlacement?.scale == 2)
        #expect(session.livePlacement?.centerX == 0.25)
        #expect(session.snap.guideX == nil)
    }

    /// A twist after a drag off the layer holds the quarter turn the layer began at, so one that
    /// was upright already counts no snap taking hold.
    @Test func aTwistAfterADragOffTheLayerCountsNoSnap() {
        let centered = Layer(content: .text(TextLayer(text: "Hi")))
        let session = session(selecting: centered)
        let offLayer = drag(40, 0, from: CGPoint(x: 350, y: 350), pinched: .zero)

        session.move(centered, by: LayerGesture(drag: offLayer), on: canvas)
        session.move(centered, by: LayerGesture(drag: offLayer, rotation: 0.01), on: canvas)

        #expect(session.livePlacement?.rotation == 0)
        #expect(session.snapsTaken == 0)
    }

    /// A placement the size slider left unsaved, which nothing else ends, is saved to the
    /// selected layer and let go.
    @Test func savesAPlacementTheSliderLeft() async throws {
        let library = ProjectLibrary(store: CountingStore(), projects: [])
        let projectID = library.createProject(aspectRatio: .portrait).id
        let slideID = try #require(library.addSlide(.single, to: projectID))
        library.saveLayer(layer, in: slideID, of: projectID)
        let address = LayerAddress(projectID: projectID, slideID: slideID, layerID: layer.id)
        let session = LayerSession(selection: address)
        var sized = layer.placement
        sized.scale = 2
        session.livePlacement = sized

        session.saveLivePlacement(to: library)

        #expect(library.layer(at: address)?.placement == sized)
        #expect(session.livePlacement == nil)
        await library.flush()
    }
}
