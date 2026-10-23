//
//  SelectionHitTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

struct SelectionHitTests {
    private let canvas = LayerCanvas(size: CGSize(width: 400, height: 500), span: 1)
    private let flush = SlideStyle(spacing: 0, border: 0, background: .white)

    @Test func findsAPointInItsCell() {
        let slide = Slide(layout: .twoColumns)

        #expect(SelectionHit.cellPoint(CGPoint(x: 250, y: 100), cell: 1, of: slide, style: flush, on: canvas) == CGPoint(x: 50, y: 100))
        #expect(SelectionHit.cellPoint(CGPoint(x: 100, y: 100), cell: 1, of: slide, style: flush, on: canvas) == nil)
    }

    /// The gap between cells and the border around them belong to no cell.
    @Test func missesTheSpacingAndBorder() {
        let spaced = SlideStyle(spacing: 0.05, border: 0.05, background: .white)
        let slide = Slide(layout: .twoColumns)

        // Cells run from 20 to 190 and from 210 to 380 across.
        #expect(SelectionHit.cellPoint(CGPoint(x: 200, y: 100), cell: 1, of: slide, style: spaced, on: canvas) == nil)
        #expect(SelectionHit.cellPoint(CGPoint(x: 10, y: 100), cell: 0, of: slide, style: spaced, on: canvas) == nil)
        #expect(SelectionHit.cellPoint(CGPoint(x: 30, y: 30), cell: 0, of: slide, style: spaced, on: canvas) == CGPoint(x: 10, y: 10))
    }

    /// A drop over the gap between cells goes to neither, and one within a cell to that one.
    @Test func findsTheCellUnderADrop() {
        let spaced = SlideStyle(spacing: 0.05, border: 0.05, background: .white)
        let slide = Slide(layout: .twoColumns)

        #expect(SelectionHit.cell(at: CGPoint(x: 100, y: 100), of: slide, style: spaced, on: canvas) == 0)
        #expect(SelectionHit.cell(at: CGPoint(x: 300, y: 400), of: slide, style: spaced, on: canvas) == 1)
        #expect(SelectionHit.cell(at: CGPoint(x: 200, y: 100), of: slide, style: spaced, on: canvas) == nil)
        #expect(SelectionHit.cell(at: CGPoint(x: 5, y: 100), of: slide, style: spaced, on: canvas) == nil)
    }

    @Test func spansAPanoramasSlides() {
        let panorama = LayerCanvas(size: CGSize(width: 900, height: 400), span: 3)
        let slide = Slide(layout: .panorama, span: 3)

        #expect(SelectionHit.cellPoint(CGPoint(x: 850, y: 200), cell: 0, of: slide, style: flush, on: panorama) == CGPoint(x: 850, y: 200))
    }

    /// A cell thinner than a fingertip takes a drag across one, which grows with the canvas's
    /// points on screen while the slides are scaled down.
    @Test func reachesAFingertipPastAThinCell() {
        let slide = Slide(layout: .panorama, span: 5)
        let thin = LayerCanvas(size: CGSize(width: 1000, height: 30), span: 5)
        let scaled = LayerCanvas(size: thin.size, span: 5, screenPoint: 2)

        // 30 points tall grows 7 either way to 44.
        #expect(SelectionHit.cellPoint(CGPoint(x: 500, y: 35), cell: 0, of: slide, style: flush, on: thin) == CGPoint(x: 500, y: 35))
        #expect(SelectionHit.cellPoint(CGPoint(x: 500, y: 40), cell: 0, of: slide, style: flush, on: thin) == nil)
        #expect(SelectionHit.cellPoint(CGPoint(x: 500, y: 50), cell: 0, of: slide, style: flush, on: scaled) == CGPoint(x: 500, y: 50))
    }
}
