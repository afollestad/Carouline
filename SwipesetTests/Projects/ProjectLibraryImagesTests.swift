//
//  ProjectLibraryImagesTests.swift
//  SwipesetTests
//

import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import Swipeset

@MainActor
struct ProjectLibraryImagesTests {
    private let temporary = TemporaryDirectory("ProjectLibraryImagesTests")

    private var paths: ProjectPaths {
        ProjectPaths(
            root: temporary.url.appending(path: "Support", directoryHint: .isDirectory),
            temporary: temporary.url.appending(path: "tmp", directoryHint: .isDirectory)
        )
    }

    /// A library with one project of one two-cell slide, and the first cell's address.
    private func makeLibrary() async throws -> (ProjectLibrary, CellAddress) {
        let library = ProjectLibrary(store: ProjectStore(paths: paths))
        await library.load()
        let projectID = library.createProject(aspectRatio: .portrait).id
        let slideID = try #require(library.addSlide(.twoColumns, to: projectID))
        return (library, CellAddress(projectID: projectID, slideID: slideID, index: 0))
    }

    /// A picked photo's file, as the picker leaves one for the import.
    private func pickedPhoto(width: Int = 1200, height: Int = 800) throws -> URL {
        let folder = temporary.url.appending(path: "Picked", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "\(UUID().uuidString).jpg")
        try TestImages.writeJPEG(width: width, height: height, to: url)
        return url
    }

    private func copyExists(_ image: PlacedImage?, in projectID: UUID) -> Bool {
        guard let image else {
            return false
        }
        return FileManager.default.fileExists(atPath: paths.imageFile(image.id, in: projectID).path(percentEncoded: false))
    }

    @Test func importsAPhotoIntoItsCellAndKeepsItsLibraryIdentifier() async throws {
        let (library, address) = try await makeLibrary()
        let picked = try pickedPhoto()

        await library.importPhoto(into: address, assetIdentifier: "ABC/L0/001") { .file(picked) }
        await library.flush()

        let image = try #require(library.photo(at: address))
        #expect(image.assetIdentifier == "ABC/L0/001")
        #expect(image.pixelSize == CGSize(width: 1200, height: 800))
        #expect(copyExists(image, in: address.projectID))
        #expect(!FileManager.default.fileExists(atPath: picked.path(percentEncoded: false)))
        #expect(library.importingCells.isEmpty)
        #expect(await ProjectStore(paths: paths).loadAll().projects.first?.images == [image])
    }

    @Test func replacingAPhotoDeletesTheOldCopy() async throws {
        let (library, address) = try await makeLibrary()
        let first = try pickedPhoto()
        await library.importPhoto(into: address, assetIdentifier: nil) { .file(first) }
        let old = library.photo(at: address)
        let second = try pickedPhoto()

        await library.importPhoto(into: address, assetIdentifier: nil) { .file(second) }
        await library.flush()

        let new = library.photo(at: address)
        #expect(new != nil && new?.id != old?.id)
        #expect(copyExists(new, in: address.projectID))
        #expect(!copyExists(old, in: address.projectID))
    }

    @Test func removingAPhotoDeletesItsCopy() async throws {
        let (library, address) = try await makeLibrary()
        let picked = try pickedPhoto()
        await library.importPhoto(into: address, assetIdentifier: nil) { .file(picked) }
        let image = library.photo(at: address)

        library.removePhoto(at: address)
        await library.flush()

        #expect(library.photo(at: address) == nil)
        #expect(!copyExists(image, in: address.projectID))
    }

    @Test func savesANewCropAndIgnoresAnUnchangedOne() async throws {
        let (library, address) = try await makeLibrary()
        let picked = try pickedPhoto()
        await library.importPhoto(into: address, assetIdentifier: nil) { .file(picked) }
        let modified = library.project(address.projectID)?.modifiedAt
        let crop = ImageCrop(scale: 2, centerX: 0.4, centerY: 0.5)

        library.setCrop(ImageCrop(), at: address)
        #expect(library.project(address.projectID)?.modifiedAt == modified)
        library.setCrop(crop, at: address)
        await library.flush()

        #expect(library.photo(at: address)?.crop == crop)
        #expect(await ProjectStore(paths: paths).loadAll().projects.first?.images.first?.crop == crop)
    }

    @Test func anImportIntoADeletedSlideLeavesNoCopy() async throws {
        let (library, address) = try await makeLibrary()
        let picked = try pickedPhoto()

        await library.importPhoto(into: address, assetIdentifier: nil) {
            library.deleteSlide(address.slideID, in: address.projectID)
            return .file(picked)
        }
        await library.flush()

        #expect(contents(of: paths.imagesFolder(for: address.projectID)).isEmpty)
    }

    @Test func anImportIntoADeletedProjectLeavesNoFolder() async throws {
        let (library, address) = try await makeLibrary()
        let picked = try pickedPhoto()

        await library.importPhoto(into: address, assetIdentifier: nil) {
            library.delete(address.projectID)
            return .file(picked)
        }
        await library.flush()

        #expect(!FileManager.default.fileExists(atPath: paths.folder(for: address.projectID).path(percentEncoded: false)))
    }

