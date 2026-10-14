//
//  LayerSnapping.swift
//  Swipeset
//

import CoreGraphics
import Foundation

/// What a layer being moved has snapped to.
nonisolated struct LayerSnap: Hashable, Sendable {
    /// The vertical guide the layer's center sits on, in slide widths from the canvas's left edge.
    var guideX: Double?
    /// The horizontal guide the layer's center sits on, as a fraction of the canvas's height.
    var guideY: Double?
    /// The quarter turn the layer is held upright at, in radians.
    var quarterTurn: Double?

    /// Whether `self` holds a snap that `previous` didn't, as when a guide or quarter turn takes
    /// hold, rather than when one lets go.
    func takesHold(after previous: LayerSnap) -> Bool {
        (guideX != nil && guideX != previous.guideX)
            || (guideY != nil && guideY != previous.guideY)
            || (quarterTurn != nil && quarterTurn != previous.quarterTurn)
    }
}

/// The slide a layer moves on: its size in points and how many slides it spans.
nonisolated struct LayerCanvas: Hashable, Sendable {
    let size: CGSize
    let span: Int
    /// How many of the canvas's points a point on screen covers: more than one while a phone
    /// scales the slides down above its layers sheet, so fingertip distances stay the same.
    var screenPoint: CGFloat = 1

    var slideWidth: CGFloat {
        LayerGeometry.slideWidth(canvas: size, span: span)
    }
}

/// Holds a moving layer's center on the middle of a slide, across and down, and its turn on
/// each quarter, so it's easy to line up and straighten.
nonisolated enum LayerSnapping {
    /// How close the center comes to a guide, in points on screen, before it snaps: a fingertip's
    /// slack, without catching a layer moved past on purpose.
    static let distance: CGFloat = 8
    /// How close a turn comes to a quarter before it snaps.
    static let angle = 5 * Double.pi / 180
    /// A snap lets go only twice as far out as it took hold, so a finger resting at the edge
    /// doesn't flicker it on and off.
    static let release = 2.0

    /// `placement`, as a gesture left it before any snapping, snapped on a canvas of `canvas`,
    /// with what it snapped to. `previous` is the gesture's last snap, which holds out to
    /// `release` times as far. Only what the gesture moves snaps, as its center when `moves`
    /// and its turn when `turns`, so dragging a layer tilted on purpose never straightens it.
    static func snapped(
        _ placement: LayerPlacement,
        on canvas: LayerCanvas,
        previous: LayerSnap,
        moves: Bool = true,
        turns: Bool = true
    ) -> (placement: LayerPlacement, snap: LayerSnap) {
        var snapped = placement
        var snap = LayerSnap()
        if moves {
            // Each slide's middle, and on a panorama its own middle, which can fall on a cut.
            let guidesX = Set((0..<max(1, canvas.span)).map { Double($0) + 0.5 } + [Double(canvas.span) / 2])
            if let guide = nearest(placement.centerX, in: guidesX, scale: Double(canvas.slideWidth / canvas.screenPoint), previous: previous.guideX) {
                snapped.centerX = guide
                snap.guideX = guide
            }
            if let guide = nearest(placement.centerY, in: [0.5], scale: Double(canvas.size.height / canvas.screenPoint), previous: previous.guideY) {
                snapped.centerY = guide
                snap.guideY = guide
            }
        }
        if turns {
            let quarter = (placement.rotation / (.pi / 2)).rounded() * (.pi / 2)
            let reach = quarter == previous.quarterTurn ? angle * release : angle
            if abs(placement.rotation - quarter) <= reach {
                snapped.rotation = remainder(quarter, 2 * .pi)
                snap.quarterTurn = quarter
            }
        }
        return (snapped, snap)
    }

    /// The guide in `guides` within reach of `value`, measured in points on screen by `scale`: the
    /// one held before out to `release` times as far, or else the closest within `distance`.
    private static func nearest(_ value: Double, in guides: Set<Double>, scale: Double, previous: Double?) -> Double? {
        guard scale > 0, scale.isFinite else {
            return nil
        }
        if let previous, guides.contains(previous), abs(value - previous) * scale <= Double(distance) * release {
            return previous
        }
        return guides
            .filter { abs(value - $0) * scale <= Double(distance) }
            .min { abs(value - $0) < abs(value - $1) }
    }
}
