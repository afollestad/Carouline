//
//  SelectionTouchesTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

struct SelectionTouchesTests {
    private func touch(_ id: Int, _ x: CGFloat, _ y: CGFloat, isDown: Bool = true) -> SelectionTouches.Touch {
        SelectionTouches.Touch(id: id, location: CGPoint(x: x, y: y), isDown: isDown)
    }

    /// Two fingers 100 points apart, moved together far enough to start the move and the pinch, so
    /// a test measures from there.
    private func pinching() -> SelectionTouches {
        var touches = SelectionTouches()
        touches.update([touch(1, 0, 0), touch(2, 100, 0)])
        touches.update([touch(1, 10, 0), touch(2, 110, 0)])
        return touches
    }

    @Test func movesNothingUntilAFingerTravelsFarEnough() {
        var touches = SelectionTouches()

        touches.update([touch(1, 0, 0)])
        touches.update([touch(1, 3, 4)])
        #expect(!touches.isMoving)
        touches.update([touch(1, 6, 8)])

        #expect(touches.isMoving)
        #expect(touches.start == .zero)
        #expect(touches.translation == CGSize(width: 6, height: 8))
    }

    @Test func aThirdFingerIsNotFollowed() {
        var touches = SelectionTouches()

        touches.update([touch(1, 0, 0), touch(2, 100, 0), touch(3, 200, 0)])
        touches.update([touch(3, 300, 0)])

        #expect(!touches.isMoving)
        #expect(touches.translation == .zero)
    }

    @Test func twoFingersMoveSizeAndTurnTogether() {
        var touches = pinching()
        #expect(touches.pinch?.magnification == 1)
        #expect(touches.pinch?.rotation == nil)

        touches.update([touch(1, 30, 30), touch(2, 130, 30)])
        #expect(touches.translation == CGSize(width: 30, height: 30))
        touches.update([touch(2, 230, 30)])
        #expect(touches.pinch?.magnification == 2)
        // A quarter turn clockwise, about the first finger.
        touches.update([touch(2, 30, 230)])

        #expect(touches.pinch?.rotation == .pi / 2)
        #expect(touches.pinch?.magnification == 2)
    }

    /// A turn too small to mean one, as fingers wobble in a move or a pinch, turns nothing.
    @Test func turnsOnlyOnceTheFingersTurnADegree() throws {
        var touches = pinching()

        touches.update([touch(2, 110, 1)])
        #expect(touches.pinch?.rotation == nil)
        touches.update([touch(2, 110, 2)])

        let rotation = try #require(touches.pinch?.rotation)
        #expect(abs(rotation - atan2(2, 100)) < 1e-12)
    }

    @Test func liftingAFingerMidPinchCarriesOnWithTheOther() {
        var touches = pinching()
        touches.update([touch(2, 210, 0)])

        touches.update([touch(2, 210, 0, isDown: false)])
        #expect(touches.translation == CGSize(width: 60, height: 0))
        touches.update([touch(1, 30, 0)])

        #expect(touches.translation == CGSize(width: 80, height: 0))
        #expect(touches.pinch?.magnification == 2)
    }

    /// A finger's move in the same update another lifts in still counts, and the photo frames
    /// afresh from where the fingers were before it.
    @Test func aLiftAndAMoveInOneUpdateKeepTheMove() {
        var touches = pinching()

        touches.update([touch(1, 10, 0, isDown: false), touch(2, 130, 0)])

        #expect(touches.translation == CGSize(width: 30, height: 0))
        #expect(touches.pinch?.translation == CGSize(width: 30, height: 0))
        #expect(touches.segment.count == 2)
        #expect(touches.segment.anchor == CGPoint(x: 110, y: 0))
        #expect(touches.segment.translation == CGSize(width: 20, height: 0))
        #expect(touches.segment.magnification == nil)
    }

    @Test func aFingerLeftOutOfAnUpdateStaysWhereItWas() {
        var touches = pinching()

        touches.update([touch(2, 210, 0)])

        #expect(touches.pinch?.magnification == 2)
        #expect(touches.translation == CGSize(width: 60, height: 0))
    }

    @Test func aFingerFirstReportedLiftedIsNeverAdded() {
        var touches = SelectionTouches()

        touches.update([touch(1, 0, 0)])
        touches.update([touch(2, 50, 0, isDown: false)])
        touches.update([touch(1, 20, 0)])

        #expect(touches.translation == CGSize(width: 20, height: 0))
        #expect(touches.pinch == nil)
    }

    @Test func aSecondFingerJoiningADragStartsThePinchWithoutAJump() {
        var touches = SelectionTouches()
        touches.update([touch(1, 0, 0)])
        touches.update([touch(1, 30, 0)])

        touches.update([touch(2, 200, 50)])
        #expect(touches.translation == CGSize(width: 30, height: 0))
        #expect(touches.pinch?.translation == .zero)
        touches.update([touch(1, 40, 0), touch(2, 210, 50)])

        #expect(touches.translation == CGSize(width: 40, height: 0))
        #expect(touches.pinch?.translation == CGSize(width: 10, height: 0))
    }

