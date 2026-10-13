//
//  SlideTests.swift
//  SwipesetTests
//

import Testing
@testable import Swipeset

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
}
