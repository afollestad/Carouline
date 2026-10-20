//
//  SheetHeightTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

struct SheetHeightTests {
    @Test func restsAtItsShareOfAShortStrip() {
        #expect(SheetHeight.restingHeight(stripHeight: 600, typingHeight: 150) == 270)
    }

    /// A tall strip, as an iPad's, keeps the slides the room past what the sheet shows at rest.
    @Test func restsNoTallerThanItsCap() {
        #expect(SheetHeight.restingHeight(stripHeight: 1_000, typingHeight: 150) == 320)
    }

    /// On a short screen the resting height stays above the typing height, so the two never swap.
    @Test func neverRestsBelowTheTypingHeight() {
        #expect(SheetHeight.restingHeight(stripHeight: 200, typingHeight: 150) == 150)
    }

    @Test func hasNoRestingHeightUntilTheStripHasMeasuredItself() {
        #expect(SheetHeight.restingHeight(stripHeight: 0, typingHeight: 150) == nil)
    }

    @Test func coversTheStripFromItsTopDown() {
        #expect(SheetHeight.room(stripBottom: 800, sheetTop: 450) == 350)
    }

    @Test func coversNothingBelowTheStripOrBeforeItHasMeasuredItself() {
        #expect(SheetHeight.room(stripBottom: 800, sheetTop: 850) == 0)
        #expect(SheetHeight.room(stripBottom: 0, sheetTop: 450) == 0)
    }
}
