//
//  ProjectLibraryLayersTests.swift
//  SwipesetTests
//

import Foundation
import Testing
@testable import Swipeset

@MainActor
struct ProjectLibraryLayersTests {
    private let temporary = TemporaryDirectory("ProjectLibraryLayersTests")

    private var paths: ProjectPaths {
        ProjectPaths(
            root: temporary.url.appending(path: "Support", directoryHint: .isDirectory),
            temporary: temporary.url.appending(path: "tmp", directoryHint: .isDirectory)
        )
    }

    /// A library with a project holding one slide.
    private struct Fixture {
        let library: ProjectLibrary
        let projectID: UUID
        let slideID: UUID
    }

    private func makeLibrary(_ layout: SlideLayout = .single) async throws -> Fixture {
        let library = ProjectLibrary(store: ProjectStore(paths: paths))
        await library.load()
        let projectID = library.createProject(aspectRatio: .portrait).id
        let slideID = try #require(library.addSlide(layout, to: projectID))
        return Fixture(library: library, projectID: projectID, slideID: slideID)
    }

    private func layers(_ library: ProjectLibrary, _ projectID: UUID, _ slideID: UUID) -> [Layer] {
        library.project(projectID)?.slides.first { $0.id == slideID }?.layers ?? []
    }

    private func text(_ string: String = "Hello", placement: LayerPlacement = LayerPlacement()) -> Layer {
        Layer(content: .text(TextLayer(text: string)), placement: placement)
    }

