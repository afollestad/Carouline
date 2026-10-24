//
//  SlideLiftTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

/// How far a swipe lifts a slide, and when it asks to delete it, for a slide that asks at 100
/// points.
@MainActor
struct SlideLiftTests {
    private let deleteRise: CGFloat = 100

    @Test func asksOncePastTheDeleteRise() {
        let lift = SlideLift()
        var asked = 0

        lift.follow(120, deleteRise: deleteRise)
        lift.release(rise: 120, speed: 0, deleteRise: deleteRise) { asked += 1 }

        #expect(asked == 1)
        #expect(lift.isAsking)
        #expect(lift.rise == deleteRise)
    }

    @Test func asksAtExactlyTheDeleteRiseAndFlickSpeed() {
        #expect(SlideLift.asks(rise: 100, speed: 0, deleteRise: deleteRise))
        #expect(SlideLift.asks(rise: 10, speed: SlideLift.flickSpeed, deleteRise: deleteRise))
        #expect(!SlideLift.asks(rise: 99.9, speed: SlideLift.flickSpeed - 0.1, deleteRise: deleteRise))
    }

    @Test func asksOnAFlickHoweverShort() {
        let lift = SlideLift()
        var asked = 0

        lift.follow(5, deleteRise: deleteRise)
        lift.release(rise: 5, speed: 1000, deleteRise: deleteRise) { asked += 1 }

        #expect(asked == 1)
        #expect(lift.rise == deleteRise)
    }

    /// Before the strip has measured the slide, nothing it lays out yet could be deleted.
    @Test func asksNothingBeforeTheStripIsMeasured() {
        let lift = SlideLift()
        var asked = 0

        lift.release(rise: 50, speed: 2000, deleteRise: 0) { asked += 1 }

        #expect(asked == 0)
        #expect(!lift.isAsking)
    }

    @Test func lowersASlowShortSwipe() {
        let lift = SlideLift()
        var asked = 0

        lift.follow(30, deleteRise: deleteRise)
        lift.release(rise: 30, speed: 10, deleteRise: deleteRise) { asked += 1 }

        #expect(asked == 0)
        #expect(!lift.isAsking)
        #expect(lift.rise == 0)
    }

    @Test func lowersOnceAsked() {
        let lift = SlideLift()
        lift.release(rise: 120, speed: 0, deleteRise: deleteRise) {}

        lift.lower()

        #expect(!lift.isAsking)
        #expect(!lift.hasReachedAsk)
        #expect(lift.rise == 0)
    }

    @Test func neverFollowsBelowWhereItRests() {
        let lift = SlideLift()

        lift.follow(-20, deleteRise: deleteRise)

        #expect(lift.rise == 0)
    }

    /// A third of the finger's pace past where it asks: 60 points past it rises 20.
    @Test func slowsPastTheDeleteRise() {
        let lift = SlideLift()

        lift.follow(160, deleteRise: deleteRise)

        #expect(lift.rise == 120)
    }

    @Test func reachesTheAskOnce() {
        let lift = SlideLift()

        lift.follow(99, deleteRise: deleteRise)
        #expect(!lift.hasReachedAsk)

        lift.follow(100, deleteRise: deleteRise)
        #expect(lift.hasReachedAsk)
    }

    @Test func reachesNothingBeforeTheStripIsMeasured() {
        let lift = SlideLift()

        lift.follow(10, deleteRise: 0)

        #expect(!lift.hasReachedAsk)
    }

    @Test func lowersNothingNeverLifted() {
        let lift = SlideLift()

        lift.lower()

        #expect(!lift.isLifted)
        #expect(lift.rise == 0)
    }

    /// Fades out from where it asked, rather than dropping as its confirmation closes.
    @Test func staysLiftedWhileItsDeleted() {
        let lift = SlideLift()
        lift.release(rise: 120, speed: 0, deleteRise: deleteRise) {}

        lift.isDeleting = true
        lift.lower()

        #expect(lift.isAsking)
        #expect(lift.rise == deleteRise)
    }

    @Test func ignoresASwipeWhileItAsks() {
        let lift = SlideLift()
        var asked = 0
        lift.release(rise: 120, speed: 0, deleteRise: deleteRise) { asked += 1 }

        lift.follow(10, deleteRise: deleteRise)
        lift.release(rise: 10, speed: 0, deleteRise: deleteRise) { asked += 1 }

        #expect(asked == 1)
        #expect(lift.isAsking)
        #expect(lift.rise == deleteRise)
    }

    /// A cancel UIKit delivers after the swipe asked leaves the slide asking, which only the
    /// confirmation's answer lowers.
    @Test func aCancelAfterAskingLeavesItAsking() {
        let lift = SlideLift()
        lift.release(rise: 120, speed: 0, deleteRise: deleteRise) {}

        lift.cancel()

        #expect(lift.isAsking)
    }

    @Test func risesAThirdOfAShortSlide() {
        #expect(SlideLift.deleteRise(slideHeight: 240) == 80)
    }

    @Test func risesNoMoreThan100Points() {
        #expect(SlideLift.deleteRise(slideHeight: 600) == 100)
    }
}
