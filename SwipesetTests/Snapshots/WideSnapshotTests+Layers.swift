//
//  WideSnapshotTests+Layers.swift
//  SwipesetTests
//

import SwiftUI
import Testing
@testable import Swipeset

extension WideSnapshotTests {
    @Test func layeredSlides() async {
        await assertScreenSnapshot(of: projectScreen(layeredProject), on: .wide)
    }

    @Test func selectedTextLayer() async {
        let project = layeredProject
        await assertScreenSnapshot(of: projectScreen(project, layerSession: selecting(fixtureID(183), in: project)), on: .wide)
    }

    @Test func layersList() async {
        await assertScreenSnapshot(of: layersSheet(layeredGridFirst), on: .wide)
    }

    @Test func addLayerPage() async {
        await assertScreenSnapshot(of: layersSheet(layeredProject, path: [.add]), on: .wide)
    }

    @Test func textLayerEditor() async {
        await assertScreenSnapshot(of: layersSheet(layeredProject, path: [.text(fixtureID(183))]), on: .wide)
    }

    @Test func imageLayerEditor() async {
        await assertScreenSnapshot(of: layersSheet(layeredGridFirst, path: [.image(fixtureID(188))]), on: .wide)
    }
}
