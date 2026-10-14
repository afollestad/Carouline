//
//  TouchTracking.swift
//  Swipeset
//

import SwiftUI
import UIKit.UIGestureRecognizerSubclass

/// Every finger on the view it's on, from the moment it lands until it lifts, in the coordinate
/// space named `space`. It claims the touches only once `claims` says so, as a scroll view does
/// once it scrolls, so until then the slides' taps, menus and scrolling work as they would without
/// it. A UIKit recognizer rather than `SpatialEventGesture`, under which a tap on a caption's menu
/// also reaches the strip's background tap, ending the selection.
struct TouchTracking: UIGestureRecognizerRepresentable {
    let space: String
    let isEnabled: Bool
    /// The fingers that landed, moved or lifted since the last call.
    let onTouches: ([SelectionTouches.Touch]) -> Void
    /// Whether to claim the touches now, after `onTouches` has taken them.
    let claims: () -> Bool

    /// Keeps the converter SwiftUI hands it, which places touches long after any one update.
    final class Coordinator {
        let converter: CoordinateSpaceConverter

        init(converter: CoordinateSpaceConverter) {
            self.converter = converter
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(converter: converter)
    }

    func makeUIGestureRecognizer(context: Context) -> TouchTrackingRecognizer {
        TouchTrackingRecognizer(target: nil, action: nil)
    }

    func updateUIGestureRecognizer(_ recognizer: TouchTrackingRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
        let converter = context.coordinator.converter
        recognizer.onChanges = { [space, onTouches] changes in
            onTouches(changes.map {
                SelectionTouches.Touch(id: $0.id, location: converter.convert(globalPoint: $0.location, to: .named(space)), isDown: $0.isDown)
            })
        }
        recognizer.claims = claims
    }
}

/// Reports each touch as it lands, moves and lifts, straight from UIKit's touch handling, and none
/// can stop it. Until `claims` says so it doesn't recognize, so it cancels no touch and fails no
/// other gesture; once it does, it cancels the slides' taps under the fingers, so a short drag
/// doesn't end as one. It ends, or fails, once every finger is up, so it starts afresh with the
/// next.
final class TouchTrackingRecognizer: UIGestureRecognizer {
    struct Change {
        let id: ObjectIdentifier
        /// In the window, which SwiftUI calls global.
        let location: CGPoint
        let isDown: Bool
    }

    var onChanges: ([Change]) -> Void = { _ in }
    var claims: () -> Bool = { false }
    private var down: Set<ObjectIdentifier> = []

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        report(touches, isDown: true)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        report(touches, isDown: true)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        report(touches, isDown: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        report(touches, isDown: false)
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func reset() {
        super.reset()
        down = []
    }

    private func report(_ touches: Set<UITouch>, isDown: Bool) {
        let changes = touches.map { Change(id: ObjectIdentifier($0), location: $0.location(in: nil), isDown: isDown) }
        for change in changes {
            if isDown {
                down.insert(change.id)
            } else {
                down.remove(change.id)
            }
        }
        onChanges(changes)
        if down.isEmpty {
            state = state == .possible ? .failed : .ended
        } else if claims() {
            state = state == .possible ? .began : .changed
        }
    }
}
