//
//  SheetHeight.swift
//  Carouline
//

import CoreGraphics

/// The heights the layers sheet sits at, and the room each leaves the slides above it.
nonisolated enum SheetHeight: Hashable, Sendable {
    /// Just the text field, while a text layer is typed in or when the sheet is dragged down to it.
    case typing
    /// Where the sheet opens, with the slide in view and in reach above it.
    case resting
    case large

    /// The resting height's most: the title bar over the text editor's field and its row of
    /// typefaces, or over two layers' rows. Any taller only covers the slides, as half the strip
    /// did on an iPad in portrait, at over 500.
    static let restingCap: CGFloat = 320
    /// The share of a strip too short for `restingCap`, which keeps a small phone's sheet under
    /// half of it, so the slides keep the most room.
    static let restingShare: CGFloat = 0.45

    /// The resting height on a strip `stripHeight` tall, or nil until the strip has measured
    /// itself. `restingShare` of the strip, up to `restingCap`, and never under `typingHeight`, so
    /// the two can't swap places on a short screen.
    static func restingHeight(stripHeight: CGFloat, typingHeight: CGFloat) -> CGFloat? {
        guard stripHeight > 0 else {
            return nil
        }
        return max(min(stripHeight * restingShare, restingCap), typingHeight)
    }

    /// How far the room of a sheet resting at a height may be from that height, as one floating
    /// over the bottom safe area covers a little more or less than it.
    static let settlingSlack: CGFloat = 24

    /// The room a sheet whose top is at `sheetTop` covers above a strip ending at `stripBottom`,
    /// both on screen: none until the strip has measured itself, or for a sheet below it.
    static func room(stripBottom: CGFloat, sheetTop: CGFloat) -> CGFloat {
        guard stripBottom > 0 else {
            return 0
        }
        return max(0, stripBottom - sheetTop)
    }
}
