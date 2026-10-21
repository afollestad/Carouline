//
//  SlideCard+Tour.swift
//  Carouline
//

import SwiftUI
import TipKit

/// The tour's tips' room from the slide's sides, and their widest, which keeps one to a phone's
/// width over an iPad's slide.
private let tipInset: CGFloat = 12
private let tipMaxWidth: CGFloat = 400
/// The tips' narrowest, past a narrow card's sides, as a phone's in landscape is: wide enough for
/// a caption tip's arrow, which TipKit keeps `ShareTipPlacement.arrowCornerInset` from its
/// corners, to reach the buttons either side of the caption.
private let tipMinWidth: CGFloat = 280

extension SlideCard {
    /// The tour's tips over the slide in front, pointing at a photo to frame or its top layer.
    /// Inline rather than popovers, as all the tour's tips are, since TipKit leaves a popover tip on
    /// screen while a sheet opens, after which the strip presents no popover again.
    @ViewBuilder
    var tourTips: some View {
        if let tour {
            if let tip = tour.photoTip(on: slide.id), let target = TourTargets.photoTarget(on: slide, canvas: canvas) {
                pointingTip(tip, at: target, anchor: tour.anchor(.photo))
            } else if let tip = tour.layerTip(on: slide.id), let layer = slide.layers.last {
                pointingTip(tip, at: LayerGeometry.frame(of: layer, canvas: size, span: slide.span), anchor: tour.anchor(.layer))
            }
        }
    }

    /// The tour's tip about one of the buttons under the slide in front, over the slide and its
    /// caption, along the slide's foot, its arrow reaching down across to the button `targets`
    /// finds.
    @ViewBuilder
    func captionTip(at targets: [TourAnchor.Target: Anchor<CGRect>]) -> some View {
        if let tour, let caption = tour.captionTip(on: slide.id), let bounds = targets[caption.target] {
            GeometryReader { proxy in
                let anchor = tour.anchor(caption.target)
                ZStack(alignment: .bottom) {
                    anchor.standIn(at: proxy[bounds])
                    TipView(caption.tip, arrowEdge: .bottom, anchorID: anchor)
                        .modifier(SlideTipSize())
                        .padding([.horizontal, .top], tipInset)
                        .padding(.bottom, Self.captionHeight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                // Growing past a narrow slide evenly either side, and past a short one upward, with
                // its stand-in still over the button.
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            }
        }
    }

    private var canvas: LayerCanvas {
        LayerCanvas(size: size, span: slide.span, screenPoint: screenPoint)
    }

    /// `tip` pointing at `target`, in the slide's space: below it when it's in the slide's upper
    /// half, and above it otherwise, where there's more room, so it never covers what it asks the
    /// user to tap.
    private func pointingTip(_ tip: any Tip, at target: CGRect, anchor: TourAnchor) -> some View {
        let isBelow = target.midY <= size.height / 2
        let alignment: Alignment = isBelow ? .top : .bottom
        return ZStack(alignment: alignment) {
            anchor.standIn(at: target)
            TipView(tip, arrowEdge: isBelow ? .top : .bottom, anchorID: anchor)
                .modifier(SlideTipSize())
                .padding(.horizontal, tipInset)
                .padding(isBelow ? .top : .bottom, isBelow ? target.maxY : size.height - target.minY)
                .frame(maxHeight: .infinity, alignment: alignment)
        }
        // Growing past a short slide away from what it points at, with its stand-in still over it.
        .frame(width: size.width, height: size.height, alignment: alignment)
    }
}

/// A tip over a slide, at its own height, which grows past a short slide, as a wide project's or
/// a phone's in landscape is, rather than squeezing its text.
private struct SlideTipSize: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tourTipStyle()
            .frame(minWidth: tipMinWidth, maxWidth: tipMaxWidth)
            .fixedSize(horizontal: false, vertical: true)
    }
}
