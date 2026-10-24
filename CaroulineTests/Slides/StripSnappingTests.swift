//
//  StripSnappingTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

/// Where the strip rests: on a slide, anywhere along a panorama, or on the add button, for 300-point
/// slides 20 apart around a panorama three slides wide.
struct StripSnappingTests {
    private let stops = StripSnapping.stops(cards: .cards(spans: [1, 3, 1]), slideWidth: 300, spacing: 20, addButtonSize: 56)

    /// A panorama's stretch runs from its first slide's middle to its last's, and the add button
    /// rests half its difference from a slide past where the last slide's would.
    @Test func stopsOnSlidesAlongAPanoramaAndOnTheAddButton() {
        #expect(stops == [0...0, 320...920, 1240...1240, 1438...1438])
    }

    /// A slide's stop is its start alone, even for a width that rounds `start + width - width` below
    /// its start, as 344.4 points, 82% of a 420-point strip, does on the third slide.
    @Test func stopsOnASlideForAnyWidth() {
        let stops = StripSnapping.stops(cards: .cards(spans: [1, 1, 1], slideWidth: 344.4), slideWidth: 344.4, spacing: 20, addButtonSize: 56)
        #expect(stops.dropLast().allSatisfy { $0.lowerBound == $0.upperBound })
    }

    /// Cards widened by their captions, as under a phone's slides in landscape, rest each slide's
    /// middle in the screen's, measured from the first slide's, inside its card.
    @Test func stopsOnSlidesWidenedByTheirCaptions() {
        let cards = [StripCard(span: 1, width: 360), StripCard(span: 1, width: 340), StripCard(span: 2, width: 600)]
        let stops = StripSnapping.stops(cards: cards, slideWidth: 300, spacing: 20, addButtonSize: 56)
        #expect(stops == [0...0, 370...370, 710...1010, 1208...1208])
    }

    /// Half what a caption widens its card by, whether over one slide or a panorama.
    @Test func insetsSlidesInACardItsCaptionWidens() {
        #expect(StripCard(span: 1, width: 360).inset(slideWidth: 300) == 30)
        #expect(StripCard(span: 2, width: 640).inset(slideWidth: 300) == 20)
        #expect(StripCard(span: 3, width: 900).inset(slideWidth: 300) == 0)
    }

    @Test func restsWhereItIsAlongAPanorama() {
        #expect(StripSnapping.rest(for: 600, among: stops) == 600)
    }

    @Test func snapsPastAPanoramasEndToTheNearestStop() {
        #expect(StripSnapping.rest(for: 1000, among: stops) == 920)
        #expect(StripSnapping.rest(for: 1200, among: stops) == 1240)
    }

    @Test func snapsBetweenSlidesToTheNearer() {
        #expect(StripSnapping.rest(for: 100, among: stops) == 0)
        #expect(StripSnapping.rest(for: 1400, among: stops) == 1438)
    }
}

extension [StripCard] {
    /// Cards as wide as their slides, `spans` of them `slideWidth` wide.
    static func cards(spans: [Int], slideWidth: CGFloat = 300) -> [StripCard] {
        spans.map { StripCard(span: $0, width: slideWidth * CGFloat($0)) }
    }
}
