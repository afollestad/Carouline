//
//  ProjectLibraryLayerImagesTests.swift
//  SwipesetTests
//

import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Swipeset

/// Pictures copied onto slides as layers.
@MainActor
struct ProjectLibraryLayerImagesTests {
    private let temporary = TemporaryDirectory("ProjectLibraryLayerImagesTests")

    private var paths: ProjectPaths {
        ProjectPaths(
            root: temporary.url.appending(path: "Support", directoryHint: .isDirectory),
            temporary: temporary.url.appending(path: "tmp", directoryHint: .isDirectory)
        )
    }

    private struct Fixture {
        let library: ProjectLibrary
        let projectID: UUID
        let slideID: UUID
    }

    /// A library with one portrait project of one slide in `layout`.
    private func makeFixture(layout: SlideLayout = .single) async throws -> Fixture {
        let library = ProjectLibrary(store: ProjectStore(paths: paths))
        await library.load()
        let projectID = library.createProject(aspectRatio: .portrait).id
        let slideID = try #require(library.addSlide(layout, to: projectID))
        return Fixture(library: library, projectID: projectID, slideID: slideID)
    }

    /// A picked file, as the picker leaves one for the import: a photo, or a cutout with a clear
    /// half when `isCutout`.
    private func picked(isCutout: Bool = false) throws -> URL {
        let folder = temporary.url.appending(path: "Picked", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "\(UUID().uuidString).\(isCutout ? "png" : "jpg")")
        if isCutout {
            try TestImages.writePNG(width: 400, height: 300, to: url)
        } else {
            try TestImages.writeJPEG(width: 1200, height: 800, to: url)
        }
        return url
    }

