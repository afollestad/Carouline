//
//  ProjectLibrarySlidesTests.swift
//  CaroulineTests
//

import Foundation
import Testing
@testable import Carouline

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
        #expect(!exists(paths.imageFile(named: image.fileName, in: projectID)))
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
        #expect(exists(paths.imageFile(named: kept.fileName, in: projectID)))
        #expect(!exists(paths.imageFile(named: dropped.fileName, in: projectID)))
    }

    @Test func addsAPanoramaAcrossTheDefaultSpan() async throws {
        let (library, projectID) = await makeLibrary()
        _ = try #require(library.addSlide(.panorama, to: projectID))

        let panorama = try #require(slides(library, projectID).first)
        #expect(panorama.span == Slide.defaultPanoramaSpan)
        #expect(panorama.cells.count == 1)
    }

    @Test func aSlideTurnedPanoramaFitsItsFirstPhotoAndDropsTheRest() async throws {
        let (library, projectID) = await makeLibrary()
        let slideID = try #require(library.addSlide(.grid, to: projectID))
        let kept = try await placeImage(in: library, projectID: projectID, slideID: slideID, cell: 0, width: 400, height: 100)
        let dropped = try await placeImage(in: library, projectID: projectID, slideID: slideID, cell: 2)
        library.setCrop(ImageCrop(scale: 2, centerX: 0.3, centerY: 0.5), at: CellAddress(projectID: projectID, slideID: slideID, index: 0))
        let slide = try #require(slides(library, projectID).first)
        #expect(ProjectLibrary.photosLost(changing: slide, to: .panorama) == 1)

        library.changeLayout(of: slideID, in: projectID, to: .panorama)
        await library.flush()

        let panorama = try #require(slides(library, projectID).first)
        #expect(panorama.layout == .panorama)
        #expect(panorama.span == 5)
        #expect(panorama.cells.map(\.image?.id) == [kept.id])
        #expect(panorama.cells[0].image?.crop == ImageCrop())
        #expect(!exists(paths.imageFile(named: dropped.fileName, in: projectID)))
    }

    @Test func aPanoramaTurnedSlideKeepsItsPhotoInTheFirstCell() async throws {
        let (library, projectID) = await makeLibrary()
        let slideID = try #require(library.addSlide(.panorama, to: projectID))
        let image = try await placeImage(in: library, projectID: projectID, slideID: slideID, cell: 0)

        library.changeLayout(of: slideID, in: projectID, to: .twoColumns)
        await library.flush()

        let slide = try #require(slides(library, projectID).first)
        #expect(slide.span == 1)
        #expect(slide.cells.map(\.image?.id) == [image.id, nil])
    }

    @Test func setsAPanoramasSpanWithinBounds() async throws {
        let (library, projectID) = await makeLibrary()
        let panoramaID = try #require(library.addSlide(.panorama, to: projectID))
        let slideID = try #require(library.addSlide(.single, to: projectID))

        library.setSpan(1, of: panoramaID, in: projectID)
        #expect(slides(library, projectID)[0].span == 2)
        library.setSpan(11, of: panoramaID, in: projectID)
        #expect(slides(library, projectID)[0].span == 10)
        library.setSpan(4, of: slideID, in: projectID)
        #expect(slides(library, projectID)[1].span == 1)
        let modified = library.project(projectID)?.modifiedAt
        library.setSpan(10, of: panoramaID, in: projectID)
        #expect(library.project(projectID)?.modifiedAt == modified)
        await library.flush()
    }

    /// A slide's style saves on it alone, and the same style and blur don't save at all.
    @Test func savesASlidesStyleAndIgnoresTheSameOne() async throws {
        let (library, projectID) = await makeLibrary()
        let first = try #require(library.addSlide(.single, to: projectID))
        let second = try #require(library.addSlide(.grid, to: projectID))
        let modified = library.project(projectID)?.modifiedAt
        let style = SlideStyle(spacing: 0.02, border: 0.03, background: .black)

        library.setStyle(.standard, blur: 0, of: second, in: projectID)
        #expect(library.project(projectID)?.modifiedAt == modified)
        library.setStyle(style, blur: 0, of: second, in: projectID)
        await library.flush()

        let saved = await ProjectStore(paths: paths).loadAll().projects.first?.slides ?? []
        #expect(saved.map(\.id) == [first, second])
        #expect(saved.map(\.style) == [.standard, style])
    }

    /// A new slide takes the last one's style without its border, and a project's first the
    /// standard one.
    @Test func givesANewSlideTheLastOnesStyleWithoutItsBorder() async throws {
        let (library, projectID) = await makeLibrary()
        let first = try #require(library.addSlide(.single, to: projectID))
        #expect(slides(library, projectID).map(\.style) == [.standard])
        let style = SlideStyle(spacing: 0.03, border: 0.04, background: .black)
        library.setStyle(style, blur: 0, of: first, in: projectID)

        library.addSlide(.grid, to: projectID)

        #expect(slides(library, projectID).map(\.style) == [style, SlideStyle(spacing: 0.03, border: 0, background: .black)])
    }

    /// Every slide takes the style and keeps its own blur, and slides already alike don't save.
    @Test func appliesASlidesStyleToEverySlide() async throws {
        let (library, projectID) = await makeLibrary()
        let first = try #require(library.addSlide(.single, to: projectID))
        let second = try #require(library.addSlide(.panorama, to: projectID))
        let style = SlideStyle(spacing: 0.03, border: 0.02, background: .black)
        library.setStyle(.standard, blur: 0.02, of: first, in: projectID)
        library.setStyle(style, blur: 0.01, of: second, in: projectID)
        #expect(library.project(projectID)?.slides(besides: second, allHave: style) == false)

        library.applyStyle(of: second, toAllIn: projectID)

        let project = try #require(library.project(projectID))
        #expect(project.slides.map(\.style) == [style, style])
        #expect(project.slides.map(\.blur) == [0.02, 0.01])
        #expect(project.slides(besides: second, allHave: style))
        let modified = project.modifiedAt
        library.applyStyle(of: first, toAllIn: projectID)
        #expect(library.project(projectID)?.modifiedAt == modified)
        await library.flush()
        #expect(await ProjectStore(paths: paths).loadAll().projects.first?.slides.map(\.style) == [style, style])
    }

    // MARK: Helpers

    /// Puts a copy on disk and in cell `cell` of the slide, as an import would, sized as a
    /// `width` by `height` photo.
    private func placeImage(
        in library: ProjectLibrary,
        projectID: UUID,
        slideID: UUID,
        cell: Int,
        width: Int = 10,
        height: Int = 10
    ) async throws -> PlacedImage {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: width, pixelHeight: height)
        try FileManager.default.createDirectory(at: paths.imports, withIntermediateDirectories: true)
        let copy = paths.imports.appending(path: "\(image.id).jpg")
        try Data([0xFF, 0xD8]).write(to: copy)
        await library.flush()
        #expect(try await library.store.adoptImage(at: copy, as: image.fileName, in: projectID))
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
