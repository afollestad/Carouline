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

    /// The title bar's buttons' height. A phone's bar sets them one margin below the sheet's top, as
    /// far as it sets them in from its sides, and an iPad's nearer, leaving its sheet a little to
    /// spare.
    static let titleBarButtonHeight: CGFloat = 44
    /// How far the title bar reaches below its buttons, measured, since no API exposes it.
    static let titleBarBelowButtons: CGFloat = 10
    /// The text editor's field through its row of typefaces, at the default text size: the most
    /// the sheet shows whole at rest, more than two layers' rows or an empty slide's tiles.
    static let restingContent: CGFloat = 197
    /// The share of a strip too short for `restingCap(margin:)`, which keeps a small phone's sheet
    /// under half of it, so the slides keep the most room.
    static let restingShare: CGFloat = 0.45

    /// The gap from the title bar's buttons to a page's content: `margin`, the sheet's layout
    /// margin, as far below them as the content is in from the sides, unless the bar reaches
    /// further.
    static func topGap(margin: CGFloat) -> CGFloat {
        max(margin, titleBarBelowButtons)
    }

    /// Where a page's content starts below the sheet's top, under the title bar's buttons.
    static func contentTop(margin: CGFloat) -> CGFloat {
        margin + titleBarButtonHeight + topGap(margin: margin)
    }

    /// The resting height's most: the text editor's field and its row of typefaces, with a margin
    /// under them. Any taller only covers the slides, as half the strip did on an iPad in
    /// portrait, at over 500.
    static func restingCap(margin: CGFloat) -> CGFloat {
        contentTop(margin: margin) + restingContent + margin
    }

    /// The resting height on a strip `stripHeight` tall, or nil until the strip has measured
    /// itself. `restingShare` of the strip, up to `restingCap(margin:)`, and never under
    /// `typingHeight`, so the two can't swap places on a short screen.
    static func restingHeight(stripHeight: CGFloat, typingHeight: CGFloat, margin: CGFloat) -> CGFloat? {
        guard stripHeight > 0 else {
            return nil
        }
        return max(min(stripHeight * restingShare, restingCap(margin: margin)), typingHeight)
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
