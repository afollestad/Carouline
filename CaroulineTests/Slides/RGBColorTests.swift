//
//  RGBColorTests.swift
//  CaroulineTests
//

import Testing
import UIKit
@testable import Carouline

struct RGBColorTests {
    @Test func readsSRGBComponentsAsTheyAre() {
        let color = RGBColor(UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        #expect(abs(color.red - 0.2) < 0.001)
        #expect(abs(color.green - 0.4) < 0.001)
        #expect(abs(color.blue - 0.6) < 0.001)
    }

    @Test func readsAGrayAsEqualChannels() {
        let color = RGBColor(UIColor(white: 0.5, alpha: 1))
        #expect(abs(color.red - 0.5) < 0.001)
        #expect(color.red == color.green && color.green == color.blue)
    }

    /// Display P3's pure red lies outside sRGB, so it clamps to sRGB's.
    @Test func clampsAWideGamutColor() {
        let color = RGBColor(UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1))
        #expect(color.red == 1)
        #expect(color.green == 0)
        #expect(color.blue == 0)
    }

    @Test func tellsLightFromDark() {
        #expect(RGBColor.white.isLight)
        #expect(!RGBColor.black.isLight)
        #expect(!RGBColor(red: 0.47, green: 0.34, blue: 0.91).isLight)
    }
}
