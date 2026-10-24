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
            stops: StripSnapping.stops(cards: .cards(spans: [1, 3, 1]), slideWidth: 300, spacing: 20, addButtonSize: 56)
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
            stops: StripSnapping.stops(cards: .cards(spans: [3, 1, 1]), slideWidth: 300, spacing: 20, addButtonSize: 56)
        )

        #expect(moved.offset(keeping: .slide(panorama), at: 400, from: stops) == 80)
    }

    /// Narrowed to two slides, a place past its new end moves onto its last slide.
    @Test func keepsAPlaceAlongANarrowedPanoramaWithinIt() {
        let narrowed = StripStops(
            items: [.slide(first), .slide(panorama), .slide(last), .add],
            stops: StripSnapping.stops(cards: .cards(spans: [1, 2, 1]), slideWidth: 300, spacing: 20, addButtonSize: 56)
        )

        #expect(narrowed.offset(keeping: .slide(panorama), at: 900, from: stops) == 620)
    }

    /// A slide added and moved to as one change rests in the middle, rather than where the strip
    /// was before it.
    @Test func centersANewSlideItWasMovedTo() {
        let added = UUID()
        let more = StripStops(
            items: [.slide(first), .slide(panorama), .slide(last), .slide(added), .add],
            stops: StripSnapping.stops(cards: .cards(spans: [1, 3, 1, 1]), slideWidth: 300, spacing: 20, addButtonSize: 56)
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
            stops: StripSnapping.stops(cards: .cards(spans: [3, 1]), slideWidth: 300, spacing: 20, addButtonSize: 56)
        )

        #expect(deleted.offset(keeping: .slide(first), at: 0, from: stops) == 0)
    }

    /// A slide reshaping in the middle shifts the strip along it as far as its layers, no further
    /// than it rests along it, as from a single slide's rest to where its middle lands on a panorama.
    @Test func shiftsAlongAReshapedSlideNoFurtherThanItRests() {
        #expect(stops.offset(shifting: 320, by: 300, along: .slide(panorama)) == 620)
        #expect(stops.offset(shifting: 320, by: -100, along: .slide(panorama)) == 320)
        #expect(stops.offset(shifting: 900, by: 300, along: .slide(panorama)) == 920)
        #expect(stops.offset(shifting: 320, by: 300, along: .slide(UUID())) == nil)
    }

    /// The slide in the middle turned into a panorama moves the strip along it as far as its
    /// photo's middle moves, while one turned beside it leaves the strip where it is.
    @Test func followsTheSlideInTheMiddleAsItReshapes() {
        let photo = Cell(image: PlacedImage(assetIdentifier: nil, pixelWidth: 6000, pixelHeight: 1500))
        let ends = [Slide(id: first, layout: .single), Slide(id: last, layout: .single)]
        func state(_ middle: Slide) -> StripState {
            StripState(
                position: nil,
                stops: StripStops(
                    items: [.slide(first), .slide(panorama), .slide(last), .add],
                    stops: StripSnapping.stops(cards: .cards(spans: [1, middle.span, 1]), slideWidth: 300, spacing: 20, addButtonSize: 56)
                ),
                slides: [ends[0], middle, ends[1]],
                slideWidth: 300
            )
        }
        let single = state(Slide(id: panorama, layout: .single, cells: [photo]))
        let wide = state(Slide(id: panorama, layout: .panorama, span: 5, cells: [photo]))
        let size = AspectRatio.portrait.exportSize

        let middle = wide.rest(from: single, at: 320, slideSize: size)
        let beside = wide.rest(from: single, at: 0, slideSize: size)

        #expect(abs(middle.offset - 920) < 1e-9)
        #expect(middle.atOnce)
        #expect(beside.offset == 0)
        #expect(!beside.atOnce)
    }

    /// A caption measured wider than the first slide widens its card, which moves the strip along
    /// the panorama in the middle at once, keeping what's in view where it was.
    @Test func keepsTheMiddleStillAtOnceAsACaptionWidensACard() {
        let slides = [Slide(id: first, layout: .single), Slide(id: panorama, layout: .panorama, span: 3), Slide(id: last, layout: .single)]
        let cards = [StripCard(span: 1, width: 360)] + .cards(spans: [3, 1])
        let widened = StripStops(
            items: stops.items,
            stops: StripSnapping.stops(cards: cards, slideWidth: 300, spacing: 20, addButtonSize: 56)
        )
        let old = StripState(position: nil, stops: stops, slides: slides, slideWidth: 300)
        let new = StripState(position: nil, stops: widened, slides: slides, slideWidth: 300)

        let rest = new.rest(from: old, at: 400, slideSize: AspectRatio.portrait.exportSize)

        #expect(rest.offset == 430)
        #expect(rest.atOnce)
    }

    /// The slides' width changing, as on turning the screen, moves the strip as the slides moving
    /// do, animated.
    @Test func animatesAlongANewSlideWidth() {
        let slides = [Slide(id: first, layout: .single), Slide(id: panorama, layout: .panorama, span: 3), Slide(id: last, layout: .single)]
        let narrower = StripStops(
            items: stops.items,
            stops: StripSnapping.stops(cards: .cards(spans: [1, 3, 1], slideWidth: 200), slideWidth: 200, spacing: 20, addButtonSize: 56)
        )
        let old = StripState(position: nil, stops: stops, slides: slides, slideWidth: 300)
        let new = StripState(position: nil, stops: narrower, slides: slides, slideWidth: 200)

        #expect(!new.rest(from: old, at: 400, slideSize: AspectRatio.portrait.exportSize).atOnce)
    }
}
