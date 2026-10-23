//
//  StripScrollingTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

/// Which item is in the middle of the strip, and where it scrolls to, for 300-point slides 20
/// apart around a panorama three slides wide.
struct StripScrollingTests {
    private let first = UUID()
    private let panorama = UUID()
    private let last = UUID()

    private var stops: StripStops {
        StripStops(
            items: [.slide(first), .slide(panorama), .slide(last), .add],
            stops: StripSnapping.stops(spans: [1, 3, 1], slideWidth: 300, spacing: 20, addButtonSize: 56)
        )
    }

    /// Anywhere along a panorama, it's the panorama, even at its first slide, where the slide
    /// before it is nearer the middle than the panorama's own middle is.
    @Test func findsThePanoramaAnywhereAlongIt() {
        #expect(stops.item(at: 320) == .slide(panorama))
        #expect(stops.item(at: 600) == .slide(panorama))
        #expect(stops.item(at: 920) == .slide(panorama))
    }

    @Test func findsTheNearestItemBetweenThem() {
        #expect(stops.item(at: 100) == .slide(first))
        #expect(stops.item(at: 1100) == .slide(last))
        #expect(stops.item(at: 1400) == .add)
    }

    @Test func centersASlideOrAPanoramasMiddle() {
        #expect(stops.offset(centering: .slide(first)) == 0)
        #expect(stops.offset(centering: .slide(panorama)) == 620)
        #expect(stops.offset(centering: .add) == 1438)
    }

    /// Moved left past the first slide, the panorama keeps the part of it that was in the middle.
    @Test func keepsThePlaceAlongAPanoramaThatMoves() {
        let moved = StripStops(
            items: [.slide(panorama), .slide(first), .slide(last), .add],
            stops: StripSnapping.stops(spans: [3, 1, 1], slideWidth: 300, spacing: 20, addButtonSize: 56)
        )

        #expect(moved.offset(keeping: .slide(panorama), at: 400, from: stops) == 80)
    }

    /// Narrowed to two slides, a place past its new end moves onto its last slide.
    @Test func keepsAPlaceAlongANarrowedPanoramaWithinIt() {
        let narrowed = StripStops(
            items: [.slide(first), .slide(panorama), .slide(last), .add],
            stops: StripSnapping.stops(spans: [1, 2, 1], slideWidth: 300, spacing: 20, addButtonSize: 56)
        )

        #expect(narrowed.offset(keeping: .slide(panorama), at: 900, from: stops) == 620)
    }

    /// A slide added and moved to as one change rests in the middle, rather than where the strip
    /// was before it.
    @Test func centersANewSlideItWasMovedTo() {
        let added = UUID()
        let more = StripStops(
            items: [.slide(first), .slide(panorama), .slide(last), .slide(added), .add],
            stops: StripSnapping.stops(spans: [1, 3, 1, 1], slideWidth: 300, spacing: 20, addButtonSize: 56)
        )

        #expect(more.offset(keeping: .slide(added), at: 1438, from: stops) == 1560)
    }

    /// A layer held at the strip's edge scrolls it along a panorama only as far as it rests along it.
    @Test func movesAlongAPanoramaNoFurtherThanItRests() {
        #expect(stops.offset(movedBy: 50, along: .slide(panorama), from: 600) == 650)
        #expect(stops.offset(movedBy: 500, along: .slide(panorama), from: 600) == 920)
        #expect(stops.offset(movedBy: -500, along: .slide(panorama), from: 600) == 320)
    }

    /// Off a panorama's stretch, as while the strip is on its way to it, it doesn't jump onto it.
    @Test func leavesTheStripOffAPanoramaWhereItIs() {
        #expect(stops.offset(movedBy: 50, along: .slide(panorama), from: 100) == 100)
    }

    /// Once the slide in the middle is gone, the strip rests on the nearest left.
    @Test func restsOnTheNearestOnceTheFrontIsGone() {
        let deleted = StripStops(
            items: [.slide(panorama), .slide(last), .add],
            stops: StripSnapping.stops(spans: [3, 1], slideWidth: 300, spacing: 20, addButtonSize: 56)
        )

        #expect(deleted.offset(keeping: .slide(first), at: 0, from: stops) == 0)
    }
}
