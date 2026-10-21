//
//  SheetHeightTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

struct SheetHeightTests {
    @Test func restsAtItsShareOfAShortStrip() {
        #expect(SheetHeight.restingHeight(stripHeight: 600, typingHeight: 150, margin: 16) == 270)
    }

    /// A tall strip, as an iPad's, keeps the slides the room past what the sheet shows at rest.
    @Test func restsNoTallerThanItsCap() {
        #expect(SheetHeight.restingHeight(stripHeight: 1_000, typingHeight: 150, margin: 16) == 289)
    }

    /// A wider margin sets the buttons lower, the content further below them and the margin under
    /// it wider, so the sheet rests taller by three times the difference.
    @Test func capsItsRestingHeightByItsMargin() {
        #expect(SheetHeight.restingCap(margin: 16) == 289)
        #expect(SheetHeight.restingCap(margin: 20) == 301)
    }

    /// Content keeps clear of the title bar however narrow the margin.
    @Test func startsContentBelowTheTitleBar() {
        #expect(SheetHeight.topGap(margin: 16) == 16)
        #expect(SheetHeight.topGap(margin: 4) == SheetHeight.titleBarBelowButtons)
    }

    /// A phone's sheet shows past its height over the keyboard, by its bottom safe area less the
    /// keyboard's overlap, and an iPad's, with no such inset, by none.
    @Test func reachesOverTheKeyboardByItsBottomInset() {
        #expect(SheetHeight.reachOverKeyboard(bottomInset: 34) == 34 - SheetHeight.keyboardOverlap)
        #expect(SheetHeight.reachOverKeyboard(bottomInset: 0) == 0)
    }

    /// On a short screen the resting height stays above the typing height, so the two never swap.
    @Test func neverRestsBelowTheTypingHeight() {
        #expect(SheetHeight.restingHeight(stripHeight: 200, typingHeight: 150, margin: 16) == 150)
    }

    @Test func hasNoRestingHeightUntilTheStripHasMeasuredItself() {
        #expect(SheetHeight.restingHeight(stripHeight: 0, typingHeight: 150, margin: 16) == nil)
    }

    @Test func coversTheStripFromItsTopDown() {
        #expect(SheetHeight.room(stripBottom: 800, sheetTop: 450) == 350)
    }

    @Test func coversNothingBelowTheStripOrBeforeItHasMeasuredItself() {
        #expect(SheetHeight.room(stripBottom: 800, sheetTop: 850) == 0)
        #expect(SheetHeight.room(stripBottom: 0, sheetTop: 450) == 0)
    }
}
