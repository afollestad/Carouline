//
//  SlideGeometry.swift
//  Carouline
//

import CoreGraphics

/// Where a slide's cells sit, shared by the screen and the export so both lay out alike.
nonisolated enum SlideGeometry {
    /// The frames of `layout`'s cells in a slide of `size`, in reading order. A panorama's `size`
    /// covers all `span` of its slides, and the style measures from one, so its border frames
    /// the whole as thick as a single slide's. `pixelScale` rounds every edge to a whole pixel at
    /// that scale, as an export needs, so no cell's antialiased edge lets the background bleed in
    /// as a seam.
    static func cellFrames(
        for layout: SlideLayout,
        in size: CGSize,
        style: SlideStyle,
        span: Int = 1,
        pixelScale: CGFloat? = nil
    ) -> [CGRect] {
        let grid = layout.grid
        let slideWidth = size.width / CGFloat(max(1, span))
        let gap = max(0, style.spacing) * slideWidth
        let border = max(0, style.border) * slideWidth
        let trackWidth = max(0, (size.width - 2 * border - CGFloat(grid.columns - 1) * gap) / CGFloat(grid.columns))
        let trackHeight = max(0, (size.height - 2 * border - CGFloat(grid.rows - 1) * gap) / CGFloat(grid.rows))
        return grid.cells.map { span in
            let minX = border + CGFloat(span.column) * (trackWidth + gap)
            let minY = border + CGFloat(span.row) * (trackHeight + gap)
            let maxX = minX + CGFloat(span.columnSpan) * trackWidth + CGFloat(span.columnSpan - 1) * gap
            let maxY = minY + CGFloat(span.rowSpan) * trackHeight + CGFloat(span.rowSpan - 1) * gap
            guard let pixelScale, pixelScale > 0 else {
                return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            }
            func snap(_ value: CGFloat) -> CGFloat {
                (value * pixelScale).rounded() / pixelScale
            }
            return CGRect(x: snap(minX), y: snap(minY), width: snap(maxX) - snap(minX), height: snap(maxY) - snap(minY))
        }
    }
}
