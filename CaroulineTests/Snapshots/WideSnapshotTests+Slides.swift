//
//  WideSnapshotTests+Slides.swift
//  CaroulineTests
//

import SwiftUI
import Testing
@testable import Carouline

extension WideSnapshotTests {
    @Test func emptyProject() async {
        await assertScreenSnapshot(of: projectScreen(projects[3]), on: .wide)
    }

    @Test func portraitSlides() async {
        await assertScreenSnapshot(of: projectScreen(projects[0]), on: .wide)
    }

    @Test func landscapeSlides() async {
        await assertScreenSnapshot(of: projectScreen(landscapeProject), on: .wide)
    }

    @Test func photoGrid() async {
        await assertScreenSnapshot(of: projectScreen(gridFirst), on: .wide)
    }

    @Test func selectedPhoto() async {
        let project = projects[0]
        let selection = CellAddress(projectID: project.id, slideID: project.slides[0].id, index: 0)
        await assertScreenSnapshot(of: projectScreen(project, selection: selection), on: .wide)
    }

    @Test func styledSlides() async {
        await assertScreenSnapshot(of: projectScreen(styledProject), on: .wide)
    }

    @Test func movingPhoto() async {
        await assertScreenSnapshot(of: projectScreen(projects[1], held: heldFirstPhoto(of: projects[1])), on: .wide)
    }

    @Test func exportSlides() async throws {
        try await assertScreenSnapshot(of: exportSheet(projects[0]), on: .wide)
    }

    @Test func newSlideSheet() async {
        await assertScreenSnapshot(of: LayoutSheet(aspectRatio: .portrait, current: nil) { _ in 0 } onChoose: { _ in }, on: .wide)
    }

    @Test func panoramaSlides() async {
        await assertScreenSnapshot(of: projectScreen(panoramaProject), on: .wide)
    }
}