    /// The photo picked last wins, even when the one before it finishes later.
    @Test func aNewerImportReplacesOneStillRunning() async throws {
        let (library, address) = try await makeLibrary()
        let slow = try pickedPhoto(width: 1000, height: 1000)
        let fast = try pickedPhoto(width: 600, height: 900)
        let (gate, opener) = AsyncStream<Void>.makeStream()

        async let first: Void = library.importPhoto(into: address, assetIdentifier: "slow") {
            for await _ in gate {
                break
            }
            return .file(slow)
        }
        // Starts the second import only once the first holds the cell.
        while !library.importingCells.contains(address) {
            await Task.yield()
        }
        await library.importPhoto(into: address, assetIdentifier: "fast") { .file(fast) }
        opener.yield()
        await first
        await library.flush()

        #expect(library.photo(at: address)?.assetIdentifier == "fast")
        #expect(contents(of: paths.imagesFolder(for: address.projectID)).count == 1)
        #expect(library.importingCells.isEmpty)
    }

    @Test func reportsAPhotoItCantRead() async throws {
        let (library, address) = try await makeLibrary()
        let broken = try pickedPhoto()
        try Data("not an image".utf8).write(to: broken)

        await library.importPhoto(into: address, assetIdentifier: nil) { .file(broken) }
        await library.flush()

        #expect(library.photo(at: address) == nil)
        #expect(library.failure?.kind == .importPhoto)
        #expect(library.importingCells.isEmpty)
    }

    // MARK: Restoring

    /// A library whose cell at `address` holds `missing`, a photo from asset "A/L0/001" whose
    /// copy was deleted.
    private struct MissingCopy {
        let library: ProjectLibrary
        let address: CellAddress
        let missing: PlacedImage
    }

    private func makeLibraryMissingACopy() async throws -> MissingCopy {
        let (library, address) = try await makeLibrary()
        let picked = try pickedPhoto()
        await library.importPhoto(into: address, assetIdentifier: "A/L0/001") { .file(picked) }
        library.setCrop(ImageCrop(scale: 2, centerX: 0.3, centerY: 0.5), at: address)
        await library.flush()
        let image = try #require(library.photo(at: address))
        try FileManager.default.removeItem(at: paths.imageFile(image.id, in: address.projectID))
        return MissingCopy(library: library, address: address, missing: image)
    }

    @Test func restoresAMissingCopyKeepingItsFraming() async throws {
        let copy = try await makeLibraryMissingACopy()
        let library = copy.library, address = copy.address, missing = copy.missing

        let outcome = await library.restorePhoto(at: address, from: MockPhotoLibrary(assets: ["A/L0/001"]), asking: false)
        await library.flush()

        let restored = try #require(library.photo(at: address))
        #expect(outcome == .restored)
        #expect(restored.id != missing.id)
        #expect(restored.assetIdentifier == "A/L0/001")
        #expect(restored.crop == missing.crop)
        #expect(copyExists(restored, in: address.projectID))
    }

    /// A photo removed while its restore was out stays removed.
    @Test func aRestoreLeavesARemovedPhotoRemoved() async throws {
        let copy = try await makeLibraryMissingACopy()
        let library = copy.library, address = copy.address

        await library.importPhoto(into: address, assetIdentifier: "A/L0/001", replacing: copy.missing.id) {
            library.removePhoto(at: address)
            return .image(UIImage(cgImage: try #require(SampleImages.image(for: UUID(), width: 100, height: 100))))
        }
        await library.flush()

        #expect(library.photo(at: address) == nil)
        #expect(contents(of: paths.imagesFolder(for: address.projectID)).isEmpty)
    }

    @Test func restoringOnSightNeverAsksForAccess() async throws {
        let copy = try await makeLibraryMissingACopy()
        let library = copy.library, address = copy.address, missing = copy.missing
        let photos = MockPhotoLibrary(canReadWithoutAsking: false, assets: ["A/L0/001"])

        #expect(await library.restorePhoto(at: address, from: photos, asking: false) == .needsAccess)
        #expect(library.photo(at: address) == missing)
        #expect(library.failure == nil)
    }

    @Test func reportsAccessTheUserRefused() async throws {
        let copy = try await makeLibraryMissingACopy()
        let library = copy.library, address = copy.address
        let photos = MockPhotoLibrary(canReadWithoutAsking: false, grantsAccess: false, assets: ["A/L0/001"])

        #expect(await library.restorePhoto(at: address, from: photos, asking: true) == .denied)
        #expect(library.failure?.kind == .restorePhoto)
    }

    @Test func reportsAGoneOriginalOnlyWhenAsked() async throws {
        let copy = try await makeLibraryMissingACopy()
        let library = copy.library, address = copy.address, missing = copy.missing

        #expect(await library.restorePhoto(at: address, from: MockPhotoLibrary(), asking: false) == .unavailable)
        #expect(library.failure == nil)
        #expect(await library.restorePhoto(at: address, from: MockPhotoLibrary(), asking: true) == .unavailable)
        #expect(library.failure?.kind == .restorePhoto)
        #expect(library.photo(at: address) == missing)
    }

    private func contents(of folder: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
    }
}
