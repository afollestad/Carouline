//
//  LayerSnappingTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

struct LayerSnappingTests {
    /// A slide 400 points square, so a hundredth of it is 4 points.
    private let canvas = LayerCanvas(size: CGSize(width: 400, height: 400), span: 1)

    private func snapped(
        _ placement: LayerPlacement,
        previous: LayerSnap = LayerSnap(),
        on canvas: LayerCanvas? = nil
    ) -> (LayerPlacement, LayerSnap) {
        let result = LayerSnapping.snapped(placement, on: canvas ?? self.canvas, previous: previous)
        return (result.placement, result.snap)
    }

    @Test func centersWithinReach() {
        // 6 points off the middle across, 7 down.
        let (placement, snap) = snapped(LayerPlacement(centerX: 0.515, centerY: 0.4825))

        #expect(placement.centerX == 0.5)
        #expect(placement.centerY == 0.5)
        #expect(snap.guideX == 0.5)
        #expect(snap.guideY == 0.5)
    }

    @Test func leavesALayerOutOfReachWhereItIs() {
        // 10 points off the middle.
        let (placement, snap) = snapped(LayerPlacement(centerX: 0.525, centerY: 0.475))

        #expect(placement.centerX == 0.525)
        #expect(placement.centerY == 0.475)
        #expect(snap.guideX == nil)
        #expect(snap.guideY == nil)
    }

    /// While the slides are scaled down on screen, a snap reaches as far on screen as ever, so
    /// across more of the canvas.
    @Test func reachesAsFarOnScreenWhileScaledDown() {
        let scaled = LayerCanvas(size: CGSize(width: 400, height: 400), span: 1, screenPoint: 2)
        // 12 canvas points off the middle: 6 on screen.
        let (near, nearSnap) = snapped(LayerPlacement(centerX: 0.53, centerY: 0.5), on: scaled)
        // 20 canvas points off: 10 on screen.
        let (far, farSnap) = snapped(LayerPlacement(centerX: 0.55, centerY: 0.5), on: scaled)

        #expect(near.centerX == 0.5)
        #expect(nearSnap.guideX == 0.5)
        #expect(far.centerX == 0.55)
        #expect(farSnap.guideX == nil)
    }

    /// A snap holds out to twice as far as it took hold, so a finger resting at its edge doesn't
    /// flicker it on and off.
    @Test func holdsASnapOutToTwiceItsReach() {
        let held = LayerSnap(guideX: 0.5, guideY: 0.5)
        // 12 points off: out of reach, but within the hold.
        let (holding, holdingSnap) = snapped(LayerPlacement(centerX: 0.53, centerY: 0.53), previous: held)
        // 20 points off: past it.
        let (released, releasedSnap) = snapped(LayerPlacement(centerX: 0.55, centerY: 0.55), previous: held)

        #expect(holding.centerX == 0.5)
        #expect(holdingSnap.guideX == 0.5)
        #expect(holdingSnap.guideY == 0.5)
        #expect(released.centerX == 0.55)
        #expect(releasedSnap.guideX == nil)
        #expect(releasedSnap.guideY == nil)
    }

    @Test func turnsUprightWithinFiveDegrees() {
        let degree = Double.pi / 180

        #expect(snapped(LayerPlacement(rotation: 4 * degree)).0.rotation == 0)
        #expect(snapped(LayerPlacement(rotation: 6 * degree)).0.rotation == 6 * degree)
        #expect(abs(snapped(LayerPlacement(rotation: .pi / 2 + 3 * degree)).0.rotation - .pi / 2) < 1e-9)
        #expect(snapped(LayerPlacement(rotation: -.pi + 2 * degree)).1.quarterTurn == -.pi)
        // Held at a quarter, a turn lets go only past ten degrees.
        let held = LayerSnap(quarterTurn: 0)
        #expect(snapped(LayerPlacement(rotation: 8 * degree), previous: held).0.rotation == 0)
        #expect(snapped(LayerPlacement(rotation: 11 * degree), previous: held).0.rotation == 11 * degree)
    }

    /// A drag leaves a layer's tilt alone, and a twist its center, so moving a layer tilted on
    /// purpose never straightens it.
    @Test func snapsOnlyWhatTheGestureMoves() {
        let tilted = LayerPlacement(centerX: 0.51, rotation: 0.05)

        let dragged = LayerSnapping.snapped(tilted, on: canvas, previous: LayerSnap(), moves: true, turns: false)
        let twisted = LayerSnapping.snapped(tilted, on: canvas, previous: LayerSnap(), moves: false, turns: true)

        #expect(dragged.placement.centerX == 0.5)
        #expect(dragged.placement.rotation == 0.05)
        #expect(twisted.placement.centerX == 0.51)
        #expect(twisted.placement.rotation == 0)
    }

    /// On a panorama a layer centers on each slide, and on the whole, which can fall on a cut.
    @Test func centersOnAPanoramasSlidesAndOnTheWhole() {
        let panorama = LayerCanvas(size: CGSize(width: 800, height: 400), span: 4)

        #expect(snapped(LayerPlacement(centerX: 2.52), on: panorama).0.centerX == 2.5)
        #expect(snapped(LayerPlacement(centerX: 2.02), on: panorama).0.centerX == 2)
        #expect(snapped(LayerPlacement(centerX: 1.25), on: panorama).0.centerX == 1.25)
    }

    @Test func tellsWhenASnapTakesHold() {
        let none = LayerSnap()
        let across = LayerSnap(guideX: 0.5)

        #expect(across.takesHold(after: none))
        #expect(!across.takesHold(after: across))
        #expect(!none.takesHold(after: across))
        #expect(LayerSnap(guideX: 0.5, quarterTurn: 0).takesHold(after: across))
    }
}
