//
//  SnapshotTests+Slides.swift
//  SwipesetTests
//

import SwiftUI
import Testing
@testable import Swipeset

extension SnapshotTests {
    @Test func emptyProject() async {
        await assertScreenSnapshot(of: projectScreen(projects[3]))
    }

    @Test func portraitSlides() async {
        await assertScreenSnapshot(of: projectScreen(projects[0]))
    }

    @Test func storySlides() async {
        await assertScreenSnapshot(of: projectScreen(projects[1]))
    }

    @Test func photoGrid() async {
        await assertScreenSnapshot(of: projectScreen(gridFirst))
    }

    @Test func newSlideSheet() async {
        await assertScreenSnapshot(of: LayoutSheet(aspectRatio: .portrait, current: nil) { _ in 0 } onChoose: { _ in })
    }

    @Test func changeLayoutSheet() async {
        await assertScreenSnapshot(of: LayoutSheet(aspectRatio: .landscape, current: .grid) { _ in 0 } onChoose: { _ in })
    }
}
