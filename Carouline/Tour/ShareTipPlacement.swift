//
//  ShareTipPlacement.swift
//  Carouline
//

import SwiftUI

/// Where the tour's Share tip sits on the screen, from where the Share button measures: under a
/// bar across the top, pointing up at the button, or beside a bar that runs down the screen's
/// side, as iPhone Duo's does, pointing across at it.
nonisolated struct ShareTipPlacement: Equatable {
    let arrowEdge: Edge
    let alignment: Alignment
    /// The tip's room from the screen's edges, its arrow's included.
    let padding: EdgeInsets

    /// The tip's inset from the screen's edges where it doesn't point at the button.
    static let inset: CGFloat = 16
    /// How close TipKit lets a tip's arrow come to its corners, measured, so a tip beside the
    /// button sits only as far above it as keeps its arrow pointing straight across.
    static let arrowCornerInset: CGFloat = 40
    /// The room between the arrow's point and the button's measured frame, which its glass
    /// reaches past.
    static let buttonGap: CGFloat = 12

    /// `button` is the Share button's frame in the screen's space, which starts at the screen's top
    /// leading corner, so a button in a bar above the screen sits above zero.
    init(button: CGRect, in size: CGSize) {
        guard button.midY >= 0 else {
            arrowEdge = .top
            alignment = .topTrailing
            padding = EdgeInsets(top: 0, leading: Self.inset, bottom: 0, trailing: Self.inset)
            return
        }
        let top = max(0, button.midY - Self.arrowCornerInset)
        if button.midX > size.width / 2 {
            arrowEdge = .trailing
            alignment = .topTrailing
            padding = EdgeInsets(top: top, leading: Self.inset, bottom: 0, trailing: max(0, size.width - button.minX + Self.buttonGap))
        } else {
            arrowEdge = .leading
            alignment = .topLeading
            padding = EdgeInsets(top: top, leading: max(0, button.maxX + Self.buttonGap), bottom: 0, trailing: Self.inset)
        }
    }
}
