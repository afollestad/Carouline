//
//  PresentationQueueTests.swift
//  CaroulineTests
//

import Testing
@testable import Carouline

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

    /// An ask while one is closing waits for it too, rather than opening as it goes, which would
    /// never show and leave the earlier ask to open later.
    @Test func theLatestAskWinsWhileOneIsClosing() {
        var queue = PresentationQueue<Sheet>()
        queue.present(.style)
        queue.present(.export)

        queue.present(.layout(1))
        #expect(queue.current == nil)
        #expect(queue.pending == .layout(1))
        queue.presentPending()

        #expect(queue.current == .layout(1))
        #expect(queue.pending == nil)
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

    /// It reports whether it closed anything, so a tap can close what's open or else do its own work.
    @Test func dismissesByCase() {
        var queue = PresentationQueue<Sheet>()
        queue.present(.layout(2))

        let closedExport = queue.dismiss { $0 == .export }
        #expect(!closedExport)
        #expect(queue.current == .layout(2))
        let closedLayout = queue.dismiss { if case .layout = $0 { true } else { false } }
        #expect(closedLayout)
        #expect(queue.current == nil)
    }
}
