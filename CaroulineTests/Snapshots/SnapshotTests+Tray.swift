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

    /// Tray photos on slides marked, by their clone and by their library original, beside those
    /// still to place.
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
