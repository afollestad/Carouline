//
//  SnapshotTests.swift
//  SwipesetTests
//

import SwiftUI
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
                slides: [
                    Slide(id: fixtureID(11), layout: .single, cells: [photo(111, 2048, 2730)]),
                    Slide(
                        id: fixtureID(12),
                        layout: .grid,
                        cells: [photo(121, 2048, 1536), Cell(), photo(missingPhotoNumber, 2048, 2048), photo(124, 1536, 2048)]
                    )
                ],
                createdAt: created
            ),
            Project(
                id: fixtureID(2),
                name: "Story Ideas",
                aspectRatio: .story,
                slides: [Slide(id: fixtureID(21), layout: .threeRows, cells: [photo(211, 2048, 1365), Cell(), photo(213, 2048, 1536)])],
                createdAt: created
            ),
            Project(id: fixtureID(3), name: "Coastline", aspectRatio: .landscape, createdAt: created),
            Project(id: fixtureID(4), name: "Square One", aspectRatio: .square, createdAt: created)
        ]
    }

    /// A landscape project with a slide in each of a few layouts, several to a screen.
    var landscapeProject: Project {
        Project(
            id: fixtureID(5),
            name: "Coastline",
            aspectRatio: .landscape,
            slides: [
                Slide(id: fixtureID(51), layout: .threeColumns),
                Slide(id: fixtureID(52), layout: .oneLeftTwoRight),
                Slide(id: fixtureID(53), layout: .twoRows)
            ],
            createdAt: created
        )
    }

    /// `project`'s screen in its navigation stack, from a library holding just it, with
    /// `selection` selected to frame.
    func projectScreen(_ project: Project, selection: CellAddress? = nil) -> some View {
        NavigationStack {
            ProjectScreen(library: library([project]), projectID: project.id, selection: selection)
        }
        .environment(\.imageLoader, imageLoader)
    }

    /// Lisbon with its grid first, filled, empty and missing cells side by side.
    var gridFirst: Project {
        var project = projects[0]
        project.slides.reverse()
        return project
    }

    /// The grid on black, with wide spacing and a border.
    var styledProject: Project {
        var project = gridFirst
        project.style = SlideStyle(spacing: 0.03, border: 0.05, background: .black)
        return project
    }

    /// Draws every fixture photo but one, whose copy reads as missing.
    var imageLoader: MockImageLoader {
        MockImageLoader(missing: [fixtureID(missingPhotoNumber)])
    }

    private var missingPhotoNumber: UInt8 {
        123
    }

    private func photo(_ number: UInt8, _ width: Int, _ height: Int) -> Cell {
        Cell(image: PlacedImage(id: fixtureID(number), assetIdentifier: nil, pixelWidth: width, pixelHeight: height))
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
