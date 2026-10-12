//
//  SnapshotTests.swift
//  SwipesetTests
//

import Foundation
import Testing
@testable import Swipeset

/// Full-screen snapshots on the iPhone, grouped into `+Topic` files by screen. Serialized,
/// since each snapshot puts its own window over the whole screen.
@MainActor
@Suite(.serialized)
struct SnapshotTests: ScreenSnapshotting {}

/// The fixtures both snapshot suites build their screens from.
@MainActor
protocol ScreenSnapshotting {}

extension ScreenSnapshotting {
    /// A library of `projects` that never touches the disk.
    func library(_ projects: [Project], unreadable: [UnreadableProject] = []) -> ProjectLibrary {
        ProjectLibrary(store: MockProjectStore(), projects: projects, unreadable: unreadable)
    }

    /// Projects of every shape, with slides or without.
    var projects: [Project] {
        [
            Project(
                id: fixtureID(1),
                name: "Lisbon",
                aspectRatio: .portrait,
                slides: [Slide(id: fixtureID(11), layout: .single), Slide(id: fixtureID(12), layout: .grid)],
                createdAt: created
            ),
            Project(
                id: fixtureID(2),
                name: "Story Ideas",
                aspectRatio: .story,
                slides: [Slide(id: fixtureID(21), layout: .threeRows)],
                createdAt: created
            ),
            Project(id: fixtureID(3), name: "Coastline", aspectRatio: .landscape, createdAt: created),
            Project(id: fixtureID(4), name: "Square One", aspectRatio: .square, createdAt: created)
        ]
    }

    var unreadableProject: UnreadableProject {
        UnreadableProject(folder: URL(filePath: "/Projects/Newer", directoryHint: .isDirectory), reason: .newerVersion(2))
    }

    /// IDs that stay the same between runs, so slides keep their order and identity.
    func fixtureID(_ number: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, number))
    }

    private var created: Date {
        Date(timeIntervalSince1970: 1_800_000_000)
    }
}
