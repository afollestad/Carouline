//
//  CustomRatioDraftTests.swift
//  CaroulineTests
//

import Foundation
import Testing
@testable import Carouline

struct CustomRatioDraftTests {
    private let english = Locale(identifier: "en_US")

    @Test func startsOnAShapeItCanMake() {
        let draft = CustomRatioDraft(locale: english)
        #expect([draft.ratioWidth, draft.ratioHeight, draft.pixelWidth, draft.pixelHeight] == ["4", "5", "1080", "1350"])
        #expect(draft.aspectRatio == .portrait)
        #expect(draft.problems.isEmpty)
    }

    /// The side typed last keeps its pixels, and the other follows the ratio.
    @Test func keepsTheSizeToTheRatio() {
        var draft = CustomRatioDraft(locale: english)
        draft.setRatioWidth("5")
        draft.setRatioHeight("7")
        #expect(draft.pixelHeight == "1512")
        draft.setPixelWidth("2000")
        #expect(draft.pixelHeight == "2800")
        draft.setPixelHeight("1400")
        #expect(draft.pixelWidth == "1000")
        // The height was typed last, so a new ratio keeps it.
        draft.setRatioWidth("1")
        draft.setRatioHeight("2")
        #expect(draft.pixelWidth == "700")
        #expect(draft.pixelHeight == "1400")
        #expect(draft.aspectRatio == AspectRatio(width: 1, height: 2, pixelWidth: 700, pixelHeight: 1400))
    }

    /// The same round-up as the presets, so a preset's ratio at its width is that preset.
    @Test func sizesAPresetsRatioAsThePresetIs() {
        var draft = CustomRatioDraft(locale: english)
        draft.setRatioWidth("1.91")
        draft.setRatioHeight("1")
        #expect(draft.pixelHeight == "566")
        #expect(draft.aspectRatio == .landscape)
    }

    @Test func tellsWhatsPastTheLimits() {
        var draft = CustomRatioDraft(locale: english)
        draft.setRatioWidth("3")
        draft.setRatioHeight("1")
        #expect(draft.problems == [.ratio])
        #expect(draft.aspectRatio == nil)
        // The size still shows what the ratio would make.
        #expect(draft.pixelHeight == "360")
        draft.setRatioWidth("2")
        #expect(draft.problems.isEmpty)
        draft.setPixelWidth("5000")
        #expect(draft.problems == [.size])
        #expect(draft.pixelHeight == "2500")
        #expect(draft.aspectRatio == nil)
        // A ratio past its limits can push the side that follows it past its own too.
        draft.setPixelHeight("1400")
        draft.setRatioWidth("3")
        #expect(draft.pixelWidth == "4200")
        #expect(draft.problems == [.ratio, .size])
    }

    /// Only digits and one decimal separator read as a number, rather than as much of the text
    /// as makes one, and an empty field is still being typed rather than wrong.
    @Test func readsOnlyWhatTheKeypadsType() {
        var draft = CustomRatioDraft(locale: english)
        for text in ["12a", "-5", "2000.5", "1,080"] {
            draft.setPixelWidth(text)
            #expect(draft.pixelHeight == "1350", "\(text)")
            #expect(draft.problems == [.size], "\(text)")
        }
        draft.setPixelWidth("")
        #expect(draft.problems.isEmpty)
        #expect(draft.aspectRatio == nil)
        draft.setPixelWidth("١٠٨٠")
        #expect(draft.aspectRatio == .portrait)
        draft.setRatioWidth(".")
        #expect(draft.problems == [.ratio])
    }

    @Test func readsTheLocalesDecimalSeparator() {
        var draft = CustomRatioDraft(locale: Locale(identifier: "de_DE"))
        draft.setRatioWidth("1,91")
        draft.setRatioHeight("1")
        #expect(draft.pixelHeight == "566")
        #expect(draft.aspectRatio == .landscape)
        draft.setRatioWidth("1.91")
        #expect(draft.problems == [.ratio])
    }
}
