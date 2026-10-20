//
//  TileSheetOpening.swift
//  Carouline
//

import SwiftUI

/// Opens a sheet of tiles taller when `.medium` can't show two rows of them whole, as on iPhone
/// Duo's screen in landscape, which is short without being compact and would cut the second row in
/// two: tall enough for two rows and a glimpse of a third, so there's plainly more to scroll to, or
/// for all of them when they end sooner. Short of `.large`, where the sheet loses its glass. Decided
/// once, as the sheet opens, so it stays at whatever height it's dragged to. Goes on the sheet's
/// scroll view, whose sheet offers `detent` among its detents.
struct TileSheetOpening: ViewModifier {
    /// The scroll view's content, where the first tile is measured, since it holds still as the
    /// content scrolls. Named on the padded grid.
    static let contentSpace = NamedCoordinateSpace.named("TileSheetOpening.content")

    @Binding var detent: PresentationDetent
    /// The first tile's frame in `contentSpace`, and the gap between rows.
    let firstTile: CGRect
    let rowSpacing: CGFloat
    @State private var fit = ScrollFit()
    @State private var isDecided = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Longer than the gap between the sheet's first layout, at full height, and the one it opens
    /// at, so it's measured where it opens.
    private static let settleDelay = Duration.milliseconds(120)

    /// How much of the scroll view's content shows clear of the safe area below it, how tall all
    /// of it is, and what the sheet takes besides: the title bar above it and that safe area.
    private struct ScrollFit: Hashable {
        var visibleHeight: CGFloat = 0
        var contentHeight: CGFloat = 0
        var top: CGFloat = 0
        var bottom: CGFloat = 0
    }

    private struct Measures: Hashable {
        let fit: ScrollFit
        let firstTile: CGRect
    }

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: ScrollFit.self) { geometry in
                ScrollFit(
                    visibleHeight: geometry.containerSize.height - geometry.contentInsets.bottom,
                    contentHeight: geometry.contentSize.height,
                    top: geometry.contentInsets.top,
                    bottom: geometry.contentInsets.bottom
                )
            } action: { _, fit in
                if !isDecided {
                    self.fit = fit
                }
            }
            .task(id: isDecided ? nil : Measures(fit: fit, firstTile: firstTile)) {
                try? await Task.sleep(for: Self.settleDelay)
                if !Task.isCancelled {
                    decide()
                }
            }
    }

    private func decide() {
        guard !isDecided, fit.visibleHeight > 0, !firstTile.isEmpty else {
            return
        }
        isDecided = true
        let secondRowBottom = firstTile.maxY + rowSpacing + firstTile.height
        // A compact height has no `.medium`, and shows the sheet full height already. Measured at
        // rest, where the content's top is the scroll view's.
        guard detent == .medium, verticalSizeClass == .regular, fit.contentHeight > fit.visibleHeight,
              secondRowBottom > fit.visibleHeight else {
            return
        }
        // The glimpse reaches into the safe area below, which the sheet's glass shows through.
        let glimpse = secondRowBottom + rowSpacing + firstTile.height / 4
        detent = .height(fit.top + min(glimpse, fit.contentHeight + fit.bottom))
    }
}
