//
//  ProjectLibraryTests.swift
//  CaroulineTests
//

import Foundation
import Testing
@testable import Carouline

@MainActor
struct ProjectLibraryTests {
    private let temporary = TemporaryDirectory("ProjectLibraryTests")

    private var paths: ProjectPaths {
        ProjectPaths(
            root: temporary.url.appending(path: "Support", directoryHint: .isDirectory),
            temporary: temporary.url.appending(path: "tmp", directoryHint: .isDirectory)
        )
    }

    private func makeLibrary() async -> ProjectLibrary {
        let library = ProjectLibrary(store: ProjectStore(paths: paths))
        await library.load()
        return library
    }

    /// What a later launch reads back.
    private func reloaded() async -> [Project] {
        await ProjectStore(paths: paths).loadAll().projects
    }

    @Test func namesNewProjectsAfterTheFirstFreeNumber() async {
        let library = await makeLibrary()
        let first = library.createProject(aspectRatio: .portrait)
        let second = library.createProject(aspectRatio: .square)
        _ = library.createProject(aspectRatio: .story)
        library.delete(second.id)

        #expect(first.name == "Untitled")
        #expect(second.name == "Untitled 2")
        #expect(library.createProject(aspectRatio: .landscape).name == "Untitled 2")
        await library.flush()
    }

    @Test func savesChangesInTheOrderTheyWereMade() async {
        let library = await makeLibrary()
        let project = library.createProject(aspectRatio: .portrait)
        library.rename(project.id, to: "First")
        library.rename(project.id, to: "Second")
        await library.flush()

        #expect(await reloaded().map(\.name) == ["Second"])
    }

    @Test func trimsNamesAndIgnoresBlankOnes() async {
        let library = await makeLibrary()
        let project = library.createProject(aspectRatio: .portrait)
        library.rename(project.id, to: "  Lisbon \n")
        library.rename(project.id, to: "   ")

        #expect(library.project(project.id)?.name == "Lisbon")
        await library.flush()
    }

    @Test func keepsTheLatestChangeFirst() async {
        let library = await makeLibrary()
        let older = library.createProject(aspectRatio: .portrait)
        let newer = library.createProject(aspectRatio: .square)
        library.rename(older.id, to: "Changed")

        #expect(library.projects.map(\.id) == [older.id, newer.id])
        await library.flush()
    }

    @Test func deletingBeforeTheFirstSaveLandsLeavesNothing() async {
        let library = await makeLibrary()
        let project = library.createProject(aspectRatio: .portrait)
        library.rename(project.id, to: "Doomed")
        library.delete(project.id)
        await library.flush()

        #expect(library.projects.isEmpty)
        #expect(await reloaded().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: paths.folder(for: project.id).path(percentEncoded: false)))
    }

    @Test func deletesDroppedImagesOnceTheChangeIsSaved() async throws {
        let library = await makeLibrary()
        let project = library.createProject(aspectRatio: .portrait)
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10)
        try FileManager.default.createDirectory(at: paths.imports, withIntermediateDirectories: true)
        let copy = paths.imports.appending(path: "copy.jpg")
        try Data([0xFF, 0xD8]).write(to: copy)
        await library.flush()
        #expect(try await library.store.adoptImage(at: copy, as: image.fileName, in: project.id))
        library.update(project.id) { $0.slides = [Slide(layout: .single, cells: [Cell(image: image)])] }

        library.update(project.id, deletingImages: [image]) { $0.slides = [] }
        await library.flush()

        #expect(await reloaded().first?.slides.isEmpty == true)
        #expect(!FileManager.default.fileExists(atPath: paths.imageFile(named: image.fileName, in: project.id).path(percentEncoded: false)))
    }

    /// Every window asks the library to load, and a second load would sweep again.
    @Test func loadsOnceHoweverManyWindowsAsk() async {
        let store = CountingStore()
        let library = ProjectLibrary(store: store)
        async let first: Void = library.load()
        async let second: Void = library.load()
        _ = await (first, second)
        await library.load()

        #expect(await store.loads == 1)
        #expect(library.isLoaded)
    }

    /// Placeholders stand in for the projects on disk until the library loads them.
    @Test func expectsTheProjectsOnDisk() async throws {
        let store = ProjectStore(paths: paths)
        try await store.save(Project(name: "First", aspectRatio: .portrait))
        try await store.save(Project(name: "Second", aspectRatio: .square))

        #expect(ProjectLibrary(store: ProjectStore(paths: paths)).expectedCount == 2)
    }

    @Test func reportsAWriteThatFails() async {
        let library = ProjectLibrary(store: FailingStore(), projects: [])
        _ = library.createProject(aspectRatio: .portrait)
        await library.flush()

        #expect(library.failure?.kind == .write)
    }
}

/// A store whose every write fails, as a full disk's would.
private actor FailingStore: ProjectStoring {
    struct Failure: Error {}

    nonisolated let paths = ProjectPaths(root: .temporaryDirectory, temporary: .temporaryDirectory)
    nonisolated let storedProjectCount = 0

    func loadAll() -> StoredProjects {
        StoredProjects()
    }

    func save(_ project: Project) throws {
        throw Failure()
    }

    func delete(projectID: UUID) throws {
        throw Failure()
    }

    func delete(_ unreadable: UnreadableProject) throws {
        throw Failure()
    }

    func adoptImage(at source: URL, as fileName: String, in projectID: UUID) throws -> Bool {
        throw Failure()
    }

    func deleteImages(_ fileNames: [String], in projectID: UUID) {}
}