    /// A second finger that touches down and lifts before anything moves, as a palm might,
    /// doesn't make the drag after it a pinch.
    @Test func aBriefSecondTouchBeforeAnyMoveMakesNoPinch() {
        var touches = SelectionTouches()

        touches.update([touch(1, 0, 0)])
        touches.update([touch(2, 100, 0)])
        touches.update([touch(2, 100, 0, isDown: false)])
        touches.update([touch(1, 20, 0)])

        #expect(touches.isMoving)
        #expect(touches.pinch == nil)
    }

    /// A finger that lifted before anything moved doesn't decide where the drag began.
    @Test func startsWhereTheFirstFingerStillDownLanded() {
        var touches = SelectionTouches()

        touches.update([touch(1, 0, 0), touch(2, 100, 100)])
        touches.update([touch(1, 0, 0, isDown: false)])
        touches.update([touch(2, 100, 120)])

        #expect(touches.start == CGPoint(x: 100, y: 100))
    }

    @Test func aThirdFingerTakesOverWithoutAJump() {
        var touches = pinching()
        touches.update([touch(3, 310, 0)])

        touches.update([touch(1, 10, 0, isDown: false)])
        #expect(touches.translation == CGSize(width: 10, height: 0))
        touches.update([touch(3, 510, 0)])

        #expect(touches.pinch?.magnification == 2)
        #expect(touches.translation == CGSize(width: 110, height: 0))
    }

    @Test func pinchingAgainAfterALiftMultipliesOnAndFramesAfresh() {
        var touches = pinching()
        touches.update([touch(2, 210, 0)])
        touches.update([touch(2, 210, 0, isDown: false)])

        touches.update([touch(3, 10, 100)])
        #expect(touches.segment.count == 3)
        #expect(touches.segment.anchor == CGPoint(x: 10, y: 50))
        touches.update([touch(3, 10, 150)])

        #expect(touches.pinch?.magnification == 3)
        #expect(touches.segment.magnification == 1.5)
    }

    @Test func aTwistPastAHalfTurnAddsUpWithoutFlipping() throws {
        var touches = pinching()

        for step in 1...4 {
            let angle = Double(step) * .pi / 3
            touches.update([touch(2, 10 + 100 * cos(angle), 100 * sin(angle))])
        }

        let rotation = try #require(touches.pinch?.rotation)
        #expect(abs(rotation - 4 * .pi / 3) < 1e-9)
    }

    @Test func fingersMeetingLeaveTheSizeFinite() {
        var touches = pinching()

        touches.update([touch(2, 10, 0)])
        #expect(touches.pinch?.magnification == 1)
        touches.update([touch(2, 60, 0)])
        touches.update([touch(2, 110, 0)])

        let magnification = touches.pinch?.magnification ?? 0
        #expect(magnification.isFinite && magnification > 0)
    }

    /// The strip's gesture can start the move before any finger travels far, but not with none
    /// down, which would leave the next tap counting as a move.
    @Test func claimingStartsTheMoveOnlyWithAFingerDown() {
        var touches = SelectionTouches()

        touches.claim()
        #expect(!touches.isMoving)
        touches.update([touch(1, 0, 0)])
        touches.claim()

        #expect(touches.isMoving)
        #expect(touches.start == .zero)
    }

    @Test func aFingerLandingAfterEveryFingerLiftedStartsAfresh() {
        var touches = SelectionTouches()
        touches.update([touch(1, 0, 0)])
        touches.update([touch(1, 20, 0)])

        touches.update([touch(1, 20, 0, isDown: false)])
        #expect(touches.isEmpty)
        #expect(touches.segment.count == 1)
        touches.update([touch(2, 50, 50)])

        #expect(!touches.isMoving)
        #expect(touches.start == nil)
        #expect(touches.translation == .zero)
    }

    @Test func aTrackpadPinchMovesWithNoFingers() {
        var touches = SelectionTouches()

        touches.updateIndirect(magnification: 1.5, rotation: 0.2, at: CGPoint(x: 40, y: 40))

        #expect(touches.isIndirect)
        #expect(touches.isMoving)
        #expect(touches.start == CGPoint(x: 40, y: 40))
        #expect(touches.pinch?.magnification == 1.5)
        #expect(touches.pinch?.rotation == 0.2)
        #expect(touches.segment.anchor == CGPoint(x: 40, y: 40))
        #expect(touches.segment.magnification == 1.5)
    }

    /// A finger's own pinch counts while one is down, and a trackpad's values, which still
    /// arrive for a moment after fingers moved the selection, change nothing then.
    @Test func aTrackpadPinchIsIgnoredWhileOrAfterFingersMove() {
        var down = SelectionTouches()
        down.update([touch(1, 0, 0)])
        var lifted = down
        lifted.update([touch(1, 20, 0)])
        lifted.update([touch(1, 20, 0, isDown: false)])

        down.updateIndirect(magnification: 2, rotation: nil, at: .zero)
        lifted.updateIndirect(magnification: 2, rotation: nil, at: .zero)

        #expect(!down.isIndirect && down.pinch == nil)
        #expect(!lifted.isIndirect && lifted.pinch == nil)
    }
}
