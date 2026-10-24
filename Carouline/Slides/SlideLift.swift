//
//  SlideLift.swift
//  Carouline
//

import Observation
import SwiftUI

/// How far a swipe up has lifted a slide, which asks to delete it once it's lifted far enough or
/// flicked, and waits there for the answer. Only `LiftEffect` reads `rise`, so each step of a swipe
/// moves the card without redrawing it.
@Observable
final class SlideLift {
    private(set) var rise: CGFloat = 0
    /// From a swipe's start until the slide is back down, while its controls take no taps, so
    /// nothing under the finger fires as it lifts.
    private(set) var isLifted = false
    private(set) var isAsking = false
    /// Whether this swipe has reached where it asks, which taps once.
    private(set) var hasReachedAsk = false
    /// Whether the confirmation this lift asked for has shown, which SwiftUI may never do for one
    /// asked for as something else closes.
    var hasShownAsk = false
    /// Set as the slide is deleted, so it fades out from where it's lifted.
    var isDeleting = false
    /// Advanced by each swipe and lowering, so a lowering's end can't free the controls of a slide
    /// a newer swipe has lifted.
    @ObservationIgnored private var lowering = 0

    /// How fast a flick up asks, however short, as swipes away do elsewhere in iOS.
    static let flickSpeed: CGFloat = 800

    /// How far a slide `slideHeight` tall lifts to ask: a third of it, far enough to be meant, and
    /// no more than 100 points, so a phone's slide in landscape, with little room above it, stays
    /// mostly on screen.
    static func deleteRise(slideHeight: CGFloat) -> CGFloat {
        min(100, max(0, slideHeight) / 3)
    }

    /// Whether a swipe that rose `rise` points, `speed` points a second as it lifted, asks. Never
    /// before the strip has measured the slide.
    static func asks(rise: CGFloat, speed: CGFloat, deleteRise: CGFloat) -> Bool {
        deleteRise > 0 && (rise >= deleteRise || speed >= flickSpeed)
    }

    /// Follows the finger up, at its pace up to `deleteRise` and a third of it past, so a long
    /// drag can't carry the slide off screen.
    func follow(_ rise: CGFloat, deleteRise: CGFloat) {
        guard !isAsking else {
            return
        }
        lowering += 1
        isLifted = true
        self.rise = max(0, rise <= deleteRise ? rise : deleteRise + (rise - deleteRise) / 3)
        if deleteRise > 0, self.rise >= deleteRise {
            hasReachedAsk = true
        }
    }

    /// Settles the slide where it asks and asks, once it rose far enough or was flicked, or else
    /// lowers it.
    func release(rise: CGFloat, speed: CGFloat, deleteRise: CGFloat, onAsk: () -> Void) {
        guard !isAsking else {
            return
        }
        guard Self.asks(rise: rise, speed: speed, deleteRise: deleteRise) else {
            lower()
            return
        }
        hasShownAsk = false
        withAnimation(.smooth) {
            isAsking = true
            hasReachedAsk = true
            self.rise = deleteRise
        }
        onAsk()
    }

    /// Lowers the slide, unless it's being deleted, and frees its controls once it's down.
    func lower() {
        guard !isDeleting, isLifted || isAsking || rise != 0 else {
            return
        }
        guard isAsking || rise != 0 else {
            isLifted = false
            hasReachedAsk = false
            return
        }
        lowering += 1
        let token = lowering
        withAnimation(.smooth) {
            isAsking = false
            hasReachedAsk = false
            rise = 0
        } completion: { [weak self] in
            guard let self, self.lowering == token else {
                return
            }
            self.isLifted = false
        }
    }

    /// Lowers a swipe UIKit called off, unless it already asks, which only its answer lowers.
    func cancel() {
        guard !isAsking else {
            return
        }
        lower()
    }

    /// The swipe that lifts a slide `slideHeight` tall, which calls `onAsk` once it asks.
    func swipeUp(isEnabled: Bool, canBegin: @escaping () -> Bool, slideHeight: CGFloat, onAsk: @escaping () -> Void) -> SwipeUpGesture {
        let deleteRise = Self.deleteRise(slideHeight: slideHeight)
        return SwipeUpGesture(
            isEnabled: isEnabled,
            canBegin: canBegin,
            onChanged: { [self] rise in
                self.follow(rise, deleteRise: deleteRise)
            },
            onEnded: { [self] rise, speed in
                self.release(rise: rise, speed: speed, deleteRise: deleteRise, onAsk: onAsk)
            },
            onCancelled: { [self] in
                self.cancel()
            }
        )
    }
}

/// Lifts a card by its slide's lift, fading it toward where it asks and tapping as it gets there,
/// and lowers it once its confirmation closes, once it can no longer ask, or once an ask never
/// shows. An offset rather than a visual effect, so the confirmation anchored inside, the tour's
/// anchors and taps all move with it.
struct LiftEffect: ViewModifier {
    let lift: SlideLift
    let slideHeight: CGFloat
    /// The card's confirmation, named apart from the lift's `isAsking`.
    @Binding var isConfirming: Bool
    /// Whether the slide can still ask, as the one in front with nothing else going on.
    let isEnabled: Bool

    /// Longer than a popover takes to close, which an ask held by `ShownPopovers` waits for, and
    /// short enough that one SwiftUI never shows lowers the slide before it looks stuck.
    static let askTimeout: Duration = .seconds(1)
    /// How faded a slide is where it asks: enough to read as on its way out, while it stays
    /// readable under its confirmation.
    private static let fade = 0.5

    func body(content: Content) -> some View {
        let deleteRise = SlideLift.deleteRise(slideHeight: slideHeight)
        content
            .offset(y: -(lift.isAsking ? deleteRise : lift.rise))
            // As one, so the photos don't show through the layers, nor the shadow through the slide.
            .compositingGroup()
            .opacity(1 - Self.fade * progress(toward: deleteRise))
            .sensoryFeedback(.impact, trigger: lift.hasReachedAsk) { !$0 && $1 }
            .onChange(of: isConfirming) { _, isConfirming in
                if !isConfirming {
                    lift.lower()
                }
            }
            // Not while the confirmation shows, which only its answer closes, as a turn of the
            // screen can pass the strip's middle by a neighbor on its way.
            .onChange(of: isEnabled) { _, isEnabled in
                if !isEnabled, !isConfirming {
                    lift.lower()
                }
            }
            .task(id: lift.isAsking) {
                guard lift.isAsking else {
                    return
                }
                try? await Task.sleep(for: Self.askTimeout)
                guard !Task.isCancelled, lift.isAsking, !lift.hasShownAsk else {
                    return
                }
                if isConfirming {
                    isConfirming = false
                } else {
                    lift.lower()
                }
            }
    }

    /// How far the slide is toward where it asks, from 0 to 1. None before the strip has measured
    /// it, which would otherwise divide by nothing.
    private func progress(toward deleteRise: CGFloat) -> CGFloat {
        guard deleteRise > 0 else {
            return 0
        }
        return lift.isAsking ? 1 : min(1, lift.rise / deleteRise)
    }
}
