//
//  SlideView.swift
//  Swipeset
//

import SwiftUI

/// A slide's background with `cell` in each of its cells, at whatever size it's given.
struct SlideView<CellContent: View>: View {
    let slide: Slide
    let style: SlideStyle
    @ViewBuilder let cell: (Int) -> CellContent

    var body: some View {
        SlideCells(layout: slide.layout, style: style) {
            ForEach(slide.cells.indices, id: \.self) { index in
                cell(index)
            }
        }
        .background(style.background.color)
    }
}

extension SlideView where CellContent == PlaceholderCell {
    /// The slide with every cell drawn empty, as thumbnails show it.
    init(slide: Slide, style: SlideStyle) {
        self.init(slide: slide, style: style) { _ in
            PlaceholderCell(background: style.background)
        }
    }
}

/// An empty cell's fill, dark on a light background and light on a dark one, so it shows on either.
struct PlaceholderCell: View {
    let background: RGBColor

    var body: some View {
        Rectangle()
            .fill(background.isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.16))
            .accessibilityHidden(true)
    }
}

/// Places one subview in each of `layout`'s cells, in reading order.
struct SlideCells: Layout {
    let layout: SlideLayout
    let style: SlideStyle

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = SlideGeometry.cellFrames(for: layout, in: bounds.size, style: style)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
}

nonisolated extension RGBColor {
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    /// Whether black shows up better on it than white. Past a relative luminance of about 0.18,
    /// black's contrast against it beats white's.
    var isLight: Bool {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return luminance > 0.179
    }
}

#Preview {
    SlideView(slide: Slide(layout: .twoTopOneBottom), style: .standard)
        .aspectRatio(AspectRatio.portrait.widthOverHeight, contentMode: .fit)
        .padding()
}
