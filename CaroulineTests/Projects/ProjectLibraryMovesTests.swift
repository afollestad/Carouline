//
//  ProjectLibraryMovesTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

/// Photos moved and swapped between cells, and brought in by a drop.
@MainActor
struct ProjectLibraryMovesTests {
    private let temporary = TemporaryDirectory("ProjectLibraryMovesTests")

    private var paths: ProjectPaths {
        ProjectPaths(
            root: temporary.url.appending(path: "Support", directoryHint: .isDirectory),
            temporary: temporary.url.appending(path: "tmp", directoryHint: .isDirectory)
        )
    }

    /// A library with one portrait project of a slide for each of `layouts`, and each slide's
    /// cells.
    private func makeLibrary(_ layouts: [SlideLayout] = [.twoColumns]) async throws -> (ProjectLibrary, [[CellAddress]]) {
        let library = ProjectLibrary(store: ProjectStore(paths: paths))
        await library.load()
        let projectID = library.createProject(aspectRatio: .portrait).id
        let cells = try layouts.map { layout in
            let slideID = try #require(library.addSlide(layout, to: projectID))
            return (0..<layout.grid.cells.count).map { CellAddress(projectID: projectID, slideID: slideID, index: $0) }
        }
        return (library, cells)
    }

    /// A picked photo, as the picker leaves one for the import.
    private func picked(_ assetIdentifier: String? = nil, width: Int = 1200, height: Int = 800) throws -> IncomingPhoto {
        let folder = temporary.url.appending(path: "Picked", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "\(UUID().uuidString).jpg")
        try TestImages.writeJPEG(width: width, height: height, to: url)
        return IncomingPhoto(assetIdentifier: assetIdentifier) { .file(url) }
    }

    /// Imports a photo into the cell at `address` and returns it.
    @discardableResult
    private func fill(_ address: CellAddress, in library: ProjectLibrary, width: Int = 1200, height: Int = 800) async throws -> PlacedImage {
        await library.importPhoto(into: address, assetIdentifier: nil, from: try picked(width: width, height: height).load)
        return try #require(library.photo(at: address))
    }

