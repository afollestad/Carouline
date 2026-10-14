//
//  SnapshotTests.swift
//  CaroulineTests
//

import SwiftUI
import Testing
@testable import Carouline

/// Full-screen snapshots on the iPhone, grouped into `+Topic` files by screen. Serialized,
/// since each snapshot puts its own window over the whole screen.
@MainActor
@Suite(.serialized)
struct SnapshotTests: ScreenSnapshotting {
    let temporary = TemporaryDirectory("SnapshotTests")
}

/// The fixtures both snapshot suites build their screens from.
@MainActor
protocol ScreenSnapshotting {
    /// Where screens that write files, like the export sheet, write them.
    var temporary: TemporaryDirectory { get }
}

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

    /// A wide photo cut across three portrait slides, with a slide after it. Kept out of
    /// `projects`, so the project list's baselines don't change with it.
    var panoramaProject: Project {
        Project(
            id: fixtureID(6),
            name: "Ridgeline",
            aspectRatio: .portrait,
            slides: [
                Slide(id: fixtureID(61), layout: .panorama, span: 3, cells: [photo(161, 3072, 1024)]),
                Slide(id: fixtureID(62), layout: .single, cells: [photo(162, 2048, 2730)])
            ],
            createdAt: created
        )
    }

    /// An empty panorama across three landscape slides, the thinnest card a default one makes.
    var landscapePanorama: Project {
        Project(
            id: fixtureID(7),
            name: "Shoreline",
            aspectRatio: .landscape,
            slides: [Slide(id: fixtureID(71), layout: .panorama)],
            createdAt: created
        )
    }

    /// `project`'s screen in its navigation stack, from a library holding just it, with
    /// `selection` selected to frame, `layerSession`'s layer selected, `missing` images' copies
    /// missing, and `loading` images' still loading.
    func projectScreen(
        _ project: Project,
        selection: CellAddress? = nil,
        layerSession: LayerSession? = nil,
        missing: Set<UUID>? = nil,
        loading: Set<UUID> = []
    ) -> some View {
        var loader = missing.map { MockImageLoader(missing: $0) } ?? imageLoader
        loader.loading = loading
        return NavigationStack {
            ProjectScreen(library: library([project]), projectID: project.id, selection: selection, layerSession: layerSession ?? LayerSession())
        }
        .environment(\.imageLoader, loader)
    }

    /// A photo under a shadowed title and highlighted, turned text, and a grid under a framed,
    /// turned photo and a sticker, both shadowed. Kept out of `projects`, so the project list's
    /// baselines don't change with it.
    var layeredProject: Project {
        Project(
            id: fixtureID(8),
            name: "Layered",
            aspectRatio: .portrait,
            slides: [
                Slide(
                    id: fixtureID(81),
                    layout: .single,
                    cells: [photo(181, 2048, 2730)],
                    layers: [
                        Layer(
                            id: fixtureID(182),
                            content: .text(TextLayer(text: "Lisbon", font: .serif, hasShadow: true)),
                            placement: LayerPlacement(centerY: 0.14, scale: 1.4)
                        ),
                        Layer(
                            id: fixtureID(183),
                            content: .text(TextLayer(
                                text: "Day one,\nby the river",
                                font: .rounded,
                                color: violet,
                                alignment: .leading,
                                isHighlighted: true
                            )),
                            placement: LayerPlacement(centerX: 0.36, centerY: 0.84, scale: 0.8, rotation: -0.06)
                        )
                    ]
                ),
                Slide(
                    id: fixtureID(84),
                    layout: .grid,
                    cells: [photo(185, 2048, 1536), photo(186, 1536, 2048), Cell(), photo(187, 2048, 2048)],
                    layers: [
                        Layer(
                            id: fixtureID(188),
                            content: .image(ImageLayer(
                                image: PlacedImage(id: fixtureID(189), assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 1536),
                                borderWidth: 0.04,
                                hasShadow: true
                            )),
                            placement: LayerPlacement(centerY: 0.42, scale: 1.2, rotation: 0.08)
                        ),
                        Layer(
                            id: fixtureID(190),
                            content: .image(ImageLayer(
                                image: PlacedImage(id: layeredStickerID, assetIdentifier: nil, pixelWidth: 600, pixelHeight: 600, fileFormat: .png),
                                borderWidth: 0.05,
                                hasShadow: true
                            )),
                            placement: LayerPlacement(centerX: 0.75, centerY: 0.76, scale: 0.6)
                        )
                    ]
                )
            ],
            createdAt: created
        )
    }

    /// A session with `layerID` on `project`'s first slide selected, snapped to `snap`.
    func selecting(_ layerID: UUID, in project: Project, snap: LayerSnap = LayerSnap()) -> LayerSession {
        LayerSession(selection: LayerAddress(projectID: project.id, slideID: project.slides[0].id, layerID: layerID), snap: snap)
    }

    /// The layers sheet for `project`'s first slide, at `path`.
    func layersSheet(_ project: Project, path: [LayersPage] = []) -> some View {
        let session = LayerSession()
        session.sheetPath = path
        return LayersSheet(
            library: library([project]),
            projectID: project.id,
            slideID: project.slides[0].id,
            session: session,
            actions: .preview,
            dynamicTypeSize: .large
        ) {}
        .environment(\.imageLoader, imageLoader)
    }

    /// `layeredProject` with its grid first.
    var layeredGridFirst: Project {
        var project = layeredProject
        project.slides.reverse()
        return project
    }

    /// The sticker on `layeredProject`'s grid, which some snapshots leave without a copy.
    var layeredStickerID: UUID {
        fixtureID(191)
    }

    /// A wide photo cut across three slides, with highlighted text across its first cut, which
    /// the carousel splits between two slides, and a title within its middle slide.
    var layeredPanorama: Project {
        Project(
            id: fixtureID(9),
            name: "Ridgeline",
            aspectRatio: .portrait,
            slides: [
                Slide(
                    id: fixtureID(92),
                    layout: .panorama,
                    span: 3,
                    cells: [photo(193, 3072, 1024)],
                    layers: [
                        Layer(
                            id: fixtureID(194),
                            content: .text(TextLayer(text: "Swipe →", font: .rounded, color: violet, isHighlighted: true)),
                            placement: LayerPlacement(centerX: 1, centerY: 0.8, scale: 2)
                        ),
                        Layer(
                            id: fixtureID(195),
                            content: .text(TextLayer(text: "Ridgeline", font: .futura, hasShadow: true)),
                            placement: LayerPlacement(centerX: 1.5, centerY: 0.2, scale: 2)
                        )
                    ]
                )
            ],
            createdAt: created
        )
    }

    /// A photo blurred into a backdrop under sharp text, kept out of `projects`.
    var blurredProject: Project {
        Project(
            id: fixtureID(10),
            name: "Backdrop",
            aspectRatio: .portrait,
            slides: [
                Slide(
                    id: fixtureID(96),
                    layout: .single,
                    cells: [photo(196, 2048, 2560)],
                    layers: [
                        Layer(
                            id: fixtureID(197),
                            content: .text(TextLayer(text: "Day one,\nby the river", font: .serif, color: .white, hasShadow: true)),
                            placement: LayerPlacement(scale: 1.6)
                        )
                    ],
                    blur: 0.03
                )
            ],
            createdAt: created
        )
    }

    private var violet: RGBColor {
        RGBColor(red: 0.47, green: 0.34, blue: 0.91)
    }

    /// Lisbon with its grid first, filled, empty and missing cells side by side.
    var gridFirst: Project {
        var project = projects[0]
        project.slides.reverse()
        return project
    }

    /// The grid alone on black, with wide spacing and a border, beside slides in the standard
    /// style.
    var styledProject: Project {
        var project = gridFirst
        project.slides[0].style = SlideStyle(spacing: 0.03, border: 0.05, background: .black)
        return project
    }

    /// `project`'s export sheet, which renders the fixture images as drawn, but for those
    /// `missing`, by default the photo whose copy reads as missing. The export runs before the
    /// sheet shows, since a slow machine like CI's takes longer to write it than a screen gets to
    /// settle, and would snapshot the sheet still preparing.
    func exportSheet(_ project: Project, missing: Set<UUID>? = nil) async throws -> some View {
        let missing = missing ?? [fixtureID(missingPhotoNumber)]
        let exporter = SlideExporter(paths: ProjectPaths(root: temporary.url, temporary: temporary.url)) { image, _, size in
            guard !missing.contains(image.id) else {
                return nil
            }
            return SampleImages.image(for: image, maxPixelSize: Int(max(size.width, size.height)))
        }
        let result = try await exporter.export(project)
        return ExportSheet(project: project, exporter: FinishedExport(result: result))
            .environment(\.photoSaver, MockPhotoSaver())
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
        UnreadableProject(
            folder: URL(filePath: "/Projects/Newer", directoryHint: .isDirectory),
            reason: .newerVersion(ProjectFile.currentFormatVersion + 1)
        )
    }

    /// IDs that stay the same between runs, so slides keep their order and identity.
    func fixtureID(_ number: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, number))
    }

    private var created: Date {
        Date(timeIntervalSince1970: 1_800_000_000)
    }
}

/// An export already written, which the sheet shows on its first update.
private struct FinishedExport: SlideExporting {
    let result: ExportResult

    func export(_ project: Project) async throws -> ExportResult {
        result
    }
}
