//
//  StripScrolling.swift
//  Carouline
//

import SwiftUI

/// The strip's items in order, with where each rests, which the strip scrolls between and finds
/// the one in its middle from.
nonisolated struct StripStops: Equatable {
    let items: [StripItem]
    let stops: [ClosedRange<CGFloat>]

    /// The item the strip rests on at `offset`: the one whose stop is nearest. Along a panorama,
    /// that's the panorama, however far off its own middle is, which a scroll view finding the
    /// item whose middle is nearest its own would miss for a slide beside it.
    func item(at offset: CGFloat) -> StripItem? {
        StripSnapping.nearest(to: offset, among: stops).map { items[$0] }
    }

    /// The offset that rests `item` in the middle: a slide's stop, or a panorama's middle.
    func offset(centering item: StripItem) -> CGFloat? {
        items.firstIndex(of: item).map { (stops[$0].lowerBound + stops[$0].upperBound) / 2 }
    }

    /// `offset` moved by `distance`, no further than `item` rests along its stop, or as it is
    /// off it, short of jumping onto it. Within a point counts, as a rest can land that near.
    func offset(movedBy distance: CGFloat, along item: StripItem, from offset: CGFloat) -> CGFloat {
        guard let stop = items.firstIndex(of: item).map({ stops[$0] }),
              (stop.lowerBound - 1)...(stop.upperBound + 1) ~= offset else {
            return offset
        }
        return min(max(offset + distance, stop.lowerBound), stop.upperBound)
    }

    /// The offset that keeps `item`, at `offset` in `old`'s layout, where it was along its stop,
    /// as slides come, go, move or change width around it. A new item, which the strip was moved to
    /// as it was added, rests in the middle, and once the item's gone, the nearest stop does.
    func offset(keeping item: StripItem?, at offset: CGFloat, from old: StripStops) -> CGFloat {
        guard let item, let index = items.firstIndex(of: item) else {
            return StripSnapping.rest(for: offset, among: stops)
        }
        let stop = stops[index]
        guard let oldIndex = old.items.firstIndex(of: item) else {
            return (stop.lowerBound + stop.upperBound) / 2
        }
        let moved = offset - old.stops[oldIndex].lowerBound + stop.lowerBound
        return min(max(moved, stop.lowerBound), stop.upperBound)
    }

    /// `offset` moved by `distance`, no further than `item` rests along its stop, or nil for an
    /// item the strip doesn't have.
    func offset(shifting offset: CGFloat, by distance: CGFloat, along item: StripItem) -> CGFloat? {
        items.firstIndex(of: item).map { min(max(offset + distance, stops[$0].lowerBound), stops[$0].upperBound) }
    }
}

