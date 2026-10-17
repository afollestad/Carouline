//
//  WideSnapshotTests+Projects.swift
//  CaroulineTests
//

import SwiftUI
import Testing
@testable import Carouline

extension WideSnapshotTests {
    @Test func emptyProjects() async {
        await assertScreenSnapshot(of: NavigationStack { ProjectsScreen(library: library([])) {} }, on: .wide)
    }

    @Test func loadingProjects() async {
        let library = ProjectLibrary(store: MockProjectStore(projects: projects))
        await assertScreenSnapshot(of: NavigationStack { ProjectsScreen(library: library) {} }, on: .wide)
    }

    @Test func projectList() async {
        let library = library(projects, unreadable: [unreadableProject])
        await assertScreenSnapshot(of: NavigationStack { ProjectsScreen(library: library) {} }.environment(\.imageLoader, imageLoader), on: .wide)
    }

    @Test func newProjectSheet() async throws {
        let presets = try savedPresets()
        await assertScreenSnapshot(of: AspectRatioSheet(presets: presets) { _ in }, on: .wide)
    }

    @Test func customRatioPage() async {
        var draft = CustomRatioDraft()
        draft.savesPreset = true
        draft.presetName = "Etsy"
        await assertScreenSnapshot(of: AspectRatioSheet(presets: CustomPresets(presets: []), startsOnCustom: draft) { _ in }, on: .wide)
    }
}
