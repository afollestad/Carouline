//
//  SampleProjects.swift
//  Swipeset
//

import Foundation

/// Projects with something in them, for previews and the debug sample store.
nonisolated enum SampleProjects {
    static var all: [Project] {
        [
            Project(
                id: sampleID(1),
                name: "Lisbon",
                aspectRatio: .portrait,
                slides: [
                    Slide(id: sampleID(11), layout: .single),
                    Slide(id: sampleID(12), layout: .twoColumns),
                    Slide(id: sampleID(13), layout: .grid)
                ],
                createdAt: date(daysAgo: 3)
            ),
            Project(
                id: sampleID(2),
                name: "Story Ideas",
                aspectRatio: .story,
                slides: [Slide(id: sampleID(21), layout: .threeRows)],
                createdAt: date(daysAgo: 5)
            ),
            Project(id: sampleID(3), name: "Coastline", aspectRatio: .landscape, createdAt: date(daysAgo: 8))
        ]
    }

    /// IDs that stay the same between launches, so a debug launch argument can name a project.
    static func sampleID(_ number: UInt8) -> UUID {
        UUID(uuid: (0x5E, 0x7A, 0x5E, 0x70, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, number))
    }

    private static func date(daysAgo: Double) -> Date {
        Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 - daysAgo * 86_400).rounded())
    }
}
