//
//  SlideGeometryTests.swift
//  SwipesetTests
//

import CoreGraphics
import Testing
@testable import Swipeset

struct SlideGeometryTests {
    private let size = CGSize(width: 1080, height: 1350)
    private let flush = SlideStyle(spacing: 0, border: 0, background: .white)

    @Test(arguments: SlideLayout.allCases)
    func cellsTileTheSlideWithoutOverlapping(_ layout: SlideLayout) {
        let frames = SlideGeometry.cellFrames(for: layout, in: size, style: flush)
        #expect(frames.count == layout.grid.cells.count)
        let area = frames.reduce(0) { $0 + $1.width * $1.height }
        #expect(abs(area - size.width * size.height) < 0.001)
        for (index, frame) in frames.enumerated() {
            #expect(CGRect(origin: .zero, size: size).insetBy(dx: -0.001, dy: -0.001).contains(frame))
            for other in frames[(index + 1)...] {
                #expect(frame.intersection(other).width < 0.001 || frame.intersection(other).height < 0.001)
            }
        }
    }

    @Test func spacingAndBorderAreTheSameWidthEverywhere() {
        let style = SlideStyle(spacing: 0.02, border: 0.05, background: .white)
        let frames = SlideGeometry.cellFrames(for: .twoTopOneBottom, in: size, style: style)
        let gap = 0.02 * size.width
        let border = 0.05 * size.width
        #expect(abs(frames[0].minX - border) < 0.001)
        #expect(abs(frames[0].minY - border) < 0.001)
        #expect(abs(frames[1].minX - frames[0].maxX - gap) < 0.001)
        #expect(abs(frames[2].minY - frames[0].maxY - gap) < 0.001)
        #expect(abs(size.width - frames[2].maxX - border) < 0.001)
        #expect(abs(size.height - frames[2].maxY - border) < 0.001)
        #expect(abs(frames[2].width - (frames[0].width + gap + frames[1].width)) < 0.001)
    }

    @Test func snappingPutsEveryEdgeOnAWholePixel() {
        let style = SlideStyle(spacing: 0.013, border: 0.007, background: .white)
        let frames = SlideGeometry.cellFrames(for: .threeColumns, in: CGSize(width: 1080, height: 566), style: style, pixelScale: 1)
        for frame in frames {
            for edge in [frame.minX, frame.minY, frame.maxX, frame.maxY] {
                #expect(edge == edge.rounded())
            }
        }
    }

    @Test func oversizedSpacingCollapsesCellsRatherThanInvertingThem() {
        let style = SlideStyle(spacing: 0.6, border: 0, background: .white)
        let frames = SlideGeometry.cellFrames(for: .threeColumns, in: size, style: style)
        #expect(frames.allSatisfy { $0.width >= 0 && $0.height >= 0 })
    }
}