    /// A picture layer whose copy is in the project's folder, as an import leaves it.
    private func picture(in library: ProjectLibrary, projectID: UUID) async throws -> Layer {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 40, pixelHeight: 20, fileFormat: .png)
        try FileManager.default.createDirectory(at: paths.imports, withIntermediateDirectories: true)
        let copy = paths.imports.appending(path: image.id.uuidString)
        try Data([0x89, 0x50]).write(to: copy)
        await library.flush()
        #expect(try await library.store.adoptImage(at: copy, as: image.fileName, in: projectID))
        return Layer(content: .image(ImageLayer(image: image)))
    }

    private func copyExists(_ image: PlacedImage?, in projectID: UUID) -> Bool {
        guard let image else {
            return false
        }
        return FileManager.default.fileExists(atPath: paths.imageFile(named: image.fileName, in: projectID).path(percentEncoded: false))
    }

    private func address(_ layer: Layer, _ projectID: UUID, _ slideID: UUID) -> LayerAddress {
        LayerAddress(projectID: projectID, slideID: slideID, layerID: layer.id)
    }

    @Test func addsLayersOnTopAndReplacesThemInPlace() async throws {
        let fixture = try await makeLibrary()
        let library = fixture.library
        let projectID = fixture.projectID
        let slideID = fixture.slideID
        let first = text("First")
        let second = text("Second")

        #expect(library.saveLayer(first, in: slideID, of: projectID))
        #expect(library.saveLayer(second, in: slideID, of: projectID))
        var edited = first
        edited.content = .text(TextLayer(text: "Edited"))
        library.saveLayer(edited, in: slideID, of: projectID)

        #expect(layers(library, projectID, slideID) == [edited, second])
        await library.flush()
        #expect(await ProjectStore(paths: paths).loadAll().projects.first?.slides.first?.layers == [edited, second])
    }

    @Test func refusesASlideThatsGone() async throws {
        let fixture = try await makeLibrary()

        #expect(!fixture.library.saveLayer(text(), in: UUID(), of: fixture.projectID))
    }

    /// No text layer is ever saved without text: one left blank goes.
    @Test func blankTextDeletesItsLayer() async throws {
        let fixture = try await makeLibrary()
        let library = fixture.library
        let projectID = fixture.projectID
        let slideID = fixture.slideID
        let layer = text()
        library.saveLayer(layer, in: slideID, of: projectID)

        library.setContent(.text(TextLayer(text: "  ")), at: address(layer, projectID, slideID))
        library.saveLayer(text(" "), in: slideID, of: projectID)

        #expect(layers(library, projectID, slideID).isEmpty)
    }

    /// Per the storage rules, a copy goes only once the JSON that stopped referring to it is saved.
    @Test func deletesAReplacedOrDeletedPicturesCopyOnceSaved() async throws {
        let fixture = try await makeLibrary()
        let library = fixture.library
        let projectID = fixture.projectID
        let slideID = fixture.slideID
        let original = try await picture(in: library, projectID: projectID)
        library.saveLayer(original, in: slideID, of: projectID)
        let replacement = try await picture(in: library, projectID: projectID)
        var replaced = original
        replaced.content = replacement.content

        library.saveLayer(replaced, in: slideID, of: projectID)
        await library.flush()

        #expect(!copyExists(original.image, in: projectID))
        #expect(copyExists(replacement.image, in: projectID))
        library.deleteLayer(at: address(replaced, projectID, slideID))
        await library.flush()
        #expect(!copyExists(replacement.image, in: projectID))
        #expect(layers(library, projectID, slideID).isEmpty)
    }

    /// An editor changes a picture's border and blur, never which picture it shows, and never
    /// undoes a move made while it was open.
    @Test func newContentKeepsThePictureAndThePlacement() async throws {
        let fixture = try await makeLibrary()
        let library = fixture.library
        let projectID = fixture.projectID
        let slideID = fixture.slideID
        let layer = try await picture(in: library, projectID: projectID)
        library.saveLayer(layer, in: slideID, of: projectID)
        let moved = LayerPlacement(centerX: 0.2, centerY: 0.3)
        library.setPlacement(moved, at: address(layer, projectID, slideID))
        let other = PlacedImage(assetIdentifier: nil, pixelWidth: 1, pixelHeight: 1)

        library.setContent(.image(ImageLayer(image: other, borderWidth: 0.05, blur: 0.02)), at: address(layer, projectID, slideID))

        let saved = try #require(layers(library, projectID, slideID).first)
        #expect(saved.image == layer.image)
        #expect(saved.placement == moved)
        guard case .image(let image) = saved.content else {
            Issue.record("Expected an image")
            return
        }
        #expect(image.borderWidth == 0.05)
        #expect(image.blur == 0.02)
        await library.flush()
        #expect(copyExists(layer.image, in: projectID))
    }

    @Test func keepsAPlacementOnTheSlideAndSkipsAnUnchangedOne() async throws {
        let store = CountingStore()
        let library = ProjectLibrary(store: store, projects: [])
        let projectID = library.createProject(aspectRatio: .portrait).id
        let slideID = try #require(library.addSlide(.single, to: projectID))
        let layer = text()
        library.saveLayer(layer, in: slideID, of: projectID)
        await library.flush()
        let saves = await store.saves

        library.setPlacement(LayerPlacement(centerX: 3, scale: 9), at: address(layer, projectID, slideID))
        library.setPlacement(LayerPlacement(centerX: 1, scale: 4), at: address(layer, projectID, slideID))
        library.saveLayer(try #require(layers(library, projectID, slideID).first), in: slideID, of: projectID)
        await library.flush()

        #expect(layers(library, projectID, slideID).first?.placement == LayerPlacement(centerX: 1, scale: 4))
        // The second placement, the first's clamped twin, and the same layer saved again write nothing.
        #expect(await store.saves == saves + 1)
    }

    @Test func movesLayersWithinTheStack() async throws {
        let fixture = try await makeLibrary()
        let library = fixture.library
        let projectID = fixture.projectID
        let slideID = fixture.slideID
        let bottom = text("Bottom")
        let top = text("Top")
        library.saveLayer(bottom, in: slideID, of: projectID)
        library.saveLayer(top, in: slideID, of: projectID)

        library.moveLayer(at: address(top, projectID, slideID), by: 1)
        #expect(layers(library, projectID, slideID).map(\.id) == [bottom.id, top.id])
        library.moveLayer(at: address(bottom, projectID, slideID), by: 1)
        #expect(layers(library, projectID, slideID).map(\.id) == [top.id, bottom.id])
        library.moveLayer(at: address(top, projectID, slideID), by: -1)
        #expect(layers(library, projectID, slideID).map(\.id) == [top.id, bottom.id])
    }

    /// A reorder from a list another window has since changed would lose or repeat layers.
    @Test func reordersOnlyByEveryLayerOnce() async throws {
        let fixture = try await makeLibrary()
        let library = fixture.library
        let projectID = fixture.projectID
        let slideID = fixture.slideID
        let first = text("1")
        let second = text("2")
        let third = text("3")
        for layer in [first, second, third] {
            library.saveLayer(layer, in: slideID, of: projectID)
        }

        library.reorderLayers(in: slideID, of: projectID, to: [first.id, second.id])
        library.reorderLayers(in: slideID, of: projectID, to: [first.id, first.id, second.id])
        library.reorderLayers(in: slideID, of: projectID, to: [first.id, second.id, UUID()])
        #expect(layers(library, projectID, slideID).map(\.id) == [first.id, second.id, third.id])
        library.reorderLayers(in: slideID, of: projectID, to: [third.id, first.id, second.id])
        #expect(layers(library, projectID, slideID).map(\.id) == [third.id, first.id, second.id])
    }

    @Test func narrowingAPanoramaKeepsItsLayersOnIt() async throws {
        let fixture = try await makeLibrary(.panorama)
        let library = fixture.library
        let projectID = fixture.projectID
        let slideID = fixture.slideID
        library.setSpan(5, of: slideID, in: projectID)
        let layer = text(placement: LayerPlacement(centerX: 4.5))
        library.saveLayer(layer, in: slideID, of: projectID)

        library.setSpan(3, of: slideID, in: projectID)

        #expect(layers(library, projectID, slideID).first?.placement.centerX == 2.5)
    }

    @Test func changingLayoutKeepsLayersAndBlur() async throws {
        let fixture = try await makeLibrary(.panorama)
        let library = fixture.library
        let projectID = fixture.projectID
        let slideID = fixture.slideID
        let layer = text(placement: LayerPlacement(centerX: 2.25))
        library.saveLayer(layer, in: slideID, of: projectID)
        library.update(projectID) { $0.slides[0].blur = 0.02 }

        library.changeLayout(of: slideID, in: projectID, to: .grid)

        let slide = try #require(library.project(projectID)?.slides.first)
        #expect(slide.layers.map(\.id) == [layer.id])
        #expect(slide.layers.first?.placement.centerX == 0.25)
        #expect(slide.blur == 0.02)
    }

    @Test func deletingASlideDeletesItsLayersCopies() async throws {
        let fixture = try await makeLibrary()
        let library = fixture.library
        let projectID = fixture.projectID
        let slideID = fixture.slideID
        let layer = try await picture(in: library, projectID: projectID)
        library.saveLayer(layer, in: slideID, of: projectID)

        library.deleteSlide(slideID, in: projectID)
        await library.flush()

        #expect(!copyExists(layer.image, in: projectID))
    }

    /// A slide's blur is kept in range, and its slider's drag saves once, as it's let go, and
    /// not at all when it's left where it was.
    @Test func blursASlideOncePerDrag() async throws {
        let store = CountingStore()
        let library = ProjectLibrary(store: store, projects: [])
        let projectID = library.createProject(aspectRatio: .portrait).id
        let slideID = try #require(library.addSlide(.single, to: projectID))
        await library.flush()
        let saves = await store.saves
        let session = LayerSession()

        session.beginSlideBlur(0, on: slideID)
        for step in 1...20 {
            session.slideBlur = Double(step) / 100
        }
        session.endSlideBlur(to: library, projectID: projectID)
        library.setBlur(Slide.maximumBlur, of: slideID, in: projectID)
        await library.flush()

        #expect(library.project(projectID)?.slides.first?.blur == Slide.maximumBlur)
        #expect(await store.saves == saves + 1)
        #expect(session.blurringSlideID == nil)
    }
}
