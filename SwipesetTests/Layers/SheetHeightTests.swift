//
//  SheetHeightTests.swift
//  SwipesetTests
//

import CoreGraphics
import Testing
@testable import Swipeset

struct SheetHeightTests {
    @Test func restsAtHalfTheStrip() {
        #expect(SheetHeight.restingHeight(stripHeight: 700, typingHeight: 150) == 350)
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

    /// The height a sheet has come to rest at, which its detents never report back, a little
    /// short of it, as a floating sheet sits over the bottom safe area.
    @Test func settlesAtTheHeightItCovers() {
        #expect(settled(room: 142) == .typing)
        #expect(settled(room: 354) == .resting)
        #expect(settled(room: 770) == .large)
    }

    /// A drag paused partway, or a sheet riding the keyboard, is at none of them.
    @Test func settlesAtNoHeightBetweenThem() {
        #expect(settled(room: 250) == nil)
        #expect(settled(room: 550) == nil)
    }

    private func settled(room: CGFloat) -> SheetHeight? {
        SheetHeight.settled(room: room, typingHeight: 150, restingHeight: 362, stripHeight: 726)
    }
}
