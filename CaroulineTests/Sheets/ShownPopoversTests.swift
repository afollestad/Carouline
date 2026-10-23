//
//  ShownPopoversTests.swift
//  CaroulineTests
//

import Foundation
import Testing
@testable import Carouline

@MainActor
struct ShownPopoversTests {
    @Test func runsRightAwayWithNoPopoverShown() {
        let popovers = ShownPopovers()
        var ran = false

        popovers.whenGone { ran = true }

        #expect(ran)
    }

    /// A popover asked for while another is still closing would be cancelled, so it waits for the
    /// last one to go.
    @Test func holdsTheActionUntilTheLastPopoverHasGone() {
        let popovers = ShownPopovers()
        let first = UUID()
        let second = UUID()
        popovers.shown(first)
        popovers.shown(second)
        var ran = false

        popovers.whenGone { ran = true }
        popovers.gone(first)

        #expect(!ran)
        popovers.gone(second)
        #expect(ran)
    }

    /// Later taps landed while the closing popover still covered the screen.
    @Test func runsOnlyTheFirstActionHeldBack() {
        let popovers = ShownPopovers()
        let popover = UUID()
        popovers.shown(popover)
        var ran: [String] = []

        popovers.whenGone { ran.append("layers") }
        popovers.whenGone { ran.append("options") }
        popovers.gone(popover)

        #expect(ran == ["layers"])
    }

    /// An appearance SwiftUI repeats can't leave the popover counted after it has gone.
    @Test func countsAPopoverShownTwiceOnce() {
        let popovers = ShownPopovers()
        let popover = UUID()
        popovers.shown(popover)
        popovers.shown(popover)
        var ran = false

        popovers.whenGone { ran = true }
        popovers.gone(popover)

        #expect(ran)
    }

    @Test func ignoresAPopoverGoneThatNeverShowed() {
        let popovers = ShownPopovers()
        popovers.shown(UUID())
        var ran = false

        popovers.whenGone { ran = true }
        popovers.gone(UUID())

        #expect(!ran)
    }
}
