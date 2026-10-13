//
//  SnapshotTests+Projects.swift
//  SwipesetTests
//

import SwiftUI
import Testing
@testable import Swipeset

extension SnapshotTests {
    @Test func emptyProjects() async {
        await assertScreenSnapshot(of: NavigationStack { ProjectsScreen(library: library([])) {} })
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
}
