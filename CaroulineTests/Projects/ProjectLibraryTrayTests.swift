//
//  ProjectLibraryTrayTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

/// Photos gathered into a tray, placed from it, and restored.
@MainActor
struct ProjectLibraryTrayTests {
    private let temporary = TemporaryDirectory("ProjectLibraryTrayTests")

    private var paths: ProjectPaths {
        ProjectPaths(
            root: temporary.url.appending(path: "Support", directoryHint: .isDirectory),
            temporary: temporary.url.appending(path: "tmp", directoryHint: .isDirectory)
        )
    }

    /// A library with one portrait project of one slide in `layout`, and the slide's first cell.
    private func makeLibrary(layout: SlideLayout = .twoColumns) async throws -> (ProjectLibrary, CellAddress) {
        let library = ProjectLibrary(store: ProjectStore(paths: paths))
        await library.load()
        let projectID = library.createProject(aspectRatio: .portrait).id
        let slideID = try #require(library.addSlide(layout, to: projectID))
        return (library, CellAddress(projectID: projectID, slideID: slideID, index: 0))
    }

    /// A picked photo, as the picker leaves one for the import.
    private func picked(_ assetIdentifier: String? = nil, width: Int = 1200, height: Int = 800) throws -> IncomingPhoto {
        let folder = temporary.url.appending(path: "Picked", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "\(UUID().uuidString).jpg")
        try TestImages.writeJPEG(width: width, height: height, to: url)
        return IncomingPhoto(assetIdentifier: assetIdentifier) { .file(url) }
    }

    /// A library, the first cell of its project's slide, and the photo its tray holds.
    private struct TrayFixture {
        let library: ProjectLibrary
        let address: CellAddress
        let photo: TrayPhoto
    }

    /// A library whose tray holds one wide photo from asset "A/L0/001".
    private func makeLibraryWithATrayPhoto(layout: SlideLayout = .twoColumns) async throws -> TrayFixture {
        let (library, address) = try await makeLibrary(layout: layout)
        await library.importToTray([try picked("A/L0/001", width: 6000, height: 1500)], in: address.projectID)
        let photo = try #require(library.project(address.projectID)?.tray.first)
        return TrayFixture(library: library, address: address, photo: photo)
    }

    private func copyExists(_ image: PlacedImage?, in projectID: UUID) -> Bool {
        image.map { FileManager.default.fileExists(atPath: paths.imageFile(named: $0.fileName, in: projectID).path(percentEncoded: false)) } ?? false
    }

    private func deleteCopy(of image: PlacedImage, in projectID: UUID) throws {
        try FileManager.default.removeItem(at: paths.imageFile(named: image.fileName, in: projectID))
    }

    // MARK: Gathering

    /// The photos land in the order they were picked, however their copies finish.
    @Test func gathersPhotosInTheOrderTheyWerePicked() async throws {
        let (library, address) = try await makeLibrary()
        let (gate, opener) = AsyncStream<Void>.makeStream()
        let slow = try picked("slow")
        let gated = IncomingPhoto(assetIdentifier: "slow") {
            for await _ in gate {
                break
            }
            return try await slow.load()
        }
        let fast = try picked("fast")

        async let gathering: Void = library.importToTray([gated, fast], in: address.projectID)
        while library.project(address.projectID)?.tray.isEmpty != false {
            await Task.yield()
        }
        #expect(library.importingTray[address.projectID] == 1)
        opener.yield()
        await gathering
        await library.flush()

        let tray = try #require(library.project(address.projectID)?.tray)
        #expect(tray.map(\.image.assetIdentifier) == ["slow", "fast"])
        #expect(tray.allSatisfy { copyExists($0.image, in: address.projectID) })
        #expect(library.importingTray.isEmpty)
        #expect(await ProjectStore(paths: paths).loadAll().projects.first?.tray == tray)
    }

    @Test func gathersALibraryPhotoOnlyOnce() async throws {
        let (library, address) = try await makeLibrary()

        await library.importToTray([try picked("A/L0/001"), try picked("A/L0/001"), try picked()], in: address.projectID)
        await library.importToTray([try picked("A/L0/001")], in: address.projectID)

        #expect(library.project(address.projectID)?.tray.map(\.image.assetIdentifier) == ["A/L0/001", nil])
        // The saves it made reach the disk before the suite's directory goes.
        await library.flush()
    }

    @Test func gathersNothingIntoADeletedProject() async throws {
        let (library, address) = try await makeLibrary()
        let photo = try picked()

        await library.importToTray([IncomingPhoto(assetIdentifier: nil) {
            await library.delete(address.projectID)
            return try await photo.load()
        }], in: address.projectID)
        await library.flush()

        #expect(!FileManager.default.fileExists(atPath: paths.folder(for: address.projectID).path(percentEncoded: false)))
        #expect(library.importingTray.isEmpty)
    }