    private func copies(in projectID: UUID) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: paths.imagesFolder(for: projectID).path(percentEncoded: false))) ?? [])
    }

    @Test func movesAPhotoToAnEmptyCellKeepingItsCopyAndFraming() async throws {
        let (library, cells) = try await makeLibrary()
        let photo = try await fill(cells[0][0], in: library)
        library.setCrop(ImageCrop(scale: 2, centerX: 0.3, centerY: 0.6), at: cells[0][0])
        await library.flush()
        let before = copies(in: cells[0][0].projectID)

        #expect(library.movePhoto(from: cells[0][0], imageID: photo.id, to: cells[0][1]))
        await library.flush()

        #expect(library.photo(at: cells[0][0]) == nil)
        #expect(library.photo(at: cells[0][1])?.id == photo.id)
        #expect(library.photo(at: cells[0][1])?.crop == ImageCrop(scale: 2, centerX: 0.3, centerY: 0.6))
        #expect(copies(in: cells[0][0].projectID) == before)
    }

    @Test func swapsTwoPhotosAcrossSlides() async throws {
        let (library, cells) = try await makeLibrary([.twoColumns, .single])
        let first = try await fill(cells[0][1], in: library)
        let second = try await fill(cells[1][0], in: library)

        #expect(library.movePhoto(from: cells[0][1], imageID: first.id, to: cells[1][0]))
        await library.flush()

        #expect(library.photo(at: cells[1][0])?.id == first.id)
        #expect(library.photo(at: cells[0][1])?.id == second.id)
        #expect(copies(in: cells[0][0].projectID).count == 2)
    }

    /// A photo moving into a panorama shows all of itself; an empty panorama fits it, and one with
    /// a photo keeps its width.
    @Test func framesAPhotoMovingIntoAPanoramaWhole() async throws {
        let (library, cells) = try await makeLibrary([.twoColumns, .panorama])
        let panorama = cells[1][0]
        let wide = try await fill(cells[0][0], in: library, width: 6000, height: 1500)
        library.setCrop(ImageCrop(scale: 2, centerX: 0.3, centerY: 0.6), at: cells[0][0])
        let span = { library.project(panorama.projectID)?.slides[1].span }

        library.movePhoto(from: cells[0][0], imageID: wide.id, to: panorama)
        #expect(span() == 5)
        #expect(library.photo(at: panorama)?.crop == ImageCrop())
        let other = try await fill(cells[0][1], in: library)
        library.movePhoto(from: cells[0][1], imageID: other.id, to: panorama)

        #expect(span() == 5)
        #expect(library.photo(at: panorama)?.id == other.id)
        #expect(library.photo(at: cells[0][1])?.id == wide.id)
        // The saves it made reach the disk before the suite's directory goes.
        await library.flush()
    }

    @Test func refusesAMoveThatCantHappen() async throws {
        let (library, cells) = try await makeLibrary([.grid])
        let photo = try await fill(cells[0][0], in: library)
        let gone = CellAddress(projectID: cells[0][0].projectID, slideID: UUID(), index: 0)

        #expect(!library.movePhoto(from: cells[0][0], imageID: photo.id, to: cells[0][0]))
        #expect(!library.movePhoto(from: cells[0][0], imageID: UUID(), to: cells[0][1]))
        #expect(!library.movePhoto(from: cells[0][0], imageID: photo.id, to: gone))
        library.importingCells.insert(cells[0][2])
        #expect(!library.movePhoto(from: cells[0][0], imageID: photo.id, to: cells[0][2]))
        #expect(library.photo(at: cells[0][0])?.id == photo.id)
        // The saves it made reach the disk before the suite's directory goes.
        await library.flush()
    }

    /// A photo dragged in from another project's window is copied, leaving that one's photo.
    @Test func landsAPhotoFromAnotherProjectAsAClone() async throws {
        let (library, cells) = try await makeLibrary()
        let photo = try await fill(cells[0][0], in: library)
        let otherID = library.createProject(aspectRatio: .square).id
        let otherSlideID = try #require(library.addSlide(.single, to: otherID))
        let destination = CellAddress(projectID: otherID, slideID: otherSlideID, index: 0)

        await library.land(.cell(cells[0][0], imageID: photo.id), at: destination)
        await library.flush()

        let clone = try #require(library.photo(at: destination))
        #expect(clone.id != photo.id)
        #expect(library.photo(at: cells[0][0])?.id == photo.id)
        #expect(copies(in: otherID) == [clone.fileName])
    }

    /// Photos dropped on an empty cell fill it and the slide's other empty cells in reading order,
    /// as a pick does, and the tray takes the rest.
    @Test func dropsFillTheSlideThenTheTray() async throws {
        let (library, cells) = try await makeLibrary([.threeRows])
        try await fill(cells[0][0], in: library)

        await library.importPhotos([try picked("a"), try picked("b"), try picked("c")], into: cells[0][2])

        #expect(library.photo(at: cells[0][1])?.assetIdentifier == "a")
        #expect(library.photo(at: cells[0][2])?.assetIdentifier == "b")
        #expect(library.project(cells[0][0].projectID)?.tray.map(\.image.assetIdentifier) == ["c"])
        // The saves it made reach the disk before the suite's directory goes.
        await library.flush()
    }

    @Test func findsTheFirstEmptyCellNotImporting() async throws {
        let (library, cells) = try await makeLibrary([.grid])
        try await fill(cells[0][0], in: library)
        library.importingCells.insert(cells[0][1])

        #expect(library.emptyCell(in: cells[0][0].slideID, of: cells[0][0].projectID) == cells[0][2])
        #expect(library.emptyCell(in: UUID(), of: cells[0][0].projectID) == nil)
        // The saves it made reach the disk before the suite's directory goes.
        await library.flush()
    }
}
