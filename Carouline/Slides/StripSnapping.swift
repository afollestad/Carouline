//
//  StripSnapping.swift
//  Carouline
//

import SwiftUI

/// Snaps a scroll of the strip to the nearest of `stops`, or rests it where it is within one, as
/// along a panorama.
nonisolated struct StripSnapping: ScrollTargetBehavior {
    let stops: [ClosedRange<CGFloat>]

    /// Where the strip rests for each slide, then the add button, past the leading padding that
    /// rests the first slide's middle in the screen's: each slide's middle in the screen's, and
    /// anywhere from a panorama's first slide's middle to its last's, so the strip scrolls freely
    /// along one wider than the screen.
    static func stops(spans: [Int], slideWidth: CGFloat, spacing: CGFloat, addButtonSize: CGFloat) -> [ClosedRange<CGFloat>] {
        var origin: CGFloat = 0
        var stops: [ClosedRange<CGFloat>] = []
        for span in spans {
            let width = slideWidth * CGFloat(max(1, span))
            stops.append(origin...(origin + width - slideWidth))
            origin += width + spacing
        }
        let addButton = origin + (addButtonSize - slideWidth) / 2
        return stops + [addButton...addButton]
    }

    /// `proposed` within whichever of `stops` it's nearest.
    static func rest(for proposed: CGFloat, among stops: [ClosedRange<CGFloat>]) -> CGFloat {
        nearest(to: proposed, among: stops).map { clamped(proposed, to: stops[$0]) } ?? proposed
    }

    /// The index of whichever of `stops` is nearest `offset`, the first of any as near.
    static func nearest(to offset: CGFloat, among stops: [ClosedRange<CGFloat>]) -> Int? {
        stops.indices.min { abs(clamped(offset, to: stops[$0]) - offset) < abs(clamped(offset, to: stops[$1]) - offset) }
    }

    private static func clamped(_ offset: CGFloat, to stop: ClosedRange<CGFloat>) -> CGFloat {
        min(max(offset, stop.lowerBound), stop.upperBound)
    }

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        // A scroll to bring a view into view targets the view's own rect, anchored to it, which
        // already rests where it should. Snapping that rect as if it were the visible region
        // would stop the scroll short.
        guard target.anchor == nil else {
            return
        }
        target.rect.origin.x = Self.rest(for: target.rect.minX, among: stops)
    }
}
