//
//  StripSnapping.swift
//  Carouline
//

import SwiftUI

/// A card in the strip: `span` slides side by side in its middle, and `width` wide, as wide as
/// them, or as its caption where that's wider, as under a phone's slides in landscape.
nonisolated struct StripCard: Equatable {
    let span: Int
    let width: CGFloat

    /// How far in from the card's edges its slides `slideWidth` wide sit: half what its caption
    /// widens it by.
    func inset(slideWidth: CGFloat) -> CGFloat {
        max(0, width - slideWidth * CGFloat(max(1, span))) / 2
    }
}

/// Snaps a scroll of the strip to the nearest of `stops`, or rests it where it is within one, as
/// along a panorama.
nonisolated struct StripSnapping: ScrollTargetBehavior {
    let stops: [ClosedRange<CGFloat>]

    /// Where the strip rests for each card, then the add button, past the leading padding that
    /// rests the first slide's middle in the screen's: each slide's middle in the screen's, and
    /// anywhere from a panorama's first slide's middle to its last's, so the strip scrolls freely
    /// along one wider than the screen. Each card's slides sit in its middle, past `inset`.
    static func stops(cards: [StripCard], slideWidth: CGFloat, spacing: CGFloat, addButtonSize: CGFloat) -> [ClosedRange<CGFloat>] {
        // Measured from the first card's slides rather than its edge, as the leading padding is.
        let lead = cards.first?.inset(slideWidth: slideWidth) ?? 0
        var origin: CGFloat = 0
        var stops: [ClosedRange<CGFloat>] = []
        for card in cards {
            let start = origin + card.inset(slideWidth: slideWidth) - lead
            // Its slides past the first added to its start, since taking a slide off its end can
            // round below its start, and a range that ends before it starts traps.
            stops.append(start...(start + slideWidth * CGFloat(max(1, card.span) - 1)))
            origin += card.width + spacing
        }
        let addButton = origin - lead + (addButtonSize - slideWidth) / 2
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
