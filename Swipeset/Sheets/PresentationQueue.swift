//
//  PresentationQueue.swift
//  Swipeset
//

/// The one thing open over a screen, and what opens once it's gone. A presentation asked for
/// while another is up never shows, and its state stays set, so asking again changes nothing.
/// That can happen behind a sheet that leaves the screen in reach, so an ask closes what's open
/// first.
struct PresentationQueue<Item: Hashable> {
    /// What's open, or opening.
    private(set) var current: Item?
    /// What opens once `current`'s content has gone.
    private(set) var pending: Item?

    /// Opens `item`, or, while another is open, closes it and holds `item` back for
    /// `presentPending()`; while one is still closing, `item` takes the place of what's held back.
    /// Asking for what's already open changes nothing.
    mutating func present(_ item: Item) {
        guard current != item else {
            return
        }
        if current == nil, pending == nil {
            current = item
        } else {
            pending = item
            current = nil
        }
    }

    /// Opens what `present(_:)` held back. Call it as the closed presentation's content
    /// disappears, since asking any sooner, while it's still on its way out, never shows.
    mutating func presentPending() {
        guard current == nil, let pending else {
            return
        }
        self.pending = nil
        current = pending
    }

    /// Closes `item` as its presentation is dismissed, leaving alone one opened since.
    mutating func dismiss(_ item: Item) {
        dismiss { $0 == item }
    }

    /// Closes what's open if `matches` says it's the presentation being dismissed.
    mutating func dismiss(where matches: (Item) -> Bool) {
        if let current, matches(current) {
            self.current = nil
        }
    }
}
