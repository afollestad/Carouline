//
//  WideSnapshotTests+Tray.swift
//  CaroulineTests
//

import SwiftUI
import Testing
@testable import Carouline

extension WideSnapshotTests {
    @Test func trayBeforeSlides() async {
        await assertScreenSnapshot(of: projectScreen(trayOnlyProject), on: .wide)
    }

    @Test func trayInUse() async {
        await assertScreenSnapshot(of: projectScreen(trayProject), on: .wide)
    }

    @Test func darkTray() async {
        await assertScreenSnapshot(of: projectScreen(trayProject), on: .wide, appearance: .dark)
    }

    @Test func missingTrayPhoto() async {
        await assertScreenSnapshot(of: projectScreen(trayProject, missing: [fixtureID(148)]), on: .wide)
    }

    @Test func placingTrayPhoto() async {
        let project = trayProject
        await assertScreenSnapshot(of: projectScreen(project, held: .tray(projectID: project.id, photoID: fixtureID(43))), on: .wide)
    }

    @Test func magnifyingTrayPhoto() async {
        await assertScreenSnapshot(of: projectScreen(trayProject, trayPress: TrayPress(scrubbing: fixtureID(43))), on: .wide)
    }

    @Test func carryingTrayPhoto() async {
        let press = TrayPress(carrying: fixtureID(43), at: CGPoint(x: 372, y: 520))
        await assertScreenSnapshot(of: projectScreen(trayProject, trayPress: press), on: .wide)
    }
}
