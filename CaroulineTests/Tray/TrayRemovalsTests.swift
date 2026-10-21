//
//  TrayRemovalsTests.swift
//  CaroulineTests
//

import Foundation
import Testing
@testable import Carouline

@MainActor
struct TrayRemovalsTests {
    private let projectID = UUID()

    @Test func asksAboutLeftOutPhotosAndForgetsThemOnceKept() {
        let removals = TrayRemovals()

        removals.ask(about: ["A", "B"], in: projectID)
        #expect(removals.pending == TrayRemoval(projectID: projectID, originals: ["A", "B"]))
        removals.keep()
        #expect(removals.pending == nil)
        // A photo deleted from the library is left out of every pick; it's asked about once.
        removals.ask(about: ["A", "C"], in: projectID)
        #expect(removals.pending?.originals == ["C"])
    }

    /// A second pick before the first is answered asks about both.
    @Test func gathersPicksWaitingOnAnAnswer() {
        let removals = TrayRemovals()

        removals.ask(about: ["A"], in: projectID)
        removals.ask(about: ["B"], in: projectID)

        #expect(removals.pending?.originals == ["A", "B"])
    }

    @Test func asksNothingForNothingLeftOut() {
        let removals = TrayRemovals()

        removals.ask(about: [], in: projectID)

        #expect(removals.pending == nil)
    }

    @Test func removesThePhotosWaitingOnAnAnswer() async {
        let kept = TrayPhoto(image: PlacedImage(assetIdentifier: "A", pixelWidth: 10, pixelHeight: 10))
        let removed = TrayPhoto(image: PlacedImage(assetIdentifier: "B", pixelWidth: 10, pixelHeight: 10))
        let project = Project(id: projectID, name: "Trip", aspectRatio: .portrait, tray: [kept, removed])
        let library = ProjectLibrary(store: MockProjectStore(projects: [project]), projects: [project])
        let removals = TrayRemovals()

        removals.ask(about: ["B"], in: projectID)
        removals.remove(from: library)
        await library.flush()

        #expect(library.project(projectID)?.tray == [kept])
        #expect(removals.pending == nil)
    }
}
