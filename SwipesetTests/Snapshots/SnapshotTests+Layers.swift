//
//  SnapshotTests+Layers.swift
//  SwipesetTests
//

import SwiftUI
import Testing
@testable import Swipeset

extension SnapshotTests {
    @Test func layeredSlides() async {
        await assertScreenSnapshot(of: projectScreen(layeredProject))
    }

    @Test func layeredGrid() async {
        await assertScreenSnapshot(of: projectScreen(layeredGridFirst))
    }

    @Test func darkLayeredSlides() async {
        await assertScreenSnapshot(of: projectScreen(layeredGridFirst), appearance: .dark)
    }

    /// Layers across a panorama's cuts show the cut over them, as the carousel splits them there.
    @Test func layeredPanorama() async {
        await assertScreenSnapshot(of: projectScreen(layeredPanorama))
    }

    @Test func missingLayerImage() async {
        await assertScreenSnapshot(of: projectScreen(layeredGridFirst, missing: [layeredStickerID]))
    }

    /// The export draws layers as the screen does, splits the panorama's across its slides, and
    /// notes a layer image it couldn't read.
    @Test func exportLayers() async {
        var project = layeredProject
        project.slides += layeredPanorama.slides
        await assertScreenSnapshot(of: exportSheet(project, missing: [layeredStickerID]))
    }

    @Test func layeredProjectList() async {
        let library = library([layeredProject])
        await assertScreenSnapshot(of: NavigationStack { ProjectsScreen(library: library) {} }.environment(\.imageLoader, imageLoader))
    }
}
