//
//  SelectionTouches.swift
//  Swipeset
//

import CoreGraphics
import Foundation

/// The fingers on the strip during `SelectionGesture`, and how they've moved the selection: the
/// middle of the two it follows moves it, and how far apart they spread and how they turn size
/// and turn it. Each update adds what the fingers did since the last, so a finger lifting or
/// landing changes only which fingers the next update measures, and the selection carries on from
/// where it is rather than stopping or jumping.
nonisolated struct SelectionTouches {
    /// A finger as an update reports it.
    struct Touch {
        let id: AnyHashable
        let location: CGPoint
        /// False once the finger has lifted, or the system has cancelled it.
        let isDown: Bool
    }

    /// What the fingers have done since a second joined the move, through any that came and went
    /// since.
    struct Pinch {
        /// How far the fingers' middle has moved since.
        var translation = CGSize.zero
        var magnification: CGFloat
        /// Radians clockwise, or nil until the fingers have turned `minimumTurn`.
        private(set) var rotation: Double?
        /// How far the fingers have turned, reported as `rotation` once it reaches `minimumTurn`.
        private var turned: Double

        init(magnification: CGFloat = 1, rotation: Double? = nil) {
            self.magnification = magnification
            self.rotation = rotation
            turned = rotation ?? 0
        }

        mutating func turn(by step: Double) {
            turned += step
            if rotation != nil || abs(turned) >= SelectionTouches.minimumTurn {
                rotation = turned
            }
        }

        mutating func move(by step: CGSize) {
            translation.width += step.width
            translation.height += step.height
        }
    }

    /// What the fingers down now have done since the fingers followed last changed, which a photo
    /// frames afresh from the crop it's at, so it zooms about the fingers there now.
    struct Segment {
        /// How many times the fingers followed have changed, so a photo knows when to start afresh.
        let count: Int
        /// Where the fingers' middle sat on the selection as the last update left it.
        let anchor: CGPoint
        var translation = CGSize.zero
        /// How far two fingers have spread since, once they pinch, or nil for one finger.
        var magnification: CGFloat?

        mutating func move(by step: CGSize) {
            translation.width += step.width
            translation.height += step.height
        }
    }

    private struct Finger {
        let id: AnyHashable
        let landing: CGPoint
        var location: CGPoint

        var hasTraveled: Bool {
            hypot(location.x - landing.x, location.y - landing.y) >= SelectionTouches.minimumDistance
        }
    }

    /// How far a finger moves before the gesture moves anything: `DragGesture`'s least distance,
    /// so a tap that wobbles still reaches the layers, the cells and the space between the slides.
    static let minimumDistance: CGFloat = 10
    /// How far the fingers turn before the gesture turns anything: `RotateGesture`'s least angle,
    /// so moving or pinching a layer tilted on purpose never straightens it.
    static let minimumTurn = Double.pi / 180

    /// Where the first finger still down when the move began landed, which decides whether a drag
    /// began on the selection.
    private(set) var start: CGPoint?
    /// Whether a finger has moved far enough, or the strip's gesture has recognized a pinch or a
    /// twist, for the gesture to move the selection.
    private(set) var isMoving = false
    /// Whether a trackpad's pinch or twist, which reports no fingers, is moving the selection.
    private(set) var isIndirect = false
    /// How far the fingers' middle has moved in all.
    private(set) var translation = CGSize.zero
    private(set) var pinch: Pinch?
    private(set) var segment = Segment(count: 0, anchor: .zero)
    /// Every finger down, in the order they landed.
    private var fingers: [Finger] = []
    /// The fingers followed at the last update, where they were then.
    private var followed: [Finger] = []
    private var lastSpread: CGFloat = 0
    private var lastAngle: Double = 0

    var isEmpty: Bool {
        fingers.isEmpty
    }

    /// Whether a trackpad's pinch or twist can move the selection: while no finger is down, unless
    /// fingers have moved it already.
    var takesIndirect: Bool {
        isEmpty && (start == nil || isIndirect)
    }

    /// Takes the fingers an update reports, moved, landed or lifted. One it leaves out stays
    /// where it was, and lifts only when it's reported lifted.
    mutating func update(_ touches: [Touch]) {
        // A finger landing after every finger has lifted starts a gesture anew.
        if isEmpty {
            self = SelectionTouches()
        }
        sync(touches)
        let current = Array(fingers.prefix(2))
        if !isMoving, current.contains(where: \.hasTraveled) {
            claim()
        }
        if isMoving, current.count == 2, pinch == nil {
            pinch = Pinch()
        }
        let step = sharedStep(to: current)
        if current.map(\.id) == followed.map(\.id) {
            stretch(to: current)
        } else if !current.isEmpty {
            // Where the fingers' middle sat before this update's step, which the selection is at
            // until it takes the step.
            let middle = Self.middle(of: current)
            let anchor = CGPoint(x: middle.x - step.width, y: middle.y - step.height)
            segment = Segment(count: segment.count + 1, anchor: anchor, magnification: current.count == 2 ? 1 : nil)
        }
        translation.width += step.width
        translation.height += step.height
        pinch?.move(by: step)
        segment.move(by: step)
        remember(current)
    }

    /// Starts the move, as the strip's gesture does when it recognizes a pinch or a twist before
    /// any finger has moved `minimumDistance`. Not without a finger down, so it can't leave the
    /// next tap counting as a move.
    mutating func claim() {
        guard !isMoving, let first = fingers.first else {
            return
        }
        isMoving = true
        start = first.landing
    }

    /// Takes a trackpad's pinch and twist so far, which it reports as no fingers at all, about
    /// `anchor`. Only while no finger is down and none has moved the selection, whose own pinch
    /// counts instead.
    mutating func updateIndirect(magnification: CGFloat?, rotation: Double?, at anchor: CGPoint) {
        guard takesIndirect else {
            return
        }
        isIndirect = true
        isMoving = true
        if start == nil {
            start = anchor
        }
        pinch = Pinch(magnification: magnification ?? 1, rotation: rotation)
        segment = Segment(count: segment.count, anchor: anchor, magnification: magnification ?? 1)
    }

    private mutating func sync(_ touches: [Touch]) {
        for touch in touches {
            if let index = fingers.firstIndex(where: { $0.id == touch.id }) {
                if touch.isDown {
                    fingers[index].location = touch.location
                } else {
                    fingers.remove(at: index)
                }
            } else if touch.isDown {
                fingers.append(Finger(id: touch.id, landing: touch.location, location: touch.location))
            }
        }
    }

    /// How far the fingers followed both last update and now moved, on average: the middle's
    /// move while they stay the same, and the one left's when another lifts or lands with it.
    private func sharedStep(to current: [Finger]) -> CGSize {
        let steps = current.compactMap { finger in
            followed.first { $0.id == finger.id }.map {
                CGSize(width: finger.location.x - $0.location.x, height: finger.location.y - $0.location.y)
            }
        }
        guard !steps.isEmpty else {
            return .zero
        }
        let count = CGFloat(steps.count)
        return CGSize(width: steps.map(\.width).reduce(0, +) / count, height: steps.map(\.height).reduce(0, +) / count)
    }

    /// Sizes and turns the pinch by how the two fingers followed spread and turned since the last
    /// update, a step at a time, so a twist past a half turn doesn't flip.
    private mutating func stretch(to current: [Finger]) {
        guard current.count == 2 else {
            return
        }
        let (spread, angle) = Self.measure(current)
        guard spread > 0, lastSpread > 0 else {
            return
        }
        let ratio = spread / lastSpread
        pinch?.magnification *= ratio
        if pinch != nil {
            segment.magnification? *= ratio
        }
        pinch?.turn(by: remainder(angle - lastAngle, 2 * .pi))
    }

    private mutating func remember(_ current: [Finger]) {
        followed = current
        if current.count == 2 {
            (lastSpread, lastAngle) = Self.measure(current)
        } else {
            (lastSpread, lastAngle) = (0, 0)
        }
    }

    /// How far apart two fingers are, and the angle from the first to the second, which grows
    /// clockwise, since the strip's y grows down.
    private static func measure(_ pair: [Finger]) -> (spread: CGFloat, angle: Double) {
        let across = pair[1].location.x - pair[0].location.x
        let down = pair[1].location.y - pair[0].location.y
        return (hypot(across, down), Double(atan2(down, across)))
    }

    private static func middle(of current: [Finger]) -> CGPoint {
        let count = CGFloat(current.count)
        return CGPoint(x: current.map(\.location.x).reduce(0, +) / count, y: current.map(\.location.y).reduce(0, +) / count)
    }
}
