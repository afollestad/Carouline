//
//  SnapshotTests+Projects.swift
//  CaroulineTests
//

import SwiftUI
import Testing
@testable import Carouline

extension SnapshotTests {
    @Test func emptyProjects() async {
        await assertScreenSnapshot(of: NavigationStack { ProjectsScreen(library: library([])) {} })
    }

    /// A placeholder row stands in for each project on disk until the library loads.
    @Test func loadingProjects() async {
        let library = ProjectLibrary(store: MockProjectStore(projects: projects))
        await assertScreenSnapshot(of: NavigationStack { ProjectsScreen(library: library) {} })
    }

    @Test func projectList() async {
        let library = library(projects, unreadable: [unreadableProject])
        await assertScreenSnapshot(of: NavigationStack { ProjectsScreen(library: library) {} }.environment(\.imageLoader, imageLoader))
    }

    @Test func darkProjectList() async {
        let library = library(projects)
        await assertScreenSnapshot(
            of: NavigationStack { ProjectsScreen(library: library) {} }.environment(\.imageLoader, imageLoader),
            appearance: .dark
        )
    }

    /// A panorama's thumbnail shows just its first slide, and its summary counts all of them.
    @Test func panoramaProjectList() async {
        let library = library([panoramaProject])
        await assertScreenSnapshot(of: NavigationStack { ProjectsScreen(library: library) {} }.environment(\.imageLoader, imageLoader))
    }

    @Test func newProjectSheet() async throws {
        let presets = try savedPresets()
        await assertScreenSnapshot(of: AspectRatioSheet(presets: presets) { _ in })
    }

    /// The New tile follows the presets until there are saved shapes for a Custom section.
    @Test func newProjectSheetWithoutPresets() async {
        await assertScreenSnapshot(of: AspectRatioSheet(presets: CustomPresets(presets: [])) { _ in })
    }

    /// Each saved shape shows its delete badge, and Done stands in for Edit and the New tile.
    @Test func newProjectSheetEditing() async throws {
        let presets = try savedPresets()
        await assertScreenSnapshot(of: AspectRatioSheet(presets: presets, isEditing: true) { _ in })
    }

    @Test func customRatioPage() async {
        var draft = CustomRatioDraft()
        draft.savesPreset = true
        draft.presetName = "Etsy"
        await assertScreenSnapshot(of: AspectRatioSheet(presets: CustomPresets(presets: []), startsOnCustom: draft) { _ in })
    }

    /// A ratio and a side past their limits each say so under their fields, with room before the
    /// next section, and the other side still follows the ratio.
    @Test func customRatioProblem() async {
        var draft = CustomRatioDraft()
        draft.setPixelWidth("5000")
        draft.setRatioWidth("3")
        draft.setRatioHeight("1")
        await assertScreenSnapshot(of: AspectRatioSheet(presets: CustomPresets(presets: []), startsOnCustom: draft) { _ in })
    }
}
