//
//  RoomFitTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

/// How far the slides shrink and move up above a layers sheet, on strips about the size of each
/// screen's, with the selection bar's 76 points reserved below them.
struct RoomFitTests {
    /// iPhone 18 Pro's strip, with a 4:5 slide and its caption, above the resting sheet: the slide
    /// fills the room left, short of the margin either side.
    @Test func fitsTheSlideAboveTheSheetOnAPhone() {
        let fit = fit(slideHeight: 468, stripHeight: 724, room: 320)
        #expect(abs(fit.scale - 380 / 468) < 0.001)
        #expect(abs(top(of: fit, slideHeight: 468, stripHeight: 724) - RoomFit.margin) < 0.001)
    }

    /// iPad mini's strip in portrait keeps the slide nearly whole above the sheet.
    @Test func keepsTheSlideNearlyWholeOnAnIPad() {
        let fit = fit(slideHeight: 707, stripHeight: 1_039, room: 320)
        #expect(abs(fit.scale - 695 / 707) < 0.001)
    }

    /// A slide short enough for the room keeps its size, and moves up to the middle of the room.
    @Test func centersASlideThatFitsWhole() {
        let fit = fit(slideHeight: 229, stripHeight: 724, room: 320)
        #expect(fit.scale == 1)
        #expect(abs(top(of: fit, slideHeight: 229, stripHeight: 724) - (404 - 229) / 2) < 0.001)
    }

    /// A sheet swiped nearly away covers less than the selection bar's room, and leaves the slides
    /// where they sit without it, rather than dipping below.
    @Test func leavesTheSlidesWhereTheyAreInTheSelectionBarsRoom() {
        #expect(fit(slideHeight: 468, stripHeight: 724, room: 40) == .identity)
    }

    /// A large sheet covers more than the strip, which shrinks the slides no further than the least
    /// scale, at the top.
    @Test func shrinksNoFurtherThanTheLeastScale() {
        let fit = fit(slideHeight: 468, stripHeight: 724, room: 780)
        #expect(fit.scale == RoomFit.minimumScale)
        #expect(abs(top(of: fit, slideHeight: 468, stripHeight: 724) - RoomFit.margin) < 0.001)
    }

    @Test func leavesTheSlidesWhereTheyAreWithoutRoomOrAStrip() {
        #expect(fit(slideHeight: 468, stripHeight: 724, room: 0) == .identity)
        #expect(fit(slideHeight: 468, stripHeight: 0, room: 320) == .identity)
    }

    private func fit(slideHeight: CGFloat, stripHeight: CGFloat, room: CGFloat) -> RoomFit {
        RoomFit(slideHeight: slideHeight, stripHeight: stripHeight, bottomReserve: 76, room: room)
    }

    /// Where the slide's top lands on the strip, which scales from its top and then moves up.
    private func top(of fit: RoomFit, slideHeight: CGFloat, stripHeight: CGFloat) -> CGFloat {
        (stripHeight - 76 - slideHeight) / 2 * fit.scale + fit.offset
    }
}
