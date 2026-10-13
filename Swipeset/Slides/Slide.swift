//
//  Slide.swift
//  Swipeset
//

import Foundation

/// One image of a carousel, split into cells by its layout.
nonisolated struct Slide: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var layout: SlideLayout
    /// One per cell of `layout`, in its reading order.
    var cells: [Cell]

    init(id: UUID = UUID(), layout: SlideLayout, cells: [Cell]? = nil) {
        self.id = id
        self.layout = layout
        self.cells = cells ?? Array(repeating: Cell(), count: layout.grid.cells.count)
    }

    /// How many cells have no photo, leaving out those in `skipping`.
    func emptyCellCount(skipping: Set<Int> = []) -> Int {
        cells.indices.count { cells[$0].image == nil && !skipping.contains($0) }
    }

    /// The cells `count` photos picked for cell `index` go in: it and the empty cells after it,
    /// wrapping round to those before it, in reading order. The photos then fill the slide top to
    /// bottom and left to right, and the cell they were picked for always gets one. A cell with a
    /// photo takes just the one that replaces it, and the other cells in `skipping` take none.
    func cellsToFill(from index: Int, count: Int, skipping: Set<Int> = []) -> [Int] {
        guard cells.indices.contains(index), count > 0 else {
            return []
        }
        guard cells[index].image == nil else {
            return [index]
        }
        let others = cells.indices.filter { $0 != index && cells[$0].image == nil && !skipping.contains($0) }
        let wrapped = others.filter { $0 > index } + others.filter { $0 < index }
        return ([index] + wrapped.prefix(count - 1)).sorted()
    }
}

/// A space in a slide's layout, empty until a photo fills it.
nonisolated struct Cell: Codable, Hashable, Sendable {
    var image: PlacedImage?

    init(image: PlacedImage? = nil) {
        self.image = image
    }
}
