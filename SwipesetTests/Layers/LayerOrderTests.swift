//
//  LayerOrderTests.swift
//  SwipesetTests
//

import Foundation
import Testing
@testable import Swipeset

struct LayerOrderTests {
    private let bottom = UUID()
    private let middle = UUID()
    private let top = UUID()

    /// The list shows the top layer first, so dragging its first row to the end sends that
    /// layer to the bottom of the stack.
    @Test func mapsAMoveInTheListToTheStack() {
        let shown = [top, middle, bottom]

        #expect(LayerOrder.reordered(topFirst: shown, fromOffsets: [0], toOffset: 3) == [top, bottom, middle])
        #expect(LayerOrder.reordered(topFirst: shown, fromOffsets: [2], toOffset: 0) == [middle, top, bottom])
        #expect(LayerOrder.reordered(topFirst: shown, fromOffsets: [1], toOffset: 1) == [bottom, middle, top])
    }

    @Test func mapsSwipedRowsToTheirLayers() {
        let shown = [top, middle, bottom]

        #expect(LayerOrder.ids(topFirst: shown, at: [0]) == [top])
        #expect(LayerOrder.ids(topFirst: shown, at: [1, 2]) == [middle, bottom])
        #expect(LayerOrder.ids(topFirst: shown, at: [5]).isEmpty)
    }
}
