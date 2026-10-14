//
//  SlideView.swift
//  Carouline
//

import SwiftUI

/// A slide's background with `cell` in each of its cells, at whatever size it's given.
struct SlideView<CellContent: View>: View {
    let slide: Slide
    let style: SlideStyle
    /// Whether empty cells show what's behind the slide rather than its background, for the
    /// strip's glass to frost.
    var revealsEmptyCells = false
    @ViewBuilder let cell: (Int) -> CellContent

    var body: some View {
        SlideCells(layout: slide.layout, style: style, span: slide.span) {
            ForEach(slide.cells.indices, id: \.self) { index in
                cell(index)
            }
        }
        .background {
            SlideBackground(
                layout: slide.layout,
                style: style,
                span: slide.span,
                holes: revealsEmptyCells ? slide.cells.indices.filter { slide.cells[$0].image == nil } : []
            )
            .fill(style.background.color, style: FillStyle(eoFill: true))
        }
    }
}

/// A slide's background less the cells at `holes`, which show what's behind the slide.
struct SlideBackground: Shape {
    let layout: SlideLayout
    let style: SlideStyle
    let span: Int
    let holes: [Int]

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        let frames = SlideGeometry.cellFrames(for: layout, in: rect.size, style: style, span: span)
        for index in holes where frames.indices.contains(index) {
            path.addRect(frames[index].offsetBy(dx: rect.minX, dy: rect.minY))
        }
        return path
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

/// A cell's fill where no photo shows, as in an empty cell's thumbnail or behind a missing photo:
/// dark gray in dark mode, so it doesn't glare on the dark screen, and otherwise dark on a light
/// background and light on a dark one, so it shows on either. While `isLoading` it pulses, over
/// black in dark mode, so it only ever dims there rather than letting the slide glare through.
struct PlaceholderCell: View {
    let background: RGBColor
    /// Whether it stands in for a photo still loading.
    var isLoading = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if isLoading {
            fillShape
                .loadingPulse()
                .background(colorScheme == .dark ? Color.black : Color.clear)
        } else {
            fillShape
        }
    }

    private var fillShape: some View {
        Rectangle()
            .fill(fill)
            .accessibilityHidden(true)
    }

    private var fill: Color {
        if colorScheme == .dark {
            Color(.systemGray5)
        } else if background.isLight {
            Color.black.opacity(0.08)
        } else {
            Color.white.opacity(0.16)
        }
    }

    /// Whether the fill on `background` reads as light in `colorScheme`, for glass over it to match.
    static func isLight(on background: RGBColor, in colorScheme: ColorScheme) -> Bool {
        colorScheme != .dark && background.isLight
    }
}

/// Places one subview in each of `layout`'s cells, in reading order, across `span` slides.
struct SlideCells: Layout {
    let layout: SlideLayout
    let style: SlideStyle
    var span = 1

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = SlideGeometry.cellFrames(for: layout, in: bounds.size, style: style, span: span)
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
