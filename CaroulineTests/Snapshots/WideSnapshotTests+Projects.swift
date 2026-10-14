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

    @Test func newProjectSheet() async {
        await assertScreenSnapshot(of: AspectRatioSheet { _ in }, on: .wide)
    }
}
