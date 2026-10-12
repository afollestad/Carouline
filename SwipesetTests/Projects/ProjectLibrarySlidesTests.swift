//
//  ProjectLibrarySlidesTests.swift
//  SwipesetTests
//

import Foundation
import Testing
@testable import Swipeset

@MainActor
struct ProjectLibrarySlidesTests {
    private let temporary = TemporaryDirectory("ProjectLibrarySlidesTests")

    private var paths: ProjectPaths {
        ProjectPaths(
            root: temporary.url.appending(path: "Support", directoryHint: .isDirectory),
            temporary: temporary.url.appending(path: "tmp", directoryHint: .isDirectory)
        )
    }

    private func makeLibrary() async -> (ProjectLibrary, UUID) {
        let library = ProjectLibrary(store: ProjectStore(paths: paths))
        await library.load()
        return (library, library.createProject(aspectRatio: .portrait).id)
    }

    private func slides(_ library: ProjectLibrary, _ projectID: UUID) -> [Slide] {
        library.project(projectID)?.slides ?? []
    }

    @Test func addsSlidesAtTheEnd() async throws {
        let (library, projectID) = await makeLibrary()
        let first = try #require(library.addSlide(.single, to: projectID))
        let second = try #require(library.addSlide(.grid, to: projectID))

        #expect(slides(library, projectID).map(\.id) == [first, second])
        #expect(slides(library, projectID)[1].cells.count == 4)
        await library.flush()
        #expect(await ProjectStore(paths: paths).loadAll().projects.first?.slides.count == 2)
    }

    @Test func movesSlidesWithinBounds() async throws {
        let (library, projectID) = await makeLibrary()
        let first = try #require(library.addSlide(.single, to: projectID))
        let second = try #require(library.addSlide(.twoRows, to: projectID))
        let third = try #require(library.addSlide(.grid, to: projectID))

        library.moveSlide(third, in: projectID, by: -1)
        #expect(slides(library, projectID).map(\.id) == [first, third, second])
        library.moveSlide(first, in: projectID, by: 1)
        #expect(slides(library, projectID).map(\.id) == [third, first, second])
        library.moveSlide(third, in: projectID, by: -1)
        library.moveSlide(second, in: projectID, by: 1)
        #expect(slides(library, projectID).map(\.id) == [third, first, second])
        await library.flush()
    }

    @Test func deletingASlideDeletesItsPhotos() async throws {
        let (library, projectID) = await makeLibrary()
        let slideID = try #require(library.addSlide(.twoColumns, to: projectID))
        let image = try await placeImage(in: library, projectID: projectID, slideID: slideID, cell: 1)

        library.deleteSlide(slideID, in: projectID)
        await library.flush()

        #expect(slides(library, projectID).isEmpty)
        #expect(!exists(paths.imageFile(image.id, in: projectID)))
    }

    @Test func changingLayoutPacksPhotosAndDeletesTheOverflow() async throws {
        let (library, projectID) = await makeLibrary()
        let slideID = try #require(library.addSlide(.grid, to: projectID))
        let kept = try await placeImage(in: library, projectID: projectID, slideID: slideID, cell: 1)
        let dropped = try await placeImage(in: library, projectID: projectID, slideID: slideID, cell: 3)
        let slide = try #require(slides(library, projectID).first)
        #expect(ProjectLibrary.photosLost(changing: slide, to: .single) == 1)
        #expect(ProjectLibrary.photosLost(changing: slide, to: .twoRows) == 0)

        library.changeLayout(of: slideID, in: projectID, to: .single)
        await library.flush()

        let changed = try #require(slides(library, projectID).first)
        #expect(changed.layout == .single)
        #expect(changed.cells.map(\.image?.id) == [kept.id])
        #expect(exists(paths.imageFile(kept.id, in: projectID)))
        #expect(!exists(paths.imageFile(dropped.id, in: projectID)))
    }

    @Test func savesANewStyleAndIgnoresTheSameOne() async throws {
        let (library, projectID) = await makeLibrary()
        let modified = library.project(projectID)?.modifiedAt
        let style = SlideStyle(spacing: 0.02, border: 0.03, background: .black)

        library.setStyle(.standard, of: projectID)
        #expect(library.project(projectID)?.modifiedAt == modified)
        library.setStyle(style, of: projectID)
        await library.flush()

        #expect(await ProjectStore(paths: paths).loadAll().projects.first?.style == style)
    }

    // MARK: Helpers

    /// Puts a copy on disk and in cell `cell` of the slide, as an import would.
    private func placeImage(in library: ProjectLibrary, projectID: UUID, slideID: UUID, cell: Int) async throws -> PlacedImage {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10)
        try FileManager.default.createDirectory(at: paths.imports, withIntermediateDirectories: true)
        let copy = paths.imports.appending(path: "\(image.id).jpg")
        try Data([0xFF, 0xD8]).write(to: copy)
        await library.flush()
        #expect(try await library.store.adoptImage(at: copy, as: image.id, in: projectID))
        library.update(projectID) { project in
            if let index = project.slides.firstIndex(where: { $0.id == slideID }) {
                project.slides[index].cells[cell].image = image
            }
        }
        return image
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
}
