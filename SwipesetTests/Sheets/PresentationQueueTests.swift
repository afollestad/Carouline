//
//  PresentationQueueTests.swift
//  SwipesetTests
//

import Testing
@testable import Swipeset

@MainActor
struct PresentationQueueTests {
    private enum Sheet: Hashable {
        case style
        case export
        case layout(Int)
    }

    @Test func opensRightAwayWhenNothingIsOpen() {
        var queue = PresentationQueue<Sheet>()

        queue.present(.style)

        #expect(queue.current == .style)
        #expect(queue.pending == nil)
    }

    /// Opening another while one is up would never show, so the open one closes first and the
    /// next waits until it has gone.
    @Test func closesWhatsOpenAndHoldsTheNextUntilItHasGone() {
        var queue = PresentationQueue<Sheet>()
        queue.present(.style)

        queue.present(.export)

        #expect(queue.current == nil)
        #expect(queue.pending == .export)
        queue.presentPending()
        #expect(queue.current == .export)
        #expect(queue.pending == nil)
    }

    @Test func askingForWhatsOpenChangesNothing() {
        var queue = PresentationQueue<Sheet>()
        queue.present(.style)

        queue.present(.style)

        #expect(queue.current == .style)
        #expect(queue.pending == nil)
    }

    @Test func theLatestAskWinsWhileOneIsClosing() {
        var queue = PresentationQueue<Sheet>()
        queue.present(.style)
        queue.present(.export)

        queue.present(.layout(1))
        queue.presentPending()

        #expect(queue.current == .layout(1))
    }

    /// The closed presentation's content disappears after the next has opened when nothing was
    /// held back, which mustn't open anything.
    @Test func presentingPendingWithNothingHeldBackChangesNothing() {
        var queue = PresentationQueue<Sheet>()
        queue.present(.style)

        queue.presentPending()

        #expect(queue.current == .style)
    }

    /// A dismissal reported late, after another opened, leaves the new one alone.
    @Test func dismissingClosesOnlyWhatsStillOpen() {
        var queue = PresentationQueue<Sheet>()
        queue.present(.export)

        queue.dismiss(.style)
        #expect(queue.current == .export)
        queue.dismiss(.export)
        #expect(queue.current == nil)
    }

    @Test func dismissesByCase() {
        var queue = PresentationQueue<Sheet>()
        queue.present(.layout(2))

        queue.dismiss { if case .layout = $0 { true } else { false } }

        #expect(queue.current == nil)
    }
}