    @Test func reportsAPhotoItCantGather() async throws {
        let (library, address) = try await makeLibrary()
        let broken = temporary.url.appending(path: "broken.jpg")
        try FileManager.default.createDirectory(at: temporary.url, withIntermediateDirectories: true)
        try Data("not an image".utf8).write(to: broken)

        await library.importToTray([IncomingPhoto(assetIdentifier: nil) { .file(broken) }], in: address.projectID)

        #expect(library.project(address.projectID)?.tray.isEmpty == true)
        #expect(library.failure?.kind == .importPhoto)
        #expect(library.importingTray.isEmpty)
        // The saves it made reach the disk before the suite's directory goes.
        await library.flush()
    }

    /// The cells it filled keep their clones.
    @Test func removingATrayPhotoDeletesItsCopyAlone() async throws {
        let fixture = try await makeLibraryWithATrayPhoto()
        let library = fixture.library, address = fixture.address, photo = fixture.photo
        await library.land(.tray(projectID: address.projectID, photoID: photo.id), at: address)

        library.removeFromTray(photo.id, in: address.projectID)
        await library.flush()

        #expect(library.project(address.projectID)?.tray.isEmpty == true)
        #expect(!copyExists(photo.image, in: address.projectID))
        #expect(copyExists(library.photo(at: address), in: address.projectID))
    }

    /// Unchecking photos in the picker takes them out of the tray, leaving the rest and the slides'
    /// own copies.
    @Test func removesTrayPhotosByTheirOriginals() async throws {
        let (library, address) = try await makeLibrary()
        await library.importToTray([try picked("A/L0/001"), try picked("B/L0/001"), try picked()], in: address.projectID)
        let tray = try #require(library.project(address.projectID)?.tray)
        await library.land(.tray(projectID: address.projectID, photoID: tray[0].id), at: address)

        library.removeFromTray(originals: ["A/L0/001", "C/L0/001"], in: address.projectID)
        await library.flush()

        #expect(library.project(address.projectID)?.tray.map(\.image.assetIdentifier) == ["B/L0/001", nil])
        #expect(!copyExists(tray[0].image, in: address.projectID))
        #expect(copyExists(library.photo(at: address), in: address.projectID))
    }

    // MARK: Placing

    @Test func placesAClonePointingAtItsTrayPhoto() async throws {
        let fixture = try await makeLibraryWithATrayPhoto()
        let library = fixture.library, address = fixture.address, photo = fixture.photo

        await library.land(.tray(projectID: address.projectID, photoID: photo.id), at: address)
        await library.flush()

        let clone = try #require(library.photo(at: address))
        #expect(clone.id != photo.image.id)
        #expect(clone.trayPhotoID == photo.id)
        #expect(clone.assetIdentifier == photo.image.assetIdentifier)
        #expect(clone.pixelSize == photo.image.pixelSize)
        #expect(clone.crop == ImageCrop())
        #expect(copyExists(clone, in: address.projectID))
        #expect(copyExists(photo.image, in: address.projectID))
        #expect(library.project(address.projectID)?.slidesHoldingTrayPhotos == [photo.id: [0]])
        #expect(library.importingCells.isEmpty)
    }

    @Test func placingReplacesAPhotoAndDeletesItsCopy() async throws {
        let fixture = try await makeLibraryWithATrayPhoto()
        let library = fixture.library, address = fixture.address, photo = fixture.photo
        let old = try picked()
        await library.importPhoto(into: address, assetIdentifier: nil, from: old.load)
        let replaced = try #require(library.photo(at: address))

        await library.land(.tray(projectID: address.projectID, photoID: photo.id), at: address)
        await library.flush()

        #expect(library.photo(at: address)?.trayPhotoID == photo.id)
        #expect(!copyExists(replaced, in: address.projectID))
    }

    /// An empty panorama fits the photo, as a pick does; one with a photo keeps its width.
    @Test func placingInAPanoramaFitsOnlyAnEmptyOne() async throws {
        let fixture = try await makeLibraryWithATrayPhoto(layout: .panorama)
        let library = fixture.library, address = fixture.address, photo = fixture.photo
        let span = { library.project(address.projectID)?.slides.first?.span }
        let held = HeldPhoto.tray(projectID: address.projectID, photoID: photo.id)

        await library.land(held, at: address)
        #expect(span() == 5)
        library.setSpan(3, of: address.slideID, in: address.projectID)
        await library.land(held, at: address)

        #expect(span() == 3)
        // The saves it made reach the disk before the suite's directory goes.
        await library.flush()
    }

