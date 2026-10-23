//
//  ShownPopovers.swift
//  Carouline
//

import SwiftUI

/// The popovers on a screen, from when each shows until it has gone, and what a button asks for
/// meanwhile, which waits for them. SwiftUI cancels a popover asked for while another is still
/// closing, as one is for a moment after it looks gone, so the button seemed to need a second tap.
/// Not observed, since no view draws from it.
final class ShownPopovers {
    /// Each popover's own ID rather than a count, so an appearance SwiftUI repeats without a
    /// disappearance can't leave one counted for good, holding every button back.
    private var shownIDs: Set<UUID> = []
    private var pending: (() -> Void)?

    /// Does `action` now, or once every popover has gone. Only the first held back goes, since any
    /// after it were tapped while the one closing still covered the screen.
    func whenGone(_ action: @escaping () -> Void) {
        if shownIDs.isEmpty {
            action()
        } else if pending == nil {
            pending = action
        }
    }

    func shown(_ id: UUID) {
        shownIDs.insert(id)
    }

    func gone(_ id: UUID) {
        guard shownIDs.remove(id) != nil, shownIDs.isEmpty, let action = pending else {
            return
        }
        pending = nil
        action()
    }
}

extension ShownPopovers? {
    /// `whenGone`, or `action` at once where the screen doesn't track its popovers, as in previews.
    func whenGone(_ action: @escaping () -> Void) {
        if let self {
            self.whenGone(action)
        } else {
            action()
        }
    }
}

extension EnvironmentValues {
    /// The screen's popovers, which its buttons wait on to open another.
    @Entry var shownPopovers: ShownPopovers?
}

extension View {
    /// Gives this screen `shownPopovers` of its own, for what it shows and presents.
    func tracksPopovers() -> some View {
        modifier(TracksPopovers())
    }

    /// Counts this view, a popover's content, among the screen's `shownPopovers` while it's on screen.
    func countsAsPopover() -> some View {
        modifier(CountsAsPopover())
    }
}

private struct TracksPopovers: ViewModifier {
    @State private var popovers = ShownPopovers()

    func body(content: Content) -> some View {
        content
            .environment(\.shownPopovers, popovers)
    }
}

private struct CountsAsPopover: ViewModifier {
    @State private var id = UUID()
    @Environment(\.shownPopovers) private var popovers

    func body(content: Content) -> some View {
        content
            .onAppear { popovers?.shown(id) }
            .onDisappear { popovers?.gone(id) }
    }
}
