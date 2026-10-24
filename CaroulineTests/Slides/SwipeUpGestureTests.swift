//
//  SwipeUpGestureTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

/// When a finger swiping a slide counts as a swipe up, and how far and how fast it rises, from a
/// finger landing at (100, 500).
struct SwipeUpGestureTests {
    private let landing = CGPoint(x: 100, y: 500)

    /// A track with its first finger landed at `landing` at time 0.
    private func landed() -> SwipeUpTrack {
        var track = SwipeUpTrack()
        track.land(1, at: landing, time: 0)
        return track
    }

    private func moved(by width: CGFloat, _ height: CGFloat, at time: TimeInterval = 0.05) -> SwipeUpTrack {
        var track = landed()
        track.move(1, to: CGPoint(x: landing.x + width, y: landing.y + height), time: time)
        return track
    }

    @Test func decidesNothingUntilTheFingerMovesTenPoints() {
        #expect(moved(by: 0, -9).phase == .undecided)
        #expect(moved(by: 0, -10).phase == .rising)
    }

    @Test func startsOnAMoveMostlyUp() {
        #expect(moved(by: 0, -12).phase == .rising)
        #expect(moved(by: 3, -12).phase == .rising)
    }

    /// A move at 45 degrees is as much sideways as up, and leaves the finger to the strip.
    @Test func failsOnAMoveSidewaysAtFortyFiveDegreesOrDown() {
        #expect(moved(by: 12, -3).phase == .failed)
        #expect(moved(by: 10, -10).phase == .failed)
        #expect(moved(by: 0, 12).phase == .failed)
    }

    /// Before it could have started, so the strip scrolls a sideways drag about as soon as it would
    /// have without the swipe.
    @Test func freesASidewaysMoveAtFourPoints() {
        #expect(moved(by: 3, 0).phase == .undecided)
        #expect(moved(by: 4, 0).phase == .failed)
    }

    /// A finger held before it moves, as for a photo's menu or its drag, never swipes.
    @Test func failsOnAMoveThatComesAfterTheWindow() {
        #expect(moved(by: 0, -12, at: 0.29).phase == .rising)
        #expect(moved(by: 0, -12, at: 0.3).phase == .failed)
    }

    @Test func aSecondFingerBeforeItStartsFailsIt() {
        var track = landed()
        let isFollowed = track.land(2, at: CGPoint(x: 200, y: 500), time: 0.02)

        #expect(isFollowed)
        #expect(track.phase == .failed)
    }

    @Test func ignoresAnotherFingerOnceRising() {
        var track = moved(by: 0, -12)
        let isFollowed = track.land(2, at: CGPoint(x: 200, y: 500), time: 0.1)
        track.move(2, to: CGPoint(x: 200, y: 300), time: 0.12)

        #expect(!isFollowed)
        #expect(track.phase == .rising)
        #expect(track.rise == 0)
    }

    /// Only the samples within a tenth of a second of the lift: from 480 at 0.12 to 465 at 0.2.
    @Test func measuresSpeedOverTheLastTenthOfASecond() {
        var track = landed()
        track.move(1, to: CGPoint(x: 100, y: 490), time: 0.05)
        track.move(1, to: CGPoint(x: 100, y: 480), time: 0.12)
        track.move(1, to: CGPoint(x: 100, y: 470), time: 0.17)
        track.lift(1, at: CGPoint(x: 100, y: 465), time: 0.2)

        #expect(abs(track.speed - 187.5) < 1e-6)
    }

    @Test func aPauseBeforeLiftingIsNoFlick() {
        var track = landed()
        track.move(1, to: CGPoint(x: 100, y: 490), time: 0.02)
        track.move(1, to: CGPoint(x: 100, y: 400), time: 0.05)
        track.lift(1, at: CGPoint(x: 100, y: 400), time: 0.5)

        #expect(track.speed == 0)
    }

    /// From where it decided rather than where it landed, so the slide doesn't jump as it starts.
    @Test func risesFromWhereItDecided() {
        var track = landed()
        track.move(1, to: CGPoint(x: 100, y: 488), time: 0.02)
        #expect(track.rise == 0)

        track.move(1, to: CGPoint(x: 100, y: 450), time: 0.05)
        #expect(track.rise == 38)
    }
}
