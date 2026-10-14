//
//  SheetHeight.swift
//  Swipeset
//

import CoreGraphics

/// The heights a phone's layers sheet sits at, and the room each leaves the slides above it.
nonisolated enum SheetHeight: Hashable, Sendable {
    /// Just the text field, while a text layer is typed in or when the sheet is dragged down to it.
    case typing
    /// Where the sheet opens, with the slide in view and in reach above it.
    case resting
    case large

    /// The resting height on a strip `stripHeight` tall, or nil until the strip has measured
    /// itself. Half the strip, which leaves the slide the top half, as an iPad's popover leaves it
    /// at most, and never under `typingHeight`, so the two can't swap places on a short screen.
    static func restingHeight(stripHeight: CGFloat, typingHeight: CGFloat) -> CGFloat? {
        guard stripHeight > 0 else {
            return nil
        }
        return max(stripHeight / 2, typingHeight)
    }

    /// How far a settled sheet's room may be from its height, as one floating over the bottom
    /// safe area covers a little less than it.
    static let settlingSlack: CGFloat = 24

    /// The height a sheet covering `room` above a strip `stripHeight` tall is at: typing or
    /// resting within `settlingSlack` of its own height, or large once it covers nearly all the
    /// strip. Nil anywhere between, as a drag paused partway leaves it, or riding the keyboard.
    static func settled(room: CGFloat, typingHeight: CGFloat, restingHeight: CGFloat, stripHeight: CGFloat) -> SheetHeight? {
        if abs(room - typingHeight) <= settlingSlack {
            .typing
        } else if abs(room - restingHeight) <= settlingSlack {
            .resting
        } else if room >= stripHeight - settlingSlack {
            .large
        } else {
            nil
        }
    }

    /// The room a sheet whose top is at `sheetTop` covers above a strip ending at `stripBottom`,
    /// both on screen: none until the strip has measured itself, or for a sheet below it.
    static func room(stripBottom: CGFloat, sheetTop: CGFloat) -> CGFloat {
        guard stripBottom > 0 else {
            return 0
        }
        return max(0, stripBottom - sheetTop)
    }
}
