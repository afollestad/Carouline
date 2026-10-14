//
//  SheetHeightTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

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

    /// A sheet rests at the height it covers a little short of, as a floating sheet sits over the
    /// bottom safe area.
    @Test func restsAtTheHeightItCovers() {
        #expect(rests(.typing, room: 142))
        #expect(rests(.resting, room: 354))
        #expect(rests(.large, room: 770))
        #expect(!rests(.resting, room: 142))
        #expect(!rests(.typing, room: 354))
        #expect(!rests(.resting, room: 770))
    }

    /// A finger held still mid-drag leaves the sheet at none of them.
    @Test func restsAtNoHeightBetweenThem() {
        for room: CGFloat in [250, 550] {
            #expect(!rests(.typing, room: room))
            #expect(!rests(.resting, room: room))
            #expect(!rests(.large, room: room))
        }
    }

    /// On a short screen the resting height can be within reach of the typing one, and a sheet
    /// selected to rest there still rests.
    @Test func restsAtARestingHeightNearTheTypingOne() {
        #expect(SheetHeight.rests(at: .resting, room: 165, typingHeight: 150, restingHeight: 170, stripHeight: 340))
    }

    private func rests(_ height: SheetHeight, room: CGFloat) -> Bool {
        SheetHeight.rests(at: height, room: room, typingHeight: 150, restingHeight: 362, stripHeight: 726)
    }
}
