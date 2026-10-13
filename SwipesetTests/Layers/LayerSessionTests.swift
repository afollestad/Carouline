//
//  LayerSessionTests.swift
//  SwipesetTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Swipeset

@MainActor
struct LayerSessionTests {
    /// A slide 400 points square.
    private let canvas = LayerCanvas(size: CGSize(width: 400, height: 400), span: 1)
    private let layer = Layer(content: .text(TextLayer(text: "Hi")), placement: LayerPlacement(centerX: 0.25, centerY: 0.25))

    private func session(selecting layer: Layer? = nil) -> LayerSession {
        LayerSession(selection: LayerAddress(projectID: UUID(), slideID: UUID(), layerID: (layer ?? self.layer).id))
    }

    /// A gesture reports how far it has moved in all, so each update builds on the placement it
    /// began from rather than the last update's.
    @Test func movesFromThePlacementTheGestureBeganWith() {
        let session = session()

        session.move(layer, by: LayerGesture(translation: CGSize(width: 20, height: 0)), on: canvas)
        session.move(layer, by: LayerGesture(translation: CGSize(width: 40, height: -20)), on: canvas)

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

        session.move(layer, by: LayerGesture(translation: CGSize(width: -1000, height: 1000), magnification: 100), on: canvas)

        #expect(session.livePlacement == LayerPlacement(centerX: 0, centerY: 1, scale: LayerPlacement.scales.upperBound))
    }

    @Test func endingAGestureHandsOverItsPlacementAndStartsTheNextAfresh() {
        let session = session()
        session.move(layer, by: LayerGesture(translation: CGSize(width: 40, height: 0)), on: canvas)

        #expect(session.endMoving()?.centerX == 0.35)
        #expect(session.livePlacement == nil)
        #expect(session.snap == LayerSnap())
        session.move(layer, by: LayerGesture(translation: CGSize(width: 20, height: 0)), on: canvas)
        #expect(session.livePlacement?.centerX == 0.3)
    }

    /// A gesture still running when another layer is selected, as when an import selects its
    /// picture, leaves that layer alone, and its end saves nothing.
    @Test func aGestureStaysWithTheLayerItBeganOn() {
        let session = session()
        let other = Layer(content: .text(TextLayer(text: "Other")))
        session.move(layer, by: LayerGesture(translation: CGSize(width: 40, height: 0)), on: canvas)

        session.selection = LayerAddress(projectID: UUID(), slideID: UUID(), layerID: other.id)
        session.livePlacement = nil
        session.move(other, by: LayerGesture(translation: CGSize(width: 80, height: 0)), on: canvas)

        #expect(session.livePlacement == nil)
        #expect(session.endMoving() == nil)
    }

    @Test func snapsAndReportsTheGuide() {
        let session = session()

        // From a quarter across, 99 points right puts the center a point short of the middle.
        session.move(layer, by: LayerGesture(translation: CGSize(width: 99, height: 0)), on: canvas)

        #expect(session.livePlacement?.centerX == 0.5)
        #expect(session.snap.guideX == 0.5)
    }

    /// A haptic marks each snap taking hold mid-gesture, but not one the layer sat in already.
    @Test func countsOnlySnapsTakingHoldMidGesture() {
        let centered = Layer(content: .text(TextLayer(text: "Hi")))
        let session = session(selecting: centered)

        session.move(centered, by: LayerGesture(translation: CGSize(width: 2, height: 0)), on: canvas)
        #expect(session.snap.guideX == 0.5)
        #expect(session.snapsTaken == 0)
        session.move(centered, by: LayerGesture(translation: CGSize(width: 40, height: 0)), on: canvas)
        #expect(session.snap.guideX == nil)
        session.move(centered, by: LayerGesture(translation: CGSize(width: 3, height: 0)), on: canvas)
        #expect(session.snap.guideX == 0.5)
        #expect(session.snapsTaken == 1)
    }

    @Test func movesNothingUntilTheSlideHasMeasuredItself() {
        let session = session()

        session.move(layer, by: LayerGesture(translation: CGSize(width: 40, height: 0)), on: LayerCanvas(size: .zero, span: 1))

        #expect(session.livePlacement == nil)
    }

    @Test func movesOnlyTheSelectedLayer() {
        let session = session()

        session.move(Layer(content: .text(TextLayer(text: "Other"))), by: LayerGesture(translation: CGSize(width: 40, height: 0)), on: canvas)

        #expect(session.livePlacement == nil)
    }
}
