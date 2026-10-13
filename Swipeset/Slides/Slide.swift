//
//  Slide.swift
//  Swipeset
//

import Foundation

/// One image of a carousel, split into cells by its layout, or, as a panorama, one photo cut
/// across several images side by side, with any layers drawn over it.
nonisolated struct Slide: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var layout: SlideLayout
    /// How many carousel images the slide posts as: `panoramaSpans` for a panorama, and 1 for
    /// every other layout. Unrelated to a `LayoutGrid.Span`, which places a cell in its grid.
    var span: Int
    /// One per cell of `layout`, in its reading order.
    var cells: [Cell]
    /// Drawn over the cells, bottom to top.
    var layers: [Layer]
    /// How blurred the cells' photos are, as a fraction of one slide's width, so the same blur
    /// shows on screen and in an export.
    var blur: Double

    /// Two is the least that reads as one photo swiped across, and ten, half of Instagram's
    /// twenty, keeps a panorama's export within 10,800 pixels and leaves room for other slides.
    static let panoramaSpans = 2...10
    /// Before a photo there's nothing to fit to, and three reads as a panorama without making
    /// the card a sliver.
    static let defaultPanoramaSpan = 3
    /// A twentieth of a slide's width blurs its photos past recognition, into a backdrop for
    /// the layers over them.
    static let maximumBlur = 0.05

    /// `span` defaults to `defaultPanoramaSpan` for a panorama, and is 1 for any other layout.
    /// `layers` are kept on the slide its span makes.
    init(
        id: UUID = UUID(),
        layout: SlideLayout,
        span: Int? = nil,
        cells: [Cell]? = nil,
        layers: [Layer] = [],
        blur: Double = 0
    ) {
        self.id = id
        self.layout = layout
        let span = layout == .panorama ? Self.clampedPanoramaSpan(span ?? Self.defaultPanoramaSpan) : 1
        self.span = span
        self.cells = cells ?? Array(repeating: Cell(), count: layout.grid.cells.count)
        self.layers = layers.map { $0.clamped(span: span) }
        self.blur = blur
    }

    /// Reads a missing `span` as 1, since version 1 files predate panoramas, and missing layers
    /// and blur as none, since version 2 files predate them. A span its layout can't have is
    /// left for `ProjectFile` to refuse, rather than clamped into another shape.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        layout = try container.decode(SlideLayout.self, forKey: .layout)
        span = try container.decodeIfPresent(Int.self, forKey: .span) ?? 1
        cells = try container.decode([Cell].self, forKey: .cells)
        layers = try container.decodeIfPresent([Layer].self, forKey: .layers) ?? []
        blur = try container.decodeIfPresent(Double.self, forKey: .blur) ?? 0
    }

    /// Leaves out layers and blur a slide doesn't have, so a slide without them saves as it did
    /// before they existed.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(layout, forKey: .layout)
        try container.encode(span, forKey: .span)
        try container.encode(cells, forKey: .cells)
        if !layers.isEmpty {
            try container.encode(layers, forKey: .layers)
        }
        if blur != 0 {
            try container.encode(blur, forKey: .blur)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case layout
        case span
        case cells
        case layers
        case blur
    }

    /// Every image the slide holds, in its cells and its layers.
    var images: [PlacedImage] {
        cells.compactMap(\.image) + layers.compactMap(\.image)
    }

    /// Spreads a panorama across `span` slides, within `panoramaSpans`, and keeps its layers on
    /// it: one past a narrower span's end moves onto the last slide.
    mutating func setSpan(_ span: Int) {
        guard layout == .panorama else {
            return
        }
        self.span = Self.clampedPanoramaSpan(span)
        layers = layers.map { $0.clamped(span: self.span) }
    }

    /// The span that shows all of a photo of `imageSize` across slides of `aspectRatio` at its
    /// full height. Rounding to the nearest whole slide crops the least either way.
    static func panoramaSpan(fitting imageSize: CGSize, in aspectRatio: AspectRatio) -> Int {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return defaultPanoramaSpan
        }
        let slides = imageSize.width / imageSize.height / aspectRatio.widthOverHeight
        return clampedPanoramaSpan(Int(slides.rounded()))
    }

    static func clampedPanoramaSpan(_ span: Int) -> Int {
        min(max(span, panoramaSpans.lowerBound), panoramaSpans.upperBound)
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
