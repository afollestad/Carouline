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
    private let stops = StripSnapping.stops(spans: [1, 3, 1], slideWidth: 300, spacing: 20, addButtonSize: 56)

    /// A panorama's stretch runs from its first slide's middle to its last's, and the add button
    /// rests half its difference from a slide past where the last slide's would.
    @Test func stopsOnSlidesAlongAPanoramaAndOnTheAddButton() {
        #expect(stops == [0...0, 320...920, 1240...1240, 1438...1438])
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