    /// A photo on its way into a cell keeps it, so the pick isn't lost to a placement.
    @Test func placesNothingInACellStillImporting() async throws {
        let fixture = try await makeLibraryWithATrayPhoto()
        let library = fixture.library, address = fixture.address, photo = fixture.photo
        let pick = try picked("pick")
        let (gate, opener) = AsyncStream<Void>.makeStream()

        async let picking: Void = library.importPhoto(into: address, assetIdentifier: "pick") {
            for await _ in gate {
                break
            }
            return try await pick.load()
        }
        while !library.importingCells.contains(address) {
            await Task.yield()
        }
        await library.land(.tray(projectID: address.projectID, photoID: photo.id), at: address)
        opener.yield()
        await picking

        #expect(library.photo(at: address)?.assetIdentifier == "pick")
        #expect(library.importingCells.isEmpty)
        // The saves it made reach the disk before the suite's directory goes.
        await library.flush()
    }

    @Test func reportsATrayPhotoWhoseCopyIsGone() async throws {
        let fixture = try await makeLibraryWithATrayPhoto()
        let library = fixture.library, address = fixture.address, photo = fixture.photo
        try deleteCopy(of: photo.image, in: address.projectID)

        await library.land(.tray(projectID: address.projectID, photoID: photo.id), at: address)

        #expect(library.photo(at: address) == nil)
        #expect(library.failure?.kind == .importPhoto)
        // The saves it made reach the disk before the suite's directory goes.
        await library.flush()
    }

    // MARK: Picture layers

