//
//  SampleProjects.swift
//  Carouline
//

import Foundation

/// Projects with something in them, for previews, the debug sample store and a fresh install's
/// first launch. Their photos are `SampleImages`, which `MockImageLoader` draws, and
/// `SampleStore` and `ProjectStore.addSample(_:)` write out.
nonisolated enum SampleProjects {
    static var all: [Project] {
        [
            Project(
                id: sampleID(1),
                name: "Lisbon",
                aspectRatio: .portrait,
                slides: [
                    Slide(id: sampleID(11), layout: .single, cells: [photo(101, 2048, 2730)], layers: [title(201, "Lisbon", scale: 1.4)]),
                    Slide(id: sampleID(12), layout: .twoColumns, cells: [photo(102, 2048, 1536), Cell()]),
                    Slide(
                        id: sampleID(13),
                        layout: .grid,
                        cells: [
                            photo(103, 2048, 2048),
                            photo(104, 1536, 2048, assetIdentifier: "5E7A5E70-0000-4000-8000-000000000104/L0/001"),
                            photo(105, 2048, 1365),
                            Cell()
                        ],
                        layers: [framedPhoto(202, image: 107), sticker(203, image: 108)]
                    ),
                    Slide(id: sampleID(14), layout: .panorama, span: 5, cells: [photo(106, 4096, 1024)], layers: [swipeHint(204)])
                ],
                createdAt: date(daysAgo: 3)
            ),
            Project(
                id: sampleID(2),
                name: "Story Ideas",
                aspectRatio: .story,
                slides: [
                    Slide(id: sampleID(21), layout: .threeRows, cells: [photo(201, 2048, 1365), Cell(), photo(202, 2048, 1536)]),
                    // Empty, to fill with a wide photo and watch it fit.
                    Slide(id: sampleID(22), layout: .panorama)
                ],
                createdAt: date(daysAgo: 5)
            ),
            Project(id: sampleID(3), name: "Coastline", aspectRatio: .landscape, createdAt: date(daysAgo: 8))
        ]
    }

    /// What a fresh install's first launch adds to its projects: a slide of each kind, every
    /// cell filled, under each kind of layer, so a new user sees a finished carousel. Its photos
    /// have no library original. Image IDs pick `SampleImages`' palettes, so neighbors differ,
    /// and the panorama's isn't one that fades to the swipe hint's violet.
    static var firstLaunch: Project {
        Project(
            id: firstLaunchID,
            name: "Sample Carousel",
            aspectRatio: .portrait,
            slides: [
                Slide(id: sampleID(41), layout: .single, cells: [photo(401, 2048, 2730)], layers: [title(411, "Sample Carousel", scale: 1.2)]),
                Slide(id: sampleID(42), layout: .twoColumns, cells: [photo(403, 2048, 1536), photo(404, 1536, 2048)]),
                Slide(
                    id: sampleID(43),
                    layout: .grid,
                    cells: [photo(405, 2048, 2048), photo(408, 2048, 1536), photo(407, 2048, 1365), photo(406, 1536, 2048)],
                    layers: [framedPhoto(412, image: 409), sticker(413, image: 410)]
                ),
                // A 5-slide portrait panorama's export size, so the export never enlarges it.
                Slide(id: sampleID(44), layout: .panorama, span: 5, cells: [photo(402, 5400, 1350)], layers: [swipeHint(414)])
            ],
            createdAt: date(daysAgo: 0)
        )
    }

    /// `firstLaunch`'s, which its tour runs on.
    static let firstLaunchID = sampleID(4)

    /// The photo `-DebugMissingImages` leaves without a copy, which names a library original
    /// that doesn't exist, so restoring it shows how a missing original reads, and the sticker.
    static let missingImageIDs: Set<UUID> = [sampleID(104), sampleID(108)]

    /// A title along the top of the first slide, lifted off the photo by a shadow.
    private static func title(_ number: UInt16, _ text: String, scale: Double) -> Layer {
        Layer(
            id: sampleID(number),
            content: .text(TextLayer(text: text, font: .serif, hasShadow: true)),
            placement: LayerPlacement(centerY: 0.14, scale: scale)
        )
    }

    /// A framed photo turned a little over the grid, as a print laid on the others, lifted off
    /// them by a shadow.
    private static func framedPhoto(_ number: UInt16, image: UInt16) -> Layer {
        Layer(
            id: sampleID(number),
            content: .image(ImageLayer(
                image: PlacedImage(id: sampleID(image), assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 1536),
                borderWidth: 0.04,
                hasShadow: true
            )),
            placement: LayerPlacement(centerY: 0.45, scale: 1.2, rotation: -0.08)
        )
    }

    /// A sticker cut out of its background, outlined as a die-cut one is, in the grid's lower
    /// trailing corner.
    private static func sticker(_ number: UInt16, image: UInt16) -> Layer {
        Layer(
            id: sampleID(number),
            content: .image(ImageLayer(
                image: PlacedImage(id: sampleID(image), assetIdentifier: nil, pixelWidth: 600, pixelHeight: 600, fileFormat: .png),
                borderWidth: 0.05
            )),
            placement: LayerPlacement(centerX: 0.76, centerY: 0.78, scale: 0.6)
        )
    }

    /// Highlighted text across the panorama's first cut, which the carousel splits between slides.
    private static func swipeHint(_ number: UInt16) -> Layer {
        Layer(
            id: sampleID(number),
            content: .text(TextLayer(text: "Swipe →", font: .rounded, color: RGBColor(red: 0.47, green: 0.34, blue: 0.91), isHighlighted: true)),
            placement: LayerPlacement(centerX: 1, centerY: 0.82, rotation: -0.05)
        )
    }

    /// IDs that stay the same between launches, so a debug launch argument can name a project.
    static func sampleID(_ number: UInt16) -> UUID {
        UUID(uuid: (0x5E, 0x7A, 0x5E, 0x70, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, UInt8(number >> 8), UInt8(number & 0xFF)))
    }

    private static func photo(_ number: UInt16, _ width: Int, _ height: Int, assetIdentifier: String? = nil) -> Cell {
        Cell(image: PlacedImage(id: sampleID(number), assetIdentifier: assetIdentifier, pixelWidth: width, pixelHeight: height))
    }

    private static func date(daysAgo: Double) -> Date {
        Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 - daysAgo * 86_400).rounded())
    }
}
