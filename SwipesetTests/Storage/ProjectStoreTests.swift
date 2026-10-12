//
//  ProjectStoreTests.swift
//  SwipesetTests
//

import Foundation
import Testing
@testable import Swipeset

struct ProjectStoreTests {
    /// Whole seconds, which is all a saved date keeps.
    private static let created = Date(timeIntervalSince1970: 1_800_000_000)

    private let temporary = TemporaryDirectory("ProjectStoreTests")

    private var paths: ProjectPaths {
        ProjectPaths(
            root: temporary.url.appending(path: "Support", directoryHint: .isDirectory),
            temporary: temporary.url.appending(path: "tmp", directoryHint: .isDirectory)
        )
    }

    @Test func loadsWhatItSaves() async throws {
        let store = ProjectStore(paths: paths)
        let older = Project(name: "Older", aspectRatio: .square, createdAt: Self.created)
        let newer = Project(name: "Newer", aspectRatio: .story, createdAt: Self.created.addingTimeInterval(100))
        try await store.save(older)
        try await store.save(newer)

        let stored = await ProjectStore(paths: paths).loadAll()
        #expect(stored.projects == [newer, older])
        #expect(stored.unreadable.isEmpty)
    }

    @Test func deletingRemovesTheFolderAndRefusesLateWrites() async throws {
        let store = ProjectStore(paths: paths)
        let project = Project(name: "Gone", aspectRatio: .portrait)
        try await store.save(project)
        let image = try writeImport()

        try await store.delete(projectID: project.id)
        try await store.save(project)
        let kept = try await store.adoptImage(at: image, as: UUID(), in: project.id)

        #expect(!kept)
        #expect(!exists(image))
        #expect(!exists(paths.folder(for: project.id)))
        #expect(!exists(paths.trash) || contents(of: paths.trash).isEmpty)
    }

    @Test func adoptsImportsIntoTheProjectsFolder() async throws {
        let store = ProjectStore(paths: paths)
        let project = Project(name: "Photos", aspectRatio: .portrait)
        try await store.save(project)
        let imageID = UUID()

        let kept = try await store.adoptImage(at: try writeImport(), as: imageID, in: project.id)

        #expect(kept)
        #expect(exists(paths.imageFile(imageID, in: project.id)))
        await store.deleteImages([imageID], in: project.id)
        #expect(!exists(paths.imageFile(imageID, in: project.id)))
    }

    @Test func sweepsCopiesNoProjectRefersTo() async throws {
        let store = ProjectStore(paths: paths)
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10)
        let project = Project(
            name: "Kept",
            aspectRatio: .portrait,
            slides: [Slide(layout: .single, cells: [Cell(image: image)])],
            createdAt: Self.created
        )
        try await store.save(project)
        _ = try await store.adoptImage(at: try writeImport(), as: image.id, in: project.id)
        let orphan = UUID()
        _ = try await store.adoptImage(at: try writeImport(), as: orphan, in: project.id)

        let stored = await ProjectStore(paths: paths).loadAll()

        #expect(stored.projects == [project])
        #expect(exists(paths.imageFile(image.id, in: project.id)))
        #expect(!exists(paths.imageFile(orphan, in: project.id)))
    }

    @Test func sweepsCrashLeftoversAndTemporaryFiles() async throws {
        let leftover = paths.folder(for: UUID())
        try FileManager.default.createDirectory(at: leftover.appending(path: "Images"), withIntermediateDirectories: true)
        let trashed = paths.trash.appending(path: "Half", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: trashed, withIntermediateDirectories: true)
        let export = paths.exports.appending(path: "Session", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: export, withIntermediateDirectories: true)
        let staleImport = try writeImport()

        let stored = await ProjectStore(paths: paths).loadAll()

        #expect(stored.projects.isEmpty)
        #expect(!exists(leftover))
        #expect(!exists(trashed))
        #expect(!exists(export))
        #expect(!exists(staleImport))
    }

    @Test func leavesProjectsItCantReadUntouched() async throws {
        let newerID = UUID()
        let newer = paths.file(for: newerID)
        try FileManager.default.createDirectory(at: paths.imagesFolder(for: newerID), withIntermediateDirectories: true)
        try Data(#"{"formatVersion": 9, "project": {}}"#.utf8).write(to: newer)
        let newerImage = paths.imageFile(UUID(), in: newerID)
        try Data([1]).write(to: newerImage)
        let damagedID = UUID()
        try FileManager.default.createDirectory(at: paths.folder(for: damagedID), withIntermediateDirectories: true)
        try Data("{".utf8).write(to: paths.file(for: damagedID))

        let store = ProjectStore(paths: paths)
        let stored = await store.loadAll()

        #expect(Set(stored.unreadable.map(\.reason)) == [.newerVersion(9), .damaged])
        #expect(exists(newer))
        #expect(exists(newerImage))
        #expect(exists(paths.file(for: damagedID)))

        let damaged = try #require(stored.unreadable.first { $0.reason == .damaged })
        try await store.delete(damaged)
        #expect(!exists(paths.folder(for: damagedID)))
    }

    @Test func refusesToDeleteAnUnreadableFolderOutsideItsProjects() async throws {
        let outside = temporary.url.appending(path: "Elsewhere", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)

        try await ProjectStore(paths: paths).delete(UnreadableProject(folder: outside, reason: .damaged))

        #expect(exists(outside))
    }

    @Test func treatsAProjectInAnotherProjectsFolderAsDamaged() async throws {
        let project = Project(name: "Moved", aspectRatio: .portrait)
        let folder = paths.folder(for: UUID())
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try ProjectFile.encode(project).write(to: folder.appending(path: "project.json"))

        let stored = await ProjectStore(paths: paths).loadAll()

        #expect(stored.projects.isEmpty)
        #expect(stored.unreadable.map(\.reason) == [.damaged])
    }

    // MARK: Helpers

    /// A file standing in for an image copy that finished importing.
    private func writeImport() throws -> URL {
        try FileManager.default.createDirectory(at: paths.imports, withIntermediateDirectories: true)
        let file = paths.imports.appending(path: "\(UUID().uuidString).jpg")
        try Data([0xFF, 0xD8]).write(to: file)
        return file
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    private func contents(of url: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: url.path(percentEncoded: false))) ?? []
    }
}
