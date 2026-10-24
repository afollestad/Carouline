//
//  SnapshotTests+Slides.swift
//  CaroulineTests
//

import SwiftUI
import Testing
@testable import Carouline

extension SnapshotTests {
    @Test func emptyProject() async {
        await assertScreenSnapshot(of: projectScreen(projects[3]))
    }

    @Test func portraitSlides() async {
        await assertScreenSnapshot(of: projectScreen(projects[0]))
    }

    /// Placeholders stand in for photos still decoding, and the backdrop keeps its glow.
    @Test func loadingPhotos() async {
        let project = projects[0]
        await assertScreenSnapshot(of: projectScreen(project, loading: Set(project.images.map(\.id))))
    }

    @Test func darkPhotoGrid() async {
        await assertScreenSnapshot(of: projectScreen(gridFirst), appearance: .dark)
    }

    /// The project a fresh install opens first, its title over its first photo.
    @Test func firstLaunchSample() async {
        await assertScreenSnapshot(of: projectScreen(SampleProjects.firstLaunch))
    }

    @Test func storySlides() async {
        await assertScreenSnapshot(of: projectScreen(projects[1]))
    }

    @Test func photoGrid() async {
        await assertScreenSnapshot(of: projectScreen(gridFirst))
    }

    @Test func selectedPhoto() async {
        let project = projects[0]
        let selection = CellAddress(projectID: project.id, slideID: project.slides[0].id, index: 0)
        await assertScreenSnapshot(of: projectScreen(project, selection: selection))
    }

    @Test func styledSlides() async {
        await assertScreenSnapshot(of: projectScreen(styledProject))
    }

    /// A photo held to move: its cell marked, the empty cell offering a place, and the bar asking
    /// for a cell.
    @Test func movingPhoto() async {
        await assertScreenSnapshot(of: projectScreen(projects[1], held: heldFirstPhoto(of: projects[1])))
    }

    @Test func exportSlides() async throws {
        try await assertScreenSnapshot(of: exportSheet(projects[0]))
    }

    @Test func newSlideSheet() async {
        await assertScreenSnapshot(of: LayoutSheet(aspectRatio: .portrait, current: nil) { _ in 0 } onChoose: { _ in })
    }

    @Test func changeLayoutSheet() async {
        await assertScreenSnapshot(of: LayoutSheet(aspectRatio: .landscape, current: .grid) { _ in 0 } onChoose: { _ in })
    }

    @Test func panoramaSlides() async {
        await assertScreenSnapshot(of: projectScreen(panoramaProject))
    }

    @Test func selectedPanorama() async {
        let project = panoramaProject
        let selection = CellAddress(projectID: project.id, slideID: project.slides[0].id, index: 0)
        await assertScreenSnapshot(of: projectScreen(project, selection: selection))
    }

    /// Slides narrower than their captions, as on a phone in landscape: the first rests in the
    /// middle of a card its caption widens, and the panorama's caption stays on the panorama.
    /// Tighter than the default, which a caption moved by its overflow alone would pass.
    @Test func captionsWiderThanSlides() async {
        await assertScreenSnapshot(of: slideStrip(narrowSlidesProject, height: 340), precision: 0.998)
    }

    @Test func emptyPanorama() async {
        await assertScreenSnapshot(of: projectScreen(landscapePanorama))
    }

    @Test func exportPanorama() async throws {
        try await assertScreenSnapshot(of: exportSheet(panoramaProject))
    }
}
