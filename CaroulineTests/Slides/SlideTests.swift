//
//  SlideTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

struct SlideTests {
    /// A grid of four with photos in the cells at `filled`.
    private func grid(filled: Set<Int> = []) -> Slide {
        let cells = (0..<4).map { index in
            Cell(image: filled.contains(index) ? PlacedImage(assetIdentifier: nil, pixelWidth: 100, pixelHeight: 100) : nil)
        }
        return Slide(layout: .grid, cells: cells)
    }

    @Test func countsEmptyCells() {
        #expect(grid().emptyCellCount() == 4)
        #expect(grid(filled: [0, 2]).emptyCellCount() == 2)
        #expect(grid(filled: [0]).emptyCellCount(skipping: [1]) == 2)
    }

    /// Photos picked for cell `from` of a grid with photos at `filled`, and the cells they fill.
    struct Fill: Sendable, CustomTestStringConvertible {
        let filled: Set<Int>
        let from: Int
        let count: Int
        let cells: [Int]

        var testDescription: String {
            "\(count) for cell \(from) with \(filled.sorted()) filled"
        }
    }

    @Test(arguments: [
        // A pick for every empty cell fills them in reading order, whichever was tapped.
        Fill(filled: [], from: 2, count: 4, cells: [0, 1, 2, 3]),
        // Fewer start at the tapped cell and run on to the empty ones after it.
        Fill(filled: [], from: 1, count: 2, cells: [1, 2]),
        // Past the last cell they wrap round to the first.
        Fill(filled: [], from: 3, count: 2, cells: [0, 3]),
        Fill(filled: [1], from: 0, count: 3, cells: [0, 2, 3]),
        // More photos than empty cells fill only the empty cells.
        Fill(filled: [0, 3], from: 1, count: 4, cells: [1, 2]),
        // A cell with a photo takes just its replacement.
        Fill(filled: [2], from: 2, count: 3, cells: [2])
    ])
    func fillsCellsFromTheTappedOneInReadingOrder(_ fill: Fill) {
        #expect(grid(filled: fill.filled).cellsToFill(from: fill.from, count: fill.count) == fill.cells)
    }

    @Test func passesOverSkippedCells() {
        #expect(grid().cellsToFill(from: 0, count: 3, skipping: [1]) == [0, 2, 3])
    }

    @Test func fillsNothingForACellThatIsGone() {
        #expect(grid().cellsToFill(from: 4, count: 1).isEmpty)
        #expect(grid().cellsToFill(from: 0, count: 0).isEmpty)
    }

    @Test func spansOnlyAPanoramaAcrossSlides() {
        let panorama = Slide(layout: .panorama)
        #expect(panorama.span == Slide.defaultPanoramaSpan)
        #expect(panorama.cells.count == 1)
        #expect(Slide(layout: .panorama, span: 1).span == 2)
        #expect(Slide(layout: .panorama, span: 40).span == 10)
        #expect(Slide(layout: .grid, span: 3).span == 1)
    }

    /// A photo of `width` by `height` across slides of `aspectRatio`, and the span that fits it.
    struct Fit: Sendable, CustomTestStringConvertible {
        let width: Int
        let height: Int
        let aspectRatio: AspectRatio
        let span: Int

        var testDescription: String {
            "\(width) by \(height) on \(aspectRatio.spokenRatio)"
        }
    }

    @Test(arguments: [
        Fit(width: 4000, height: 1000, aspectRatio: .portrait, span: 5),
        Fit(width: 3000, height: 1000, aspectRatio: .square, span: 3),
        Fit(width: 1920, height: 1080, aspectRatio: .portrait, span: 2),
        // Halfway between two spans rounds up.
        Fit(width: 2000, height: 1000, aspectRatio: .portrait, span: 3),
        Fit(width: 4000, height: 1000, aspectRatio: .landscape, span: 2),
        // Too narrow or too wide for a panorama, clamped to the spans there are.
        Fit(width: 1000, height: 1000, aspectRatio: .portrait, span: 2),
        Fit(width: 12000, height: 1000, aspectRatio: .story, span: 10)
    ])
    func fitsAPanoramaToItsPhoto(_ fit: Fit) {
        #expect(Slide.panoramaSpan(fitting: CGSize(width: fit.width, height: fit.height), in: fit.aspectRatio) == fit.span)
    }

    /// Version 1 to 3 slides have no style of their own, which `ProjectFile` gives them from
    /// their project's.
    @Test func readsAMissingStyleAsTheStandardOne() throws {
        let json = #"{"id": "6A1F2B3C-0000-4000-8000-000000000002", "layout": "single", "cells": [{}]}"#
        let slide = try JSONDecoder().decode(Slide.self, from: Data(json.utf8))
        #expect(slide.style == .standard)
    }
}
