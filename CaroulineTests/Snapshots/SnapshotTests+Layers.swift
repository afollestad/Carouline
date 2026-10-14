//
//  SnapshotTests+Layers.swift
//  CaroulineTests
//

import SwiftUI
import Testing
@testable import Carouline

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

    /// A blurred sticker's placeholder shows sharp over where its blur would be, with its menu.
    @Test func missingBlurredLayerImage() async {
        var project = layeredGridFirst
        project.slides[0].layers = project.slides[0].layers.map { layer in
            var layer = layer
            if case .image(var picture) = layer.content, picture.image.id == layeredStickerID {
                picture.blur = 0.03
                layer.content = .image(picture)
            }
            return layer
        }
        await assertScreenSnapshot(of: projectScreen(project, missing: [layeredStickerID]))
    }

    /// The export draws layers as the screen does, splits the panorama's across its slides, and
    /// notes a layer image it couldn't read.
    @Test func exportLayers() async throws {
        var project = layeredProject
        project.slides += layeredPanorama.slides
        try await assertScreenSnapshot(of: exportSheet(project, missing: [layeredStickerID]))
    }

    @Test func layeredProjectList() async {
        let library = library([layeredProject])
        await assertScreenSnapshot(of: NavigationStack { ProjectsScreen(library: library) {} }.environment(\.imageLoader, imageLoader))
    }

    /// While a phone's layers sheet rests, the slides shrink to fit above it, so the one it edits
    /// stays in view and in reach.
    @Test func slidesAboveRestingSheet() async {
        let session = LayerSession()
        session.sheetRoom = 350
        await assertScreenSnapshot(of: projectScreen(layeredProject, layerSession: session))
    }

    @Test func selectedTextLayer() async {
        let project = layeredProject
        await assertScreenSnapshot(of: projectScreen(project, layerSession: selecting(fixtureID(183), in: project)))
    }

    @Test func selectedImageLayer() async {
        let project = layeredGridFirst
        await assertScreenSnapshot(of: projectScreen(project, layerSession: selecting(fixtureID(188), in: project)))
    }

    /// A layer centered across its slide shows the guide it snapped to.
    @Test func snapGuides() async {
        let project = layeredGridFirst
        let session = selecting(fixtureID(188), in: project, snap: LayerSnap(guideX: 0.5))
        await assertScreenSnapshot(of: projectScreen(project, layerSession: session))
    }

    @Test func layersList() async {
        await assertScreenSnapshot(of: layersSheet(layeredGridFirst))
    }

    /// A styled slide's sliders and its background's swatch, with the way to give its style to
    /// the slides unlike it.
    @Test func styledLayersList() async {
        await assertScreenSnapshot(of: layersSheet(styledProject))
    }

    @Test func layersListEmpty() async {
        await assertScreenSnapshot(of: layersSheet(landscapeProject))
    }

    @Test func addLayerPage() async {
        await assertScreenSnapshot(of: layersSheet(layeredProject, path: [.add]))
    }

    /// An existing layer's editor, which doesn't take the keyboard as a new one's does.
    @Test func textLayerEditor() async {
        await assertScreenSnapshot(of: layersSheet(layeredProject, path: [.text(fixtureID(183))]))
    }

    @Test func imageLayerEditor() async {
        await assertScreenSnapshot(of: layersSheet(layeredGridFirst, path: [.image(fixtureID(188))]))
    }

    /// A blurred photo with sharp text over it.
    @Test func blurredSlideUnderText() async {
        await assertScreenSnapshot(of: projectScreen(blurredProject))
    }
}
