//
//  SwipeUpGesture.swift
//  Carouline
//

import SwiftUI
import UIKit.UIGestureRecognizerSubclass

/// One finger's swipe up a slide, from the moment it lands: whether it's a swipe at all, and how
/// far and how fast it has risen. A second finger before it decides fails it, as a pinch, and any
/// after are left out.
nonisolated struct SwipeUpTrack {
    enum Phase {
        case undecided
        case rising
        case failed
    }

    private struct Sample {
        let point: CGPoint
        let time: TimeInterval
    }

    /// How far a finger moves, other than up, before it's left to the strip: soon enough that a
    /// sideways drag scrolls it about when it would have without the swipe.
    static let failDistance: CGFloat = 4
    /// How far a finger moves up before it's a swipe: about where a scroll view takes a drag as a
    /// scroll, so a tap that wobbles still reaches the slide.
    static let decisionDistance: CGFloat = 10
    /// How soon after landing a finger has to decide: short of a long press's half second, so one
    /// held for a photo's menu or its drag never swipes.
    static let decisionWindow: TimeInterval = 0.3
    /// How far back a lift measures the finger's speed: short enough that a pause before lifting
    /// reads as stopped rather than as a flick.
    static let speedWindow: TimeInterval = 0.1

    private(set) var phase = Phase.undecided
    /// How far the finger has risen since it decided to swipe, in points, up positive.
    private(set) var rise: CGFloat = 0
    private var finger: AnyHashable?
    private var landing: Sample?
    /// Where the finger decided to swipe, which it rises from, so the slide doesn't jump by the
    /// distance it took to decide.
    private var decision: CGPoint?
    /// The finger's samples within `speedWindow` of the newest.
    private var samples: [Sample] = []

    /// How fast the finger rose over its last samples, in points a second, up positive.
    var speed: CGFloat {
        guard let oldest = samples.first, let last = samples.last, last.time > oldest.time else {
            return 0
        }
        return (oldest.point.y - last.point.y) / CGFloat(last.time - oldest.time)
    }

    /// Takes a finger landing, returning false for one to leave out: any after the first once it
    /// has decided.
    @discardableResult
    mutating func land(_ id: AnyHashable, at point: CGPoint, time: TimeInterval) -> Bool {
        guard finger == nil else {
            if phase == .undecided {
                phase = .failed
                return true
            }
            return false
        }
        finger = id
        landing = Sample(point: point, time: time)
        samples = [Sample(point: point, time: time)]
        return true
    }

    mutating func move(_ id: AnyHashable, to point: CGPoint, time: TimeInterval) {
        guard id == finger, let landing else {
            return
        }
        record(Sample(point: point, time: time))
        switch phase {
        case .undecided: decide(at: point, time: time, from: landing)
        case .rising: updateRise(to: point)
        case .failed: break
        }
    }

    /// Takes the finger lifting, which measures its speed but never decides.
    mutating func lift(_ id: AnyHashable, at point: CGPoint, time: TimeInterval) {
        guard id == finger else {
            return
        }
        record(Sample(point: point, time: time))
        if phase == .rising {
            updateRise(to: point)
        }
    }

    /// Fails a move that comes too late, or that heads other than up, and starts the swipe once
    /// the finger has risen far enough.
    private mutating func decide(at point: CGPoint, time: TimeInterval, from landing: Sample) {
        let translation = CGSize(width: point.x - landing.point.x, height: point.y - landing.point.y)
        let distance = hypot(translation.width, translation.height)
        let isUp = -translation.height > abs(translation.width)
        if time - landing.time >= Self.decisionWindow || (distance >= Self.failDistance && !isUp) {
            phase = .failed
        } else if distance >= Self.decisionDistance {
            phase = .rising
            decision = point
        }
    }

    private mutating func updateRise(to point: CGPoint) {
        rise = (decision?.y ?? point.y) - point.y
    }

    private mutating func record(_ sample: Sample) {
        samples.append(sample)
        samples.removeAll { sample.time - $0.time > Self.speedWindow }
    }
}

