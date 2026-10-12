//
//  SampleProjects.swift
//  Swipeset
//

import Foundation

/// Projects with something in them, for previews and the debug sample store. Their photos are
/// `SampleImages`, which `MockImageLoader` draws and `SampleStore` writes out.
nonisolated enum SampleProjects {
    static var all: [Project] {
        [
            Project(
                id: sampleID(1),
                name: "Lisbon",
                aspectRatio: .portrait,
                slides: [
                    Slide(id: sampleID(11), layout: .single, cells: [photo(101, 2048, 2730)]),
                    Slide(id: sampleID(12), layout: .twoColumns, cells: [photo(102, 2048, 1536), Cell()]),
                    Slide(
                        id: sampleID(13),
                        layout: .grid,
                        cells: [
                            photo(103, 2048, 2048),
                            photo(104, 1536, 2048, assetIdentifier: "5E7A5E70-0000-4000-8000-000000000104/L0/001"),
                            photo(105, 2048, 1365),
                            Cell()
                        ]
                    )
                ],
                createdAt: date(daysAgo: 3)
            ),
            Project(
                id: sampleID(2),
                name: "Story Ideas",
                aspectRatio: .story,
                slides: [Slide(id: sampleID(21), layout: .threeRows, cells: [photo(201, 2048, 1365), Cell(), photo(202, 2048, 1536)])],
                createdAt: date(daysAgo: 5)
            ),
            Project(id: sampleID(3), name: "Coastline", aspectRatio: .landscape, createdAt: date(daysAgo: 8))
        ]
    }

    /// The photo `-DebugMissingImages` leaves without a copy. It names a library original that
    /// doesn't exist, so restoring it shows how a missing original reads.
    static let missingImageID = sampleID(104)

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
