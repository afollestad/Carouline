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
}

/// A space in a slide's layout, empty until a photo fills it.
nonisolated struct Cell: Codable, Hashable, Sendable {
    var image: PlacedImage?

    init(image: PlacedImage? = nil) {
        self.image = image
    }
}
