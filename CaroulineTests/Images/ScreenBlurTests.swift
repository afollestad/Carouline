//
//  ScreenBlurTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

/// How much smaller than shown a blurred photo renders, on a 3x screen.
struct ScreenBlurTests {
    /// A slide's photo renders as small as its blur allows, and no smaller.
    @Test func keepsTheBlursOwnShrinkForASlide() {
        #expect(ScreenBlur.shrink(for: 2, region: CGSize(width: 330, height: 412), displayScale: 3) == 1)
        #expect(ScreenBlur.shrink(for: 8, region: CGSize(width: 330, height: 412), displayScale: 3) == 4)
    }

    /// A ten-slide panorama's photo, 9,900 pixels across, renders no wider than the cap.
    @Test func shrinksAWidePanoramaToTheCap() {
        let shrink = ScreenBlur.shrink(for: 2, region: CGSize(width: 3300, height: 412), displayScale: 3)

        #expect(3300 * 3 / shrink == ScreenBlur.maximumPixels)
    }
}
