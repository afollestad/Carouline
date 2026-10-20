//
//  RoomFit.swift
//  Carouline
//

import CoreGraphics

/// How far the slides shrink, and how far up they move, to stay in view and in reach above a
/// layers sheet, or above the keyboard and the short sheet over it while a text layer is typed.
nonisolated struct RoomFit: Equatable, Sendable {
    static let identity = RoomFit()

    /// The least the slides shrink to. The large sheet can cover the whole strip, which would scale
    /// them to nothing or flip them, though it covers them then.
    static let minimumScale: CGFloat = 0.2
    /// The room on screen above the slide and below its caption, which keeps them clear of the
    /// bar and the sheet, without the bands either side of a slide at full size.
    static let margin: CGFloat = 12

    var scale: CGFloat = 1
    /// How far up the slides move, past where the scale, anchored at the strip's top, leaves them.
    var offset: CGFloat = 0

    private init() {}

    /// The tallest slide and its caption, `slideHeight` at full size, fitted with `margin` either
    /// side into what's left of a strip `stripHeight` tall above `room`, and centered there. The
    /// slide rather than the whole strip above `bottomReserve`, whose bands above and below it
    /// would shrink it further. At full size, the slide and its caption sit in the middle of the
    /// strip above `bottomReserve`, where a room under the reserve leaves them.
    init(slideHeight: CGFloat, stripHeight: CGFloat, bottomReserve: CGFloat, room: CGFloat) {
        let content = stripHeight - bottomReserve
        guard room > 0, content > 0, slideHeight > 0 else {
            self = .identity
            return
        }
        let left = min(stripHeight - room, content)
        scale = min(1, max(Self.minimumScale, (left - 2 * Self.margin) / slideHeight))
        let scaledTop = (content - slideHeight) / 2 * scale
        offset = max(Self.margin, (left - slideHeight * scale) / 2) - scaledTop
    }
}
