//
//  AspectRatioTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

struct AspectRatioTests {
    @Test(arguments: AspectRatio.presets)
    func exportsAtItsRatio(_ ratio: AspectRatio) {
        #expect(ratio.exportSize.width == 1080)
        #expect(abs(ratio.exportSize.height - 1080 * ratio.height / ratio.width) < 1)
        #expect(ratio.isValid)
    }

    /// The sizes every build before shapes of the user's own exported each preset at.
    @Test func keepsEachPresetsSize() {
        let heights = AspectRatio.presets.map(\.pixelHeight)
        #expect(heights == [1920, 1620, 1440, 1350, 1080, 608, 566])
        #expect(AspectRatio.presets.map(\.label) == ["9:16", "2:3", "3:4", "4:5", "1:1", "16:9", "1.91:1"])
    }

    @Test func roundsASideUpWithoutAnExactProductGainingAPixel() {
        #expect(AspectRatio.side(1080, times: 16.0 / 9) == 1920)
        #expect(AspectRatio.side(1080, times: 4.0 / 3) == 1440)
        #expect(AspectRatio.side(1080, times: 9.0 / 16) == 608)
        #expect(AspectRatio.side(1080, times: 1 / 1.91) == 566)
        #expect(AspectRatio.side(2000, times: 7.0 / 5) == 2800)
        #expect(AspectRatio.side(1080, times: 0) == 0)
        #expect(AspectRatio.side(1080, times: .nan) == 0)
        #expect(AspectRatio.side(1080, times: .infinity) == 1_000_000_000)
    }

    @Test func makesAShapeWithinItsLimits() throws {
        let tall = try #require(AspectRatio(width: 1, height: 2, pixelWidth: 1080, pixelHeight: 2160))
        #expect(tall.widthOverHeight == 0.5)
        let wide = try #require(AspectRatio(width: 2, height: 1, pixelWidth: 4096, pixelHeight: 2048))
        #expect(wide.exportSize == CGSize(width: 4096, height: 2048))
        #expect(AspectRatio(width: 1, height: 1, pixelWidth: 320, pixelHeight: 320) != nil)
    }

    @Test func refusesAShapePastItsLimits() {
        #expect(AspectRatio(width: 0.49, height: 1, pixelWidth: 1000, pixelHeight: 2041) == nil)
        #expect(AspectRatio(width: 2.01, height: 1, pixelWidth: 2010, pixelHeight: 1000) == nil)
        #expect(AspectRatio(width: 1, height: 1, pixelWidth: 319, pixelHeight: 319) == nil)
        #expect(AspectRatio(width: 1, height: 1, pixelWidth: 4097, pixelHeight: 4097) == nil)
        #expect(AspectRatio(width: 0, height: 1, pixelWidth: 1080, pixelHeight: 1080) == nil)
        #expect(AspectRatio(width: .infinity, height: .infinity, pixelWidth: 1080, pixelHeight: 1080) == nil)
        // A size that doesn't keep its terms' ratio.
        #expect(AspectRatio(width: 1, height: 1, pixelWidth: 320, pixelHeight: 4096) == nil)
        #expect(AspectRatio(width: 4, height: 5, pixelWidth: 1080, pixelHeight: 1352) == nil)
    }

    @Test func keepsTermsToTwoDecimals() throws {
        let ratio = try #require(AspectRatio(width: 1.914, height: 1, pixelWidth: 1080, pixelHeight: 566))
        #expect(ratio.width == 1.91)
        #expect(ratio == .landscape)
    }

    @Test func namesAndSpeaksItsRatio() throws {
        let custom = try #require(AspectRatio(width: 5, height: 7, pixelWidth: 2000, pixelHeight: 2800))
        #expect(custom.label == "5:7")
        #expect(custom.spokenRatio == "5 by 7")
        #expect(AspectRatio.landscape.label == "1.91:1")
        #expect(AspectRatio.landscape.spokenRatio == "1.91 by 1")
    }

    /// A preset's ratio keeps its name and uses at any size; any other is named by its orientation.
    @Test func namesAShapeByItsPresetOrOrientation() throws {
        let story = try #require(AspectRatio(width: 9, height: 16, pixelWidth: 1440, pixelHeight: 2560))
        #expect(story.name == "Story")
        #expect(story.uses == "TikTok, Stories")
        let portrait = try #require(AspectRatio(width: 5, height: 7, pixelWidth: 1080, pixelHeight: 1512))
        #expect(portrait.name == "Portrait")
        #expect(portrait.uses == nil)
        let landscape = try #require(AspectRatio(width: 3, height: 2, pixelWidth: 1080, pixelHeight: 720))
        #expect(landscape.name == "Landscape")
        let square = try #require(AspectRatio(width: 2, height: 2, pixelWidth: 1080, pixelHeight: 1080))
        #expect(square.name == "Square")
    }
}
