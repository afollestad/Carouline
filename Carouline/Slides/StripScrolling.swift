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
}

/// Scrolls the strip by offset rather than by its items' IDs, which a scroll view finds the
/// middle one of by the nearest middle, so it reports the slide beside a panorama wider than the
/// screen rather than the panorama along it. Writes the item in the middle to `position` as the
/// strip moves, and moves it to an item something else writes there. Animated, as everything that
/// moves it or its slides from elsewhere is, since a scroll position takes no animation from the
/// change that set it.
struct StripScrolling: ViewModifier {
    @Binding var position: StripItem?
    @Binding var scroll: ScrollPosition
    let stops: StripStops
    let snapping: StripSnapping
    @State private var tracked = TrackedScroll()

    func body(content: Content) -> some View {
        content
            .scrollTargetBehavior(snapping)
            .scrollPosition($scroll)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.visibleRect.minX
            } action: { _, offset in
                tracked.offset = offset
                report(stops.item(at: offset))
            }
            .onChange(of: position) { _, item in
                // Only an item written from elsewhere, not one the strip reported.
                guard let item, item != tracked.front, let offset = stops.offset(centering: item) else {
                    return
                }
                tracked.front = item
                withAnimation {
                    scroll.scrollTo(x: offset)
                }
            }
            .onChange(of: stops) { old, stops in
                let offset = stops.offset(keeping: tracked.front ?? old.items.first, at: tracked.offset, from: old)
                // In step with the slides moving around the one in front, so it stays put.
                if offset != tracked.offset {
                    withAnimation {
                        scroll.scrollTo(x: offset)
                    }
                }
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
private final class TrackedScroll {
    var offset: CGFloat = 0
    var front: StripItem?
}
