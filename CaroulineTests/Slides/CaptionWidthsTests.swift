//
//  CaptionWidthsTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

/// A caption's width from its label's, measured ahead, and one caption measured on the strip.
@MainActor
struct CaptionWidthsTests {
    private var widths: CaptionWidths {
        var widths = CaptionWidths()
        widths.labels = ["Slide 0": 46, "Slide 00": 55, "Slides 0–0": 74]
        return widths
    }

    /// As much wider than its label as the measured caption is than its own.
    @Test func widensALabelByWhatACaptionAddsToItsOwn() {
        var widths = widths
        widths.sample(176, naming: 3...3)

        #expect(widths.width(naming: 3...3) == 176)
        #expect(widths.width(naming: 17...17) == 185)
        #expect(widths.width(naming: 2...3) == 204)
    }

    /// A caption measured within a point of what the kept one gives leaves it, so a rounding
    /// doesn't move every card.
    @Test func keepsACaptionThatGivesTheOthersWithinAPoint() {
        var widths = widths
        widths.sample(176, naming: 3...3)
        widths.sample(185.4, naming: 17...17)

        #expect(widths.width(naming: 17...17) == 185)
    }

    /// A caption further off, as every one is at a new text size, takes its place.
    @Test func measuresByACaptionAtANewTextSize() {
        var widths = widths
        widths.sample(176, naming: 3...3)
        widths.sample(195, naming: 17...17)

        #expect(widths.width(naming: 3...3) == 186)
    }

    /// Nothing until a caption and its labels are measured.
    @Test func knowsNoWidthUntilMeasured() {
        var widths = widths
        #expect(widths.width(naming: 3...3) == nil)

        widths.sample(176, naming: 3...3)
        #expect(widths.width(naming: 1000...1000) == nil)
    }
}
