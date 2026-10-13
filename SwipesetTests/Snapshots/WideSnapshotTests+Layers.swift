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
}
