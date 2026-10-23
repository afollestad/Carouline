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

    @Test func findsTheFirstEmptyCell() {
        #expect(grid().firstEmptyCell() == 0)
        #expect(grid(filled: [0, 1]).firstEmptyCell() == 2)
        #expect(grid(filled: [0]).firstEmptyCell(skipping: [1, 2]) == 3)
        #expect(grid(filled: [0, 1, 2, 3]).firstEmptyCell() == nil)
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

    // MARK: Reshaping

    /// A portrait slide's export size, which every reshape here measures on.
    private let slideSize = AspectRatio.portrait.exportSize

    /// Four times as wide as it's high, which a panorama of portrait slides fits five wide.
    private func widePhoto(crop: ImageCrop = ImageCrop()) -> Cell {
        Cell(image: PlacedImage(assetIdentifier: nil, pixelWidth: 6000, pixelHeight: 1500, crop: crop))
    }

    /// A picture 216 by 108 on a slide 1080 wide, so it shows whole with its center from 0.1 to 0.9
    /// of a slide across and from 0.04 to 0.96 down.
    private func picture(at centerX: Double, _ centerY: Double = 0.5) -> Layer {
        Layer(
            content: .image(ImageLayer(image: PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 200))),
            placement: LayerPlacement(centerX: centerX, centerY: centerY, scale: 0.4)
        )
    }

    /// `old` given `layout`, `span` and `cells`, its layers kept as a layout change keeps them.
    private func reshaped(_ old: Slide, to layout: SlideLayout, span: Int? = nil, cells: [Cell]) -> Slide {
        var slide = Slide(id: old.id, layout: layout, span: span, cells: cells)
        slide.keepLayers(from: old, slideSize: slideSize)
        return slide
    }

    /// Whether `slide`'s layers have their centers at `centers`, within rounding.
    private func sits(_ slide: Slide, at centers: [(x: Double, y: Double)]) -> Bool {
        slide.layers.count == centers.count && zip(slide.layers, centers).allSatisfy { layer, center in
            abs(layer.placement.centerX - center.x) < 1e-9 && abs(layer.placement.centerY - center.y) < 1e-9
        }
    }

    /// A slide's photo spreads across the panorama it turns into, and its layers shift together with
    /// it, over the same part of it, and back as they were when it turns back.
    @Test func shiftsLayersWithAPhotoIntoAPanoramaAndBack() throws {
        let single = Slide(layout: .single, cells: [widePhoto()], layers: [picture(at: 0.5), picture(at: 0.25, 0.3)])
        let panorama = reshaped(single, to: .panorama, span: 5, cells: single.cells)

        let shift = try #require(panorama.shift(from: single, slideSize: slideSize))
        #expect(abs(shift.dx - 2) < 1e-9)
        #expect(abs(shift.dy) < 1e-9)
        #expect(sits(panorama, at: [(2.5, 0.5), (2.25, 0.3)]))
        #expect(sits(reshaped(panorama, to: .single, cells: panorama.cells), at: [(0.5, 0.5), (0.25, 0.3)]))
    }

    /// A zoomed photo shows whole in a panorama, and its layers shift as far as the part of it at
    /// the slide's middle, together, rather than each drawing in with the smaller photo.
    @Test func shiftsLayersTogetherWithAZoomedPhoto() {
        let single = Slide(layout: .single, cells: [widePhoto(crop: ImageCrop(scale: 2, centerX: 0.3))], layers: [picture(at: 0.5, 0.25)])

        #expect(sits(reshaped(single, to: .panorama, span: 5, cells: [widePhoto()]), at: [(1.5, 0.25)]))
    }

    /// Layers on a panorama's far slides, past the part of its photo a single slide shows, come in
    /// from the slide's edges until they show whole.
    @Test func bringsLayersShiftedPastTheEdgesBackInside() {
        let panorama = Slide(layout: .panorama, span: 5, cells: [widePhoto()], layers: [picture(at: 0.5), picture(at: 4.5)])

        #expect(sits(reshaped(panorama, to: .single, cells: panorama.cells), at: [(0.1, 0.5), (0.9, 0.5)]))
    }

    /// Layers over a slide of several cells are placed on the whole slide rather than its first
    /// photo, so they keep their arrangement, centered on the panorama the photo spreads across.
    @Test func centersTheLayersOfSeveralCellsOnAPanorama() {
        let grid = Slide(layout: .grid, cells: [widePhoto(), Cell(), Cell(), Cell()], layers: [picture(at: 0.5, 0.45), picture(at: 0.76, 0.78)])

        #expect(sits(reshaped(grid, to: .panorama, span: 5, cells: [widePhoto()]), at: [(2.5, 0.45), (2.76, 0.78)]))
    }

    /// With no photo, a slide's layers keep their places on a slide-shaped middle of the panorama,
    /// as a centered photo's would, and come back off it.
    @Test func centersAnEmptySlidesLayersOnAPanorama() {
        let single = Slide(layout: .single, layers: [picture(at: 0.5)])
        let wide = Slide(layout: .panorama, span: 4, layers: [picture(at: 2)])

        #expect(sits(reshaped(single, to: .panorama, cells: [Cell()]), at: [(1, 0.5)]))
        #expect(sits(reshaped(single, to: .panorama, span: 3, cells: [Cell()]), at: [(1.5, 0.5)]))
        #expect(sits(reshaped(wide, to: .single, cells: [Cell()]), at: [(0.5, 0.5)]))
    }

    /// Only a span changing moves what a slide shows sideways, so a layout keeping it, or a
    /// panorama's photo replaced, leaves layers where they are.
    @Test func shiftsNothingWhereTheSpanStays() {
        let single = Slide(layout: .single, cells: [widePhoto()], layers: [picture(at: 0.3)])
        let grid = reshaped(single, to: .grid, cells: [widePhoto(), Cell(), Cell(), Cell()])
        let panorama = Slide(layout: .panorama, span: 5, cells: [widePhoto()])
        var replaced = panorama
        replaced.cells[0].image = PlacedImage(assetIdentifier: nil, pixelWidth: 3000, pixelHeight: 1000)

        #expect(grid.shift(from: single, slideSize: slideSize) == nil)
        #expect(grid.layers == single.layers)
        #expect(replaced.shift(from: panorama, slideSize: slideSize) == nil)
    }
}
