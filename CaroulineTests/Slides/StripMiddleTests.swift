//
//  StripMiddleTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

/// How far what sits on a panorama moves to stay under the strip's middle, on a card three
/// 300-point slides wide.
struct StripMiddleTests {
    private let reach = StripMiddle.reach(span: 3, cardWidth: 900)

    /// To the middles of the first and last slides, a slide either way from the card's.
    @Test func reachesTheEndSlidesMiddles() {
        #expect(reach == 300)
        #expect(StripMiddle.reach(span: 1, cardWidth: 300) == 0)
    }

    @Test func followsTheStripsMiddleAlongAPanorama() {
        #expect(StripMiddle.shift(toward: 450, across: 900, reach: reach) == 0)
        #expect(StripMiddle.shift(toward: 300, across: 900, reach: reach) == -150)
    }

    /// Past the end slides' middles, as on a panorama peeking in, it stays under the end slide.
    @Test func stopsAtTheEndSlides() {
        #expect(StripMiddle.shift(toward: -500, across: 900, reach: reach) == -300)
        #expect(StripMiddle.shift(toward: 2000, across: 900, reach: reach) == 300)
    }

    /// A caption wider than a slide moves only as far as keeps it on the card.
    @Test func keepsAViewInsideItsContainer() {
        #expect(StripMiddle.room(for: 600, in: 900) == 150)
        #expect(StripMiddle.room(for: 1000, in: 900) == 0)
    }

    @Test func findsThePanoramaSlideAtAPoint() {
        #expect(StripMiddle.slideIndex(at: 0, across: 900, span: 3) == 0)
        #expect(StripMiddle.slideIndex(at: 450, across: 900, span: 3) == 1)
        #expect(StripMiddle.slideIndex(at: 899, across: 900, span: 3) == 2)
    }

    @Test func findsNoSlideOffTheCard() {
        #expect(StripMiddle.slideIndex(at: -1, across: 900, span: 3) == nil)
        #expect(StripMiddle.slideIndex(at: 900, across: 900, span: 3) == nil)
        #expect(StripMiddle.slideIndex(at: 0, across: 0, span: 3) == nil)
    }

    @Test func leavesASlidesViewsWhereTheyAre() {
        #expect(StripMiddle.shift(toward: 0, across: 300, reach: 0) == 0)
    }
}