/// A finger swiping up the slide it's on, which `SwipeUpTrack` decides on. The strip's scrolling
/// waits for it to fail, which a sideways drag does within a few points, so a steep diagonal never
/// both scrolls the strip and lifts the slide, and nothing on the slide holds it back.
final class SwipeUpRecognizer: UIGestureRecognizer {
    /// Whether the swipe may begin, or end asking, as the slide in front resting in the middle.
    var canBegin: () -> Bool = { false }
    /// How fast the finger rose as it lifted, in points a second.
    private(set) var speed: CGFloat = 0
    private var track = SwipeUpTrack()
    /// The finger the track follows, kept to find what's presented over its window.
    private var tracked: UITouch?

    var rise: CGFloat {
        track.rise
    }

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delaysTouchesEnded = false
        // Not a pointer's drag, which on iPad scrolls the strip as it did.
        allowedTouchTypes = [UITouch.TouchType.direct, .pencil].map { NSNumber(value: $0.rawValue) }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            if !track.land(ObjectIdentifier(touch), at: touch.location(in: nil), time: touch.timestamp) {
                ignore(touch, for: event)
            } else if tracked == nil {
                tracked = touch
            }
        }
        if track.phase == .failed {
            state = .failed
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let tracked, touches.contains(tracked) else {
            return
        }
        let wasUndecided = track.phase == .undecided
        track.move(ObjectIdentifier(tracked), to: tracked.location(in: nil), time: tracked.timestamp)
        switch track.phase {
        case .rising where wasUndecided:
            state = canBegin() && isWindowClear ? .began : .failed
        case .rising:
            state = .changed
        case .failed:
            state = .failed
        case .undecided:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let tracked, touches.contains(tracked) else {
            return
        }
        track.lift(ObjectIdentifier(tracked), at: tracked.location(in: nil), time: tracked.timestamp)
        speed = track.speed
        if isSwiping {
            // One that can no longer ask lowers instead, as when the strip moved meanwhile.
            state = canBegin() && isWindowClear ? .ended : .cancelled
        } else {
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let tracked, touches.contains(tracked) else {
            return
        }
        state = isSwiping ? .cancelled : .failed
    }

    override func shouldBeRequiredToFail(by otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Whatever its state, since UIKit may ask before the touch reaches it.
        Self.isScrollPan(otherGestureRecognizer)
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        Self.isScrollPan(preventingGestureRecognizer)
    }

    override func reset() {
        super.reset()
        track = SwipeUpTrack()
        tracked = nil
        speed = 0
    }

    private var isSwiping: Bool {
        state == .began || state == .changed
    }

    /// Whether nothing is presented over the slide, or on its way in or out, as a sheet, an alert or
    /// a popover is, since a confirmation asked for meanwhile never shows. Found from the finger's
    /// window and the controller hosting the slide, as SwiftUI may not put this recognizer's own
    /// view in the hierarchy.
    private var isWindowClear: Bool {
        guard let tracked, let root = tracked.window?.rootViewController else {
            return false
        }
        var responder: UIResponder? = tracked.view
        while let current = responder, !(current is UIViewController) {
            responder = current.next
        }
        return [root, responder as? UIViewController].allSatisfy { controller in
            controller?.presentedViewController == nil && controller?.transitionCoordinator == nil
        }
    }

    private static func isScrollPan(_ recognizer: UIGestureRecognizer) -> Bool {
        (recognizer.view as? UIScrollView)?.panGestureRecognizer === recognizer
    }
}

/// A swipe up the slide it's on, reporting how far it has risen as it goes, how far and how fast
/// as it ends, and when it's called off. UIKit's rather than a SwiftUI `DragGesture`, which on the
/// strip's slides either holds its scrolling back or scrolls it alongside, and can't fail on a
/// sideways drag.
struct SwipeUpGesture: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let canBegin: () -> Bool
    let onChanged: (_ rise: CGFloat) -> Void
    let onEnded: (_ rise: CGFloat, _ speed: CGFloat) -> Void
    let onCancelled: () -> Void

    func makeUIGestureRecognizer(context: Context) -> SwipeUpRecognizer {
        SwipeUpRecognizer(target: nil, action: nil)
    }

    func updateUIGestureRecognizer(_ recognizer: SwipeUpRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
        recognizer.canBegin = canBegin
    }

    func handleUIGestureRecognizerAction(_ recognizer: SwipeUpRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed: onChanged(recognizer.rise)
        case .ended: onEnded(recognizer.rise, recognizer.speed)
        case .cancelled: onCancelled()
        default: break
        }
    }
}
