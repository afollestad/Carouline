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

    /// How far the room of a sheet resting at a height may be from that height, as one floating
    /// over the bottom safe area covers a little less than it.
    static let settlingSlack: CGFloat = 24

    /// Whether a sheet covering `room` above a strip `stripHeight` tall rests at `height`: within
    /// `settlingSlack` of the typing or resting height's own, or, at large, covering nearly all the
    /// strip. Not partway between, as a finger held still mid-drag leaves it. Asked of the height
    /// selected, so a resting height within reach of the typing one still rests.
    static func rests(at height: SheetHeight, room: CGFloat, typingHeight: CGFloat, restingHeight: CGFloat, stripHeight: CGFloat) -> Bool {
        switch height {
        case .typing: abs(room - typingHeight) <= settlingSlack
        case .resting: abs(room - restingHeight) <= settlingSlack
        case .large: room >= stripHeight - settlingSlack
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