    /// A held tray photo tapped onto a picture takes its place, the layer keeping its frame and
    /// where it sits, and the tray keeping its own copy.
    @Test func replacesAPicturesPhotoWithATrayPhoto() async throws {
        let fixture = try await makeLibraryWithATrayPhoto()
        let library = fixture.library, address = fixture.address, photo = fixture.photo
        let layerAddress = try #require(await library.importImageLayer(
            into: address.slideID,
            of: address.projectID,
            assetIdentifier: nil,
            from: try picked().load
        ))
        var framed = try #require(library.layer(at: layerAddress))
        guard case .image(var picture) = framed.content else {
            Issue.record("Expected a picture layer")
            return
        }
        picture.borderWidth = 0.04
        framed.content = .image(picture)
        framed.placement.rotation = 0.1
        library.saveLayer(framed, in: address.slideID, of: address.projectID)

        await library.replaceLayerImage(at: layerAddress, withTrayPhoto: photo.id)
        await library.flush()

        let replaced = try #require(library.layer(at: layerAddress))
        guard case .image(let replacedPicture) = replaced.content else {
            Issue.record("Expected a picture layer")
            return
        }
        #expect(replacedPicture.image.id != picture.image.id)
        #expect(replacedPicture.image.assetIdentifier == "A/L0/001")
        #expect(replacedPicture.borderWidth == 0.04)
        #expect(replaced.placement == framed.placement)
        #expect(copyExists(replacedPicture.image, in: address.projectID))
        #expect(!copyExists(picture.image, in: address.projectID))
        #expect(copyExists(photo.image, in: address.projectID))
        #expect(library.importingLayers.isEmpty)
    }

    /// A tray photo added as a layer is read from the tray's copy, which stays.
    @Test func addsATrayPhotoAsALayerKeepingTheTraysCopy() async throws {
        let fixture = try await makeLibraryWithATrayPhoto()
        let library = fixture.library, address = fixture.address, photo = fixture.photo

        let layerAddress = await library.importImageLayer(
            into: address.slideID,
            of: address.projectID,
            assetIdentifier: photo.image.assetIdentifier,
            from: library.trayCopySource(of: photo, in: address.projectID)
        )
        await library.flush()

        let layerImage = try #require(layerAddress.flatMap { library.layer(at: $0)?.image })
        #expect(copyExists(layerImage, in: address.projectID))
        #expect(copyExists(photo.image, in: address.projectID))
        #expect(library.trayPhoto(photo.id, in: address.projectID) == photo)
    }

    // MARK: Restoring

    @Test func restoresATrayPhotoFromAClonedCellWithoutTheLibrary() async throws {
        let fixture = try await makeLibraryWithATrayPhoto()
        let library = fixture.library, address = fixture.address, photo = fixture.photo
        await library.land(.tray(projectID: address.projectID, photoID: photo.id), at: address)
        try deleteCopy(of: photo.image, in: address.projectID)

        let photos = MockPhotoLibrary(canReadWithoutAsking: false)
        let outcome = await library.restoreTrayPhoto(photo.id, in: address.projectID, from: photos, asking: false)
        await library.flush()

        let restored = try #require(library.trayPhoto(photo.id, in: address.projectID))
        #expect(outcome == .restored)
        #expect(restored.image.id != photo.image.id)
        #expect(restored.image.assetIdentifier == "A/L0/001")
        #expect(copyExists(restored.image, in: address.projectID))
    }

    @Test func restoresATrayPhotoFromTheLibrary() async throws {
        let fixture = try await makeLibraryWithATrayPhoto()
        let library = fixture.library, address = fixture.address, photo = fixture.photo
        try deleteCopy(of: photo.image, in: address.projectID)

        let outcome = await library.restoreTrayPhoto(photo.id, in: address.projectID, from: MockPhotoLibrary(assets: ["A/L0/001"]), asking: false)
        await library.flush()

        #expect(outcome == .restored)
        #expect(copyExists(library.trayPhoto(photo.id, in: address.projectID)?.image, in: address.projectID))
    }

    @Test func reportsATrayPhotoItCantRestore() async throws {
        let fixture = try await makeLibraryWithATrayPhoto()
        let library = fixture.library, address = fixture.address, photo = fixture.photo
        try deleteCopy(of: photo.image, in: address.projectID)

        #expect(await library.restoreTrayPhoto(photo.id, in: address.projectID, from: MockPhotoLibrary(), asking: false) == .unavailable)
        #expect(library.failure == nil)
        #expect(await library.restoreTrayPhoto(photo.id, in: address.projectID, from: MockPhotoLibrary(), asking: true) == .unavailable)
        #expect(library.failure?.kind == .restorePhoto)
        #expect(library.trayPhoto(photo.id, in: address.projectID) == photo)
        // The saves it made reach the disk before the suite's directory goes.
        await library.flush()
    }

    /// A cell cloned from a tray photo comes back from the tray's copy, keeping its framing.
    @Test func restoresACellFromItsTrayPhotoWithoutTheLibrary() async throws {
        let fixture = try await makeLibraryWithATrayPhoto()
        let library = fixture.library, address = fixture.address, photo = fixture.photo
        await library.land(.tray(projectID: address.projectID, photoID: photo.id), at: address)
        library.setCrop(ImageCrop(scale: 2, centerX: 0.3, centerY: 0.5), at: address)
        let missing = try #require(library.photo(at: address))
        try deleteCopy(of: missing, in: address.projectID)

        let outcome = await library.restorePhoto(at: address, from: MockPhotoLibrary(canReadWithoutAsking: false), asking: false)
        await library.flush()

        let restored = try #require(library.photo(at: address))
        #expect(outcome == .restored)
        #expect(restored.id != missing.id)
        #expect(restored.crop == missing.crop)
        #expect(restored.trayPhotoID == photo.id)
        #expect(copyExists(restored, in: address.projectID))
    }

    /// A photo picked straight into a cell comes back from a tray photo of the same original.
    @Test func restoresACellFromATrayPhotoOfTheSameOriginal() async throws {
        let fixture = try await makeLibraryWithATrayPhoto()
        let library = fixture.library, address = fixture.address, photo = fixture.photo
        await library.importPhoto(into: address, assetIdentifier: "A/L0/001", from: try picked().load)
        let missing = try #require(library.photo(at: address))
        try deleteCopy(of: missing, in: address.projectID)

        let outcome = await library.restorePhoto(at: address, from: MockPhotoLibrary(canReadWithoutAsking: false), asking: false)
        await library.flush()

        #expect(outcome == .restored)
        #expect(library.photo(at: address)?.trayPhotoID == photo.id)
        #expect(copyExists(library.photo(at: address), in: address.projectID))
    }

    /// With the tray's copy gone too, it comes from the library, still standing for its tray photo.
    @Test func restoresACellFromTheLibraryKeepingItsTrayPhoto() async throws {
        let fixture = try await makeLibraryWithATrayPhoto()
        let library = fixture.library, address = fixture.address, photo = fixture.photo
        await library.land(.tray(projectID: address.projectID, photoID: photo.id), at: address)
        let missing = try #require(library.photo(at: address))
        try deleteCopy(of: missing, in: address.projectID)
        try deleteCopy(of: photo.image, in: address.projectID)

        let outcome = await library.restorePhoto(at: address, from: MockPhotoLibrary(assets: ["A/L0/001"]), asking: false)
        await library.flush()

        #expect(outcome == .restored)
        #expect(library.photo(at: address)?.trayPhotoID == photo.id)
        #expect(library.failure == nil)
    }
}