    private func copies(in projectID: UUID) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: paths.imagesFolder(for: projectID).path(percentEncoded: false))) ?? []
    }

    private func picture(at address: LayerAddress?, in library: ProjectLibrary) -> ImageLayer? {
        guard let address, case .image(let picture) = library.layer(at: address)?.content else {
            return nil
        }
        return picture
    }

    @Test func addsAPictureOnTopInTheSlidesMiddle() async throws {
        let fixture = try await makeFixture()
        let file = try picked()
        fixture.library.saveLayer(Layer(content: .text(TextLayer(text: "Lisbon"))), in: fixture.slideID, of: fixture.projectID)

        let address = await fixture.library.importImageLayer(into: fixture.slideID, of: fixture.projectID, assetIdentifier: "A/L0/001") {
            .file(file)
        }
        await fixture.library.flush()

        let layer = try #require(address.flatMap { fixture.library.layer(at: $0) })
        let picture = try #require(picture(at: address, in: fixture.library))
        #expect(fixture.library.project(fixture.projectID)?.slides.first?.layers.last?.id == layer.id)
        #expect(layer.placement == LayerPlacement())
        #expect(picture.image.assetIdentifier == "A/L0/001")
        #expect(picture.image.fileFormat == .jpeg)
        #expect(copies(in: fixture.projectID) == [picture.image.fileName])
        #expect(fixture.library.importingLayers.isEmpty)
        // The picked file and the staged copy go once it's in.
        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
        #expect((try? FileManager.default.contentsOfDirectory(atPath: paths.imports.path(percentEncoded: false)))?.isEmpty ?? true)
    }

    @Test func keepsACutoutsTransparencyAsAPNG() async throws {
        let fixture = try await makeFixture()
        let file = try picked(isCutout: true)

        let address = await fixture.library.importImageLayer(into: fixture.slideID, of: fixture.projectID, assetIdentifier: nil) {
            .file(file)
        }
        await fixture.library.flush()

        let picture = try #require(picture(at: address, in: fixture.library))
        #expect(picture.image.fileFormat == .png)
        #expect(copies(in: fixture.projectID) == [picture.image.fileName])
    }

    /// A panorama's own middle can fall on a cut, so a picture lands in its middle slide's.
    @Test func landsInTheMiddleOfAPanoramasMiddleSlide() async throws {
        let fixture = try await makeFixture(layout: .panorama)
        fixture.library.setSpan(3, of: fixture.slideID, in: fixture.projectID)
        let file = try picked()

        let address = await fixture.library.importImageLayer(into: fixture.slideID, of: fixture.projectID, assetIdentifier: nil) {
            .file(file)
        }

        #expect(address.flatMap { fixture.library.layer(at: $0) }?.placement.centerX == 1.5)
    }

    @Test func leavesNoCopyWhenItsSlideGoesMeanwhile() async throws {
        let fixture = try await makeFixture()
        let file = try picked()

        let address = await fixture.library.importImageLayer(into: fixture.slideID, of: fixture.projectID, assetIdentifier: nil) {
            fixture.library.deleteSlide(fixture.slideID, in: fixture.projectID)
            return .file(file)
        }
        await fixture.library.flush()

        #expect(address == nil)
        #expect(copies(in: fixture.projectID).isEmpty)
        #expect(fixture.library.importingLayers.isEmpty)
    }

    /// Pictures add rather than replace, so a second pick never takes the first's place, however
    /// long the first takes.
    @Test func landsEveryPictureFromPicksMadeTogether() async throws {
        let fixture = try await makeFixture()
        let first = try picked()
        let second = try picked(isCutout: true)
        let (gate, opener) = AsyncStream<Void>.makeStream()

        async let slow = fixture.library.importImageLayer(into: fixture.slideID, of: fixture.projectID, assetIdentifier: "slow") {
            for await _ in gate {
                break
            }
            return .file(first)
        }
        while fixture.library.importingLayers[fixture.slideID] == nil {
            await Task.yield()
        }
        let fast = await fixture.library.importImageLayer(into: fixture.slideID, of: fixture.projectID, assetIdentifier: "fast") {
            .file(second)
        }
        #expect(fixture.library.importingLayers[fixture.slideID] == 1)
        opener.yield()
        let slowAddress = await slow
        await fixture.library.flush()

        #expect(fast != nil && slowAddress != nil)
        #expect(fixture.library.project(fixture.projectID)?.slides.first?.layers.count == 2)
        #expect(copies(in: fixture.projectID).count == 2)
        #expect(fixture.library.importingLayers.isEmpty)
    }

    @Test func reportsAPictureItCantRead() async throws {
        let fixture = try await makeFixture()
        let broken = try picked().deletingLastPathComponent().appending(path: "broken.png")
        try Data("not an image".utf8).write(to: broken)

        let address = await fixture.library.importImageLayer(into: fixture.slideID, of: fixture.projectID, assetIdentifier: nil) {
            .file(broken)
        }

        #expect(address == nil)
        #expect(fixture.library.failure?.kind == .importPhoto)
        #expect(fixture.library.project(fixture.projectID)?.slides.first?.layers.isEmpty == true)
    }

    // MARK: Restoring

    /// A picture layer from asset "A/L0/001", bordered, blurred and moved, whose copy was deleted.
    private struct MissingCopy {
        let fixture: Fixture
        let address: LayerAddress
        let missing: Layer

        var missingID: UUID {
            missing.image?.id ?? UUID()
        }
    }

    private func makeFixtureMissingACopy() async throws -> MissingCopy {
        let fixture = try await makeFixture()
        let file = try picked()
        let address = try #require(await fixture.library.importImageLayer(into: fixture.slideID, of: fixture.projectID, assetIdentifier: "A/L0/001") {
            .file(file)
        })
        var layer = try #require(fixture.library.layer(at: address))
        if case .image(var picture) = layer.content {
            picture.borderWidth = 0.04
            picture.blur = 0.02
            layer.content = .image(picture)
        }
        layer.placement = LayerPlacement(centerX: 0.3, centerY: 0.7, scale: 1.5, rotation: 0.2)
        fixture.library.saveLayer(layer, in: fixture.slideID, of: fixture.projectID)
        await fixture.library.flush()
        let image = try #require(layer.image)
        try FileManager.default.removeItem(at: paths.imageFile(named: image.fileName, in: fixture.projectID))
        return MissingCopy(fixture: fixture, address: address, missing: layer)
    }

    @Test func restoresAMissingCopyKeepingTheLayersLook() async throws {
        let copy = try await makeFixtureMissingACopy()
        let library = copy.fixture.library

        let photos = MockPhotoLibrary(assets: ["A/L0/001"])
        let outcome = await library.restoreLayerImage(at: copy.address, missing: copy.missingID, from: photos, asking: false)
        await library.flush()

        let restored = try #require(library.layer(at: copy.address))
        let picture = try #require(picture(at: copy.address, in: library))
        #expect(outcome == .restored)
        #expect(restored.image?.id != copy.missing.image?.id)
        #expect(picture.image.assetIdentifier == "A/L0/001")
        #expect(picture.image.fileFormat == .jpeg)
        #expect(picture.borderWidth == 0.04 && picture.blur == 0.02)
        #expect(restored.placement == copy.missing.placement)
        #expect(copies(in: copy.fixture.projectID) == [picture.image.fileName])
    }

    /// A restore asked for by a view still showing the copy as missing, once it's been restored,
    /// leaves the good copy be.
    @Test func leavesACopyRestoredSince() async throws {
        let copy = try await makeFixtureMissingACopy()
        let library = copy.fixture.library
        let photos = MockPhotoLibrary(assets: ["A/L0/001"])
        #expect(await library.restoreLayerImage(at: copy.address, missing: copy.missingID, from: photos, asking: false) == .restored)
        let restored = library.layer(at: copy.address)

        #expect(await library.restoreLayerImage(at: copy.address, missing: copy.missingID, from: photos, asking: true) == .unavailable)
        await library.flush()

        #expect(library.layer(at: copy.address) == restored)
        #expect(copies(in: copy.fixture.projectID).count == 1)
    }

    /// A cutout comes back from its original's own data, transparency and all.
    @Test func restoresACutoutAsAPNG() async throws {
        let copy = try await makeFixtureMissingACopy()
        let library = copy.fixture.library
        let photos = MockPhotoLibrary(assets: ["A/L0/001"], cutouts: ["A/L0/001"])

        #expect(await library.restoreLayerImage(at: copy.address, missing: copy.missingID, from: photos, asking: false) == .restored)

        #expect(picture(at: copy.address, in: library)?.image.fileFormat == .png)
    }

    /// A library whose original arrives only after `fetching` runs, as a slow download from
    /// iCloud gives the user time to do something else.
    private struct SlowLibrary: PhotoLibrarySource {
        let fetching: @Sendable () async -> Void
        var canReadWithoutAsking: Bool { true }

        func requestReadAccess() async -> Bool {
            true
        }

        func image(for assetIdentifier: String, maxPixelSize: Int) async -> UIImage? {
            nil
        }

        func imageData(for assetIdentifier: String) async -> Data? {
            await fetching()
            return await MockPhotoLibrary(assets: [assetIdentifier]).imageData(for: assetIdentifier)
        }
    }

    /// A layer deleted while its restore was out stays deleted, leaving no copy.
    @Test func aRestoreLeavesADeletedLayerDeleted() async throws {
        let copy = try await makeFixtureMissingACopy()
        let library = copy.fixture.library
        let address = copy.address
        let photos = SlowLibrary {
            await MainActor.run {
                library.deleteLayer(at: address)
            }
        }

        let outcome = await library.restoreLayerImage(at: address, missing: copy.missingID, from: photos, asking: true)
        await library.flush()

        #expect(outcome == .unavailable)
        #expect(library.layer(at: address) == nil)
        #expect(copies(in: copy.fixture.projectID).isEmpty)
        #expect(library.failure == nil)
    }

    @Test func restoringALayerOnSightNeverAsksForAccess() async throws {
        let copy = try await makeFixtureMissingACopy()
        let library = copy.fixture.library
        let photos = MockPhotoLibrary(canReadWithoutAsking: false, assets: ["A/L0/001"])

        #expect(await library.restoreLayerImage(at: copy.address, missing: copy.missingID, from: photos, asking: false) == .needsAccess)
        #expect(library.layer(at: copy.address) == copy.missing)
        #expect(library.failure == nil)
    }

    @Test func reportsALayersGoneOriginalOnlyWhenAsked() async throws {
        let copy = try await makeFixtureMissingACopy()
        let library = copy.fixture.library

        #expect(await library.restoreLayerImage(at: copy.address, missing: copy.missingID, from: MockPhotoLibrary(), asking: false) == .unavailable)
        #expect(library.failure == nil)
        #expect(await library.restoreLayerImage(at: copy.address, missing: copy.missingID, from: MockPhotoLibrary(), asking: true) == .unavailable)
        #expect(library.failure?.kind == .restorePhoto)
        #expect(library.layer(at: copy.address) == copy.missing)
    }

    // MARK: The screen's import

    private func actions(
        _ fixture: Fixture,
        session: LayerSession,
        presenter: Binding<PresentationQueue<ProjectPresentation>>
    ) -> ProjectLayerActions {
        ProjectLayerActions(
            library: fixture.library,
            projectID: fixture.projectID,
            session: session,
            presenter: presenter,
            dynamicTypeSize: .large,
            select: { session.selection = $0 },
            photoSelection: { nil },
            photoLibrary: MockPhotoLibrary(),
            restoresQuietly: { _ in true }
        )
    }

    /// A picture picked from the add page lands selected, with the sheet on to its editor.
    @Test func selectsAPictureAndOpensItsEditor() async throws {
        let fixture = try await makeFixture()
        let file = try picked()
        let session = LayerSession()
        var presenter = PresentationQueue<ProjectPresentation>()
        presenter.present(.layers(fixture.slideID))
        session.sheetPath = [.add]

        await actions(fixture, session: session, presenter: Binding { presenter } set: { presenter = $0 })
            .importImage(into: fixture.slideID, assetIdentifier: nil) { .file(file) }

        let selection = try #require(session.selection)
        #expect(picture(at: selection, in: fixture.library) != nil)
        #expect(session.sheetPath == [.image(selection.layerID)])
    }

    /// Once the sheet has closed, the picture just lands, leaving the selection, and so the strip,
    /// where the user has since moved on to.
    @Test func leavesTheSelectionAloneOnceTheSheetCloses() async throws {
        let fixture = try await makeFixture()
        let file = try picked()
        let session = LayerSession()
        var presenter = PresentationQueue<ProjectPresentation>()
        presenter.present(.layers(fixture.slideID))
        session.sheetPath = [.add]

        await actions(fixture, session: session, presenter: Binding { presenter } set: { presenter = $0 })
            .importImage(into: fixture.slideID, assetIdentifier: nil) {
                await MainActor.run {
                    presenter.dismiss(.layers(fixture.slideID))
                }
                return .file(file)
            }

        #expect(session.selection == nil)
        #expect(session.sheetPath == [.add])
        #expect(fixture.library.project(fixture.projectID)?.slides.first?.layers.count == 1)
    }

    /// Something selected, or a page opened, while the picture copied stays as it is.
    @Test func leavesWhatChangedWhileItCopied() async throws {
        let fixture = try await makeFixture()
        let file = try picked()
        let session = LayerSession()
        var presenter = PresentationQueue<ProjectPresentation>()
        presenter.present(.layers(fixture.slideID))
        session.sheetPath = [.add]
        let other = LayerAddress(projectID: fixture.projectID, slideID: fixture.slideID, layerID: UUID())

        await actions(fixture, session: session, presenter: Binding { presenter } set: { presenter = $0 })
            .importImage(into: fixture.slideID, assetIdentifier: nil) {
                session.selection = other
                session.sheetPath = []
                return .file(file)
            }

        #expect(session.selection == other)
        #expect(session.sheetPath.isEmpty)
        #expect(fixture.library.project(fixture.projectID)?.slides.first?.layers.count == 1)
    }
}
