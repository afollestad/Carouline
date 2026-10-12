//
//  WideSnapshotTests+Slides.swift
//  SwipesetTests
//

import SwiftUI
import Testing
@testable import Swipeset

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

    @Test func newSlideSheet() async {
        await assertScreenSnapshot(of: LayoutSheet(aspectRatio: .portrait, current: nil) { _ in 0 } onChoose: { _ in }, on: .wide)
    }
}
