//
//  StripMiddle.swift
//  Carouline
//

import SwiftUI

/// Where a view on a panorama sits to stay under the middle of the strip, which a panorama wider
/// than the screen would otherwise leave off screen at its own middle.
nonisolated enum StripMiddle {
    /// How far either way from its middle a view on a card `span` slides and `cardWidth` points
    /// wide moves: to the middles of its first and last slides, where the strip rests at its ends.
    static func reach(span: Int, cardWidth: CGFloat) -> CGFloat {
        let span = max(1, span)
        return CGFloat(span - 1) * cardWidth / CGFloat(span) / 2
    }

    /// How far a view in the middle of a container `width` wide moves to sit under `middle`, the
    /// strip's middle in the container's space, no farther than `reach` either way.
    static func shift(toward middle: CGFloat, across width: CGFloat, reach: CGFloat) -> CGFloat {
        reach > 0 ? min(max(middle - width / 2, -reach), reach) : 0
    }
}

extension View {
    /// Slides the view across its container, as wide as it's offered, to stay under the strip's
    /// middle, up to `reach` either way from the container's middle.
    func followsStripMiddle(reach: CGFloat) -> some View {
        modifier(FollowsStripMiddle(reach: reach))
    }
}

/// Moves its content with an offset rather than a visual effect, so a popover from it, a tour
/// anchor on it and its taps all follow. Its own state, so a scroll redraws no more than this.
private struct FollowsStripMiddle: ViewModifier {
    let reach: CGFloat
    @State private var shift: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: shift)
            .frame(maxWidth: .infinity)
            // Measured on the frame, which the offset inside it doesn't move.
            .onGeometryChange(for: CGFloat.self) { [reach] proxy in
                guard reach > 0, let visible = proxy.bounds(of: .scrollView) else {
                    return 0
                }
                return StripMiddle.shift(toward: visible.midX, across: proxy.size.width, reach: reach)
            } action: { shift in
                self.shift = shift
            }
    }
}
