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

    @Test func newProjectSheet() async {
        await assertScreenSnapshot(of: AspectRatioSheet { _ in })
    }

    @Test func customRatioPage() async {
        await assertScreenSnapshot(of: AspectRatioSheet(startsOnCustom: CustomRatioDraft()) { _ in })
    }

    /// A side past its limits says so, and the other side still follows the ratio.
    @Test func customRatioProblem() async {
        var draft = CustomRatioDraft()
        draft.setPixelWidth("5000")
        await assertScreenSnapshot(of: AspectRatioSheet(startsOnCustom: draft) { _ in })
    }
}
