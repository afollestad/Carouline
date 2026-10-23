//
//  TrayPressGesture.swift
//  Carouline
//

import SwiftUI
import UIKit.UIGestureRecognizerSubclass

/// A finger held on the tray's photos, followed wherever it goes until it lifts, in global
/// coordinates. A UIKit long press rather than SwiftUI's, which hands a drag after it to the tray's
/// scrolling, or holds the scrolling back for every swipe. Once it begins, UIKit fails the tray's
/// scrolling and cancels the tap on the photo under it, so lifting doesn't also place the photo.
struct TrayPressGesture: UIGestureRecognizerRepresentable {
    let onBegin: (CGPoint) -> Void
    let onMove: (CGPoint) -> Void
    /// The finger lifted, where it lifted.
    let onEnd: (CGPoint) -> Void
    /// The system called the press off, as for an alert.
    let onCancel: () -> Void

    /// The system's long press, which the tray's menu opened at before, short of which a finger
    /// lifted taps the photo, and moved far scrolls the tray.
    private static let holdDuration: TimeInterval = 0.5

    func makeUIGestureRecognizer(context: Context) -> TrayPressRecognizer {
        let recognizer = TrayPressRecognizer(target: nil, action: nil)
        recognizer.minimumPressDuration = Self.holdDuration
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: TrayPressRecognizer, context: Context) {
        let location = context.converter.location(in: .global)
        switch recognizer.state {
        case .began: onBegin(location)
        case .changed: onMove(location)
        case .ended: onEnd(location)
        case .cancelled, .failed: onCancel()
        default: break
        }
    }
}

/// A long press that only the tray's scrolling can stop, before it begins, as a swipe does. Nothing
/// else on the photos holds it back.
final class TrayPressRecognizer: UILongPressGestureRecognizer {
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        (preventingGestureRecognizer.view as? UIScrollView)?.panGestureRecognizer === preventingGestureRecognizer
    }
}

/// A secondary click on the tray's photos, as a trackpad's or a mouse's right button gives, where
/// it landed in global coordinates. Pointers only, so a finger's tap still places the photo.
struct TraySecondaryClick: UIGestureRecognizerRepresentable {
    let onClick: (CGPoint) -> Void

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer()
        recognizer.buttonMaskRequired = .secondary
        recognizer.allowedTouchTypes = [UITouch.TouchType.indirectPointer.rawValue as NSNumber]
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        if recognizer.state == .ended {
            onClick(context.converter.location(in: .global))
        }
    }
}