/// Scrolls the strip by offset rather than by its items' IDs, which a scroll view finds the
/// middle one of by the nearest middle, so it reports the slide beside a panorama wider than the
/// screen rather than the panorama along it. Writes the item in the middle to `position` as the
/// strip moves, and moves it to an item something else writes there. Keeps the item in the middle
/// where it is as slides come, go or change width around it, and moves along it as far as its
/// layers shift as it reshapes, so what was in view stays. Animated, as everything that moves it
/// or its slides from elsewhere is, since a scroll position takes no animation from the change that
/// set it, except following a slide reshaping, which happens at once.
struct StripScrolling: ViewModifier {
    @Binding var position: StripItem?
    @Binding var scroll: ScrollPosition
    let stops: StripStops
    let snapping: StripSnapping
    let tracked: TrackedScroll
    /// The project's slides, whose reshaping the strip follows.
    let slides: [Slide]
    /// A slide's export size, which a slide's shift is measured on.
    let slideSize: CGSize
    /// One slide's width on screen.
    let slideWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .scrollTargetBehavior(snapping)
            .scrollPosition($scroll)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.visibleRect.minX
            } action: { _, offset in
                tracked.offset = offset
                // Within a point counts, as a rest can land that near.
                if let destination = tracked.destination, abs(offset - destination) <= 1 {
                    tracked.destination = nil
                }
                report(stops.item(at: offset))
            }
            .onScrollPhaseChange { _, phase in
                // Settled, or taken by a finger, wherever it was headed.
                if phase == .idle || phase == .interacting {
                    tracked.destination = nil
                }
            }
            // One handler, so a position written from elsewhere and the slides changing with it are
            // settled in one order.
            .onChange(of: StripState(position: position, stops: stops, slides: slides)) { old, new in
                move(from: old, to: new)
            }
    }

    /// Brings an item written to `position` from elsewhere to the middle, or else keeps the item in
    /// the middle where it is as the slides change, moved along it as far as its layers shift.
    private func move(from old: StripState, to new: StripState) {
        // Only an item written from elsewhere, not one the strip reported.
        if new.position != old.position, let item = new.position, item != tracked.front,
           let offset = new.stops.offset(centering: item) {
            tracked.front = item
            scroll(to: offset, animated: true)
            return
        }
        guard new.stops != old.stops || new.slides != old.slides else {
            return
        }
        // Where an animated scroll is headed, rather than wherever it's got to and whatever it's
        // passing, which `tracked.front` follows.
        let base = tracked.destination ?? tracked.offset
        let rest = new.rest(from: old, at: base, slideSize: slideSize, slideWidth: slideWidth)
        if rest.offset != base {
            // At once with a slide reshaping at once, unless the strip is already on its way.
            scroll(to: rest.offset, animated: !rest.reshaped || tracked.destination != nil)
        }
    }

    /// Animated in step with the slides moving around the one in front, or at once with the slide
    /// in front reshaping, so what's in view holds still.
    private func scroll(to offset: CGFloat, animated: Bool) {
        guard animated else {
            // Ahead of the scroll's report, so a change before it builds on it.
            tracked.offset = offset
            tracked.destination = nil
            scroll.scrollTo(x: offset)
            return
        }
        tracked.destination = offset
        withAnimation {
            scroll.scrollTo(x: offset)
        }
    }

    private func report(_ item: StripItem?) {
        guard item != tracked.front else {
            return
        }
        tracked.front = item
        if position != item {
            position = item
        }
    }
}

/// Where the strip is and what's in its middle, as it last moved, which a scroll writes every
/// frame, so it redraws nothing.
final class TrackedScroll {
    var offset: CGFloat = 0
    var front: StripItem?
    /// Where an animated scroll is headed, until the strip gets there, settles or a finger takes it,
    /// so a change while it moves builds on where it's going rather than where it's got to.
    var destination: CGFloat?
}

/// What moves the strip from elsewhere: an item written to its position, and the slides, whose
/// stops change with them.
nonisolated struct StripState: Equatable {
    let position: StripItem?
    let stops: StripStops
    let slides: [Slide]

    /// Where the strip rests once the slides change from `old`'s, from `base` among those: the item
    /// there kept where it was, and moved along it as far as its layers shift if it reshaped, on
    /// slides `slideWidth` points wide that export at `slideSize`. Whether it reshaped, which a
    /// slide does at once.
    func rest(from old: StripState, at base: CGFloat, slideSize: CGSize, slideWidth: CGFloat) -> (offset: CGFloat, reshaped: Bool) {
        let front = old.stops.item(at: base) ?? old.stops.items.first
        let kept = stops.offset(keeping: front, at: base, from: old.stops)
        guard case .slide(let slideID) = front,
              let before = old.slides.first(where: { $0.id == slideID }),
              let after = slides.first(where: { $0.id == slideID }),
              let shift = after.shift(from: before, slideSize: slideSize),
              let shifted = stops.offset(shifting: kept, by: shift.dx * slideWidth, along: .slide(slideID)) else {
            return (kept, false)
        }
        return (shifted, true)
    }
}
