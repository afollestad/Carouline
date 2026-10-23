//
//  SnapshotTests+Tray.swift
//  CaroulineTests
//

import SwiftUI
import Testing
@testable import Carouline

extension SnapshotTests {
    /// Photos gathered before any slide, and the empty slide asking to start one with them.
    @Test func trayBeforeSlides() async {
        await assertScreenSnapshot(of: projectScreen(trayOnlyProject))
    }

    /// Tray photos on slides marked, by their clones, counted past one, and by their library
    /// original, beside those still to place.
    @Test func trayInUse() async {
        await assertScreenSnapshot(of: projectScreen(trayProject))
    }

    @Test func darkTray() async {
        await assertScreenSnapshot(of: projectScreen(trayProject), appearance: .dark)
    }

    @Test func missingTrayPhoto() async {
        await assertScreenSnapshot(of: projectScreen(trayProject, missing: [fixtureID(148)]))
    }

    /// The tray photos a pick left out, asked about in the tray's place.
    @Test func trayRemovalQuestion() async {
        let project = trayProject
        await assertScreenSnapshot(of: projectScreen(project, trayRemoval: TrayRemoval(projectID: project.id, originals: ["SNAP/L0/001"])))
    }

    /// A tray photo held for a cell, the bar asking for one.
    @Test func placingTrayPhoto() async {
        let project = trayProject
        await assertScreenSnapshot(of: projectScreen(project, held: .tray(projectID: project.id, photoID: fixtureID(43))))
    }
}

extension ScreenSnapshotting {
    /// Lisbon with a tray: one photo on two slides as clones of its tray photo, one on a slide by
    /// its library original, and four still to place, among them a panorama's.
    var trayProject: Project {
        Project(
            id: fixtureID(30),
            name: "Lisbon",
            aspectRatio: .portrait,
            slides: [
                Slide(id: fixtureID(31), layout: .single, cells: [
                    Cell(image: PlacedImage(
                        id: fixtureID(141),
                        assetIdentifier: nil,
                        pixelWidth: 2048,
                        pixelHeight: 2730,
                        trayPhotoID: fixtureID(40)
                    ))
                ]),
                Slide(id: fixtureID(32), layout: .twoColumns, cells: [
                    Cell(image: PlacedImage(id: fixtureID(142), assetIdentifier: "SNAP/L0/001", pixelWidth: 1536, pixelHeight: 2048)),
                    Cell()
                ]),
                Slide(id: fixtureID(34), layout: .single, cells: [
                    Cell(image: PlacedImage(
                        id: fixtureID(156),
                        assetIdentifier: nil,
                        pixelWidth: 2048,
                        pixelHeight: 2730,
                        trayPhotoID: fixtureID(40)
                    ))
                ])
            ],
            // Each copy's number picks the palette its cell's photo has, so a used one matches it.
            tray: [
                trayPhoto(40, image: 146, 2048, 2730),
                trayPhoto(41, image: 147, 1536, 2048, assetIdentifier: "SNAP/L0/001"),
                trayPhoto(42, image: 148, 4096, 1024),
                trayPhoto(43, image: 149, 2048, 1536),
                trayPhoto(44, image: 150, 2048, 2048),
                trayPhoto(45, image: 151, 1536, 2048)
            ],
            createdAt: created
        )
    }

    /// A landscape project with photos gathered before any slide.
    var trayOnlyProject: Project {
        Project(
            id: fixtureID(33),
            name: "Coastline",
            aspectRatio: .landscape,
            tray: [
                trayPhoto(46, image: 152, 2048, 1365),
                trayPhoto(47, image: 153, 1536, 2048),
                trayPhoto(48, image: 154, 4096, 1024),
                trayPhoto(49, image: 155, 2048, 1536)
            ],
            createdAt: created
        )
    }

    private func trayPhoto(_ number: UInt8, image: UInt8, _ width: Int, _ height: Int, assetIdentifier: String? = nil) -> TrayPhoto {
        TrayPhoto(
            id: fixtureID(number),
            image: PlacedImage(id: fixtureID(image), assetIdentifier: assetIdentifier, pixelWidth: width, pixelHeight: height)
        )
    }
}
