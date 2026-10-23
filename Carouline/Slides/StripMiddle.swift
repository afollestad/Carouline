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

    /// How far either way from its container's middle a view `width` wide moves and still stays
    /// inside a container `containerWidth` wide.
    static func room(for width: CGFloat, in containerWidth: CGFloat) -> CGFloat {
        max(0, (containerWidth - width) / 2)
    }

    /// Which of the `span` slides across a card `width` wide is at `x`, or nil off the card.
    static func slideIndex(at x: CGFloat, across width: CGFloat, span: Int) -> Int? {
        guard width > 0, x >= 0, x < width else {
            return nil
        }
        let span = max(1, span)
        return min(span - 1, Int(x / (width / CGFloat(span))))
    }
}

extension View {
    /// Slides the view across its container, as wide as it's offered, to stay under the strip's
    /// middle, up to `reach` either way from the container's middle, and never past its edges.
    func followsStripMiddle(reach: CGFloat) -> some View {
        modifier(FollowsStripMiddle(reach: reach))
    }

    /// Tells `session` which of panorama `slideID`'s `span` slides, laid out across the view, is
    /// in the middle of the strip, while one is.
    func reportsPanoramaFront(_ slideID: UUID, span: Int, to session: LayerSession) -> some View {
        modifier(ReportsPanoramaFront(slideID: slideID, span: span, session: session))
    }

    /// Tells `session` where in a panorama's selected cell, laid out across the view, its zoom
    /// slider zooms about: under the strip's middle, as far as `reach` either way from the cell's.
    func reportsZoomAnchor(isSelected: Bool, reach: CGFloat, to session: CropSession) -> some View {
        modifier(ReportsZoomAnchor(isSelected: isSelected, reach: reach, session: session))
    }
}

/// Measured on every slide, but changing only as the strip's middle crosses a panorama's cut, or
/// leaves it.
private struct ReportsPanoramaFront: ViewModifier {
    let slideID: UUID
    let span: Int
    let session: LayerSession

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: Int?.self) { [span] proxy in
                guard span > 1, let visible = proxy.bounds(of: .scrollView) else {
                    return nil
                }
                return StripMiddle.slideIndex(at: visible.midX, across: proxy.size.width, span: span)
            } action: { index in
                if let index {
                    session.panoramaFront = PanoramaFront(slideID: slideID, index: index)
                } else {
                    clear()
                }
            }
            .onDisappear(perform: clear)
    }

    /// Forgets the front, unless another panorama has taken it.
    private func clear() {
        if session.panoramaFront?.slideID == slideID {
            session.panoramaFront = nil
        }
    }
}

/// Measured on a panorama's cell alone, and kept for a selection made while the strip holds still,
/// which measures nothing new. A new selection clears the session's, so a cell no longer selected
/// can't clear the next one's.
private struct ReportsZoomAnchor: ViewModifier {
    let isSelected: Bool
    let reach: CGFloat
    let session: CropSession
    @State private var measured = MeasuredAnchor()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat?.self) { [reach] proxy in
                guard reach > 0, let visible = proxy.bounds(of: .scrollView) else {
                    return nil
                }
                return proxy.size.width / 2 + StripMiddle.shift(toward: visible.midX, across: proxy.size.width, reach: reach)
            } action: { anchor in
                measured.x = anchor
                if isSelected, let anchor {
                    session.zoomAnchorX = anchor
                }
            }
            .onChange(of: isSelected, initial: true) { _, isSelected in
                if isSelected, let anchor = measured.x {
                    session.zoomAnchorX = anchor
                }
            }
    }
}

/// Where the zoom anchor was last measured, which a scroll writes every frame, so it redraws nothing.
private final class MeasuredAnchor {
    var x: CGFloat?
}

/// Moves its content with an offset rather than a visual effect, so a popover from it, a tour
/// anchor on it and its taps all follow. Its own state, so a scroll redraws no more than this.
/// Kept inside its container, so a caption wider than a panorama's slide stops at the panorama's
/// end, rather than running over the next slide's caption under the end slide's middle.
private struct FollowsStripMiddle: ViewModifier {
    let reach: CGFloat
    @State private var shift: CGFloat = 0
    /// The content's width and its container's, which keep it inside. Held as state rather than
    /// taken into the shift's measurement, so the shift holds to them as soon as both are measured.
    @State private var width: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    func body(content: Content) -> some View {
        let room = StripMiddle.room(for: width, in: containerWidth)
        content
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
            .offset(x: min(max(shift, -room), room))
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { containerWidth = $0 }
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
