//
//  ProjectLibrary+Tray.swift
//  Carouline
//

import Foundation

extension ProjectLibrary {
    /// How many photos copy into a tray at once: enough to keep a pick of many moving, few enough
    /// that it decodes only a few full-size photos at a time.
    static let trayImportWidth = 3

    func trayPhoto(_ photoID: UUID, in projectID: UUID) -> TrayPhoto? {
        project(projectID)?.tray.first { $0.id == photoID }
    }

    /// Copies `photos` into project `projectID`'s tray in the order given, `trayImportWidth` at a
    /// time, leaving out any whose library original the tray holds already. Each counts in
    /// `importingTray` until its copy lands, and one that fails shows as `importPhoto`.
    func importToTray(_ photos: [IncomingPhoto], in projectID: UUID) async {
        guard let project = project(projectID) else {
            return
        }
        var originals = Set(project.tray.compactMap(\.image.assetIdentifier))
        let fresh = photos.filter { photo in
            photo.assetIdentifier.map { originals.insert($0).inserted } ?? true
        }
        guard !fresh.isEmpty else {
            return
        }
        importingTray[projectID, default: 0] += fresh.count
        // Named before any lands, so each finds its place among the others whatever order they finish in.
        let pick = fresh.map { _ in UUID() }
        let limit = trayCopyLimit(for: project)
        await withTaskGroup(of: Void.self) { group in
            for (order, photo) in fresh.enumerated() {
                if order >= Self.trayImportWidth {
                    await group.next()
                }
                group.addTask {
                    await self.importTrayPhoto(photo, id: pick[order], pick: pick, limit: limit, in: projectID)
                }
            }
        }
    }

    /// Reads tray photo `photo`'s copy, for a picture layer made from it: as data, never as a file,
    /// since `adoptCopy` deletes a file it's handed once its copy is made, and this one is the tray's.
    func trayCopySource(of photo: TrayPhoto, in projectID: UUID) -> @Sendable () async throws -> PhotoSource? {
        let url = store.paths.imageFile(named: photo.image.fileName, in: projectID)
        return { @Sendable in
            .data(try await Task.detached { try Data(contentsOf: url) }.value)
        }
    }

    /// Removes tray photo `photoID` and its copy. The cells cloned from it keep their own.
    func removeFromTray(_ photoID: UUID, in projectID: UUID) {
        guard let photo = trayPhoto(photoID, in: projectID) else {
            return
        }
        update(projectID, deletingImages: [photo.image]) { project in
            project.tray.removeAll { $0.id == photoID }
        }
    }

    /// Removes the tray's photos from library originals `assetIdentifiers`, as unchecking them in
    /// the picker does, and their copies. The cells cloned from them keep their own.
    func removeFromTray(originals assetIdentifiers: Set<String>, in projectID: UUID) {
        let photos = project(projectID)?.tray.filter { $0.image.assetIdentifier.map(assetIdentifiers.contains) == true } ?? []
        guard !photos.isEmpty else {
            return
        }
        let photoIDs = Set(photos.map(\.id))
        update(projectID, deletingImages: photos.map(\.image)) { project in
            project.tray.removeAll { photoIDs.contains($0.id) }
        }
    }

    /// Copies tray photo `photoID` in again when its copy went missing: from a cell's clone of it,
    /// or a cell's photo from the same library original, which needs no access to the library,
    /// or else from its library original. Asks for access to the library only when `asking`, so
    /// a restore on sight never prompts; one that asks reports what went wrong.
    @discardableResult
    func restoreTrayPhoto(_ photoID: UUID, in projectID: UUID, from photos: any PhotoLibrarySource, asking: Bool) async -> RestoreOutcome {
        guard let project = project(projectID), let missing = trayPhoto(photoID, in: projectID)?.image else {
            return .unavailable
        }
        let standIns = project.slides.flatMap(\.cells).compactMap(\.image).filter { image in
            image.trayPhotoID == photoID || (image.assetIdentifier != nil && image.assetIdentifier == missing.assetIdentifier)
        }
        for standIn in standIns {
            let copy = PlacedImage(
                assetIdentifier: missing.assetIdentifier,
                pixelWidth: standIn.pixelWidth,
                pixelHeight: standIn.pixelHeight,
                fileFormat: standIn.fileFormat
            )
            // A stand-in whose own copy is gone too can't help.
            guard (try? await store.cloneImage(named: standIn.fileName, from: projectID, as: copy.fileName, in: projectID)) == true else {
                continue
            }
            if !replaceTrayCopy(of: photoID, in: projectID, missing: missing, with: copy) {
                write { await $0.deleteImages([copy.fileName], in: projectID) }
            }
            return trayRestoreOutcome(of: photoID, in: projectID, missing: missing)
        }
        guard let assetIdentifier = missing.assetIdentifier else {
            return .unavailable
        }
        if let refused = await readAccess(to: photos, asking: asking) {
            return refused
        }
        let limit = trayCopyLimit(for: project)
        // Asked for at the copy's size, so a 48-megapixel original doesn't come back whole.
        let maxPixelSize = limit.longestSide(width: missing.pixelWidth, height: missing.pixelHeight)
        let request = CopyRequest(projectID: projectID, assetIdentifier: assetIdentifier, crop: ImageCrop()) { source, destination in
            try await ImageImporter.makeCopy(of: source, at: destination, limit: limit)
        }
        do {
            // The photo may be removed, or restored another way, while the copy is written.
            try await adoptCopy(request) {
                guard let original = await photos.image(for: assetIdentifier, maxPixelSize: maxPixelSize) else {
                    throw RestoreError.originalGone
                }
                return .image(original)
            } isCurrent: {
                trayPhoto(photoID, in: projectID)?.image.id == missing.id
            } place: { image in
                replaceTrayCopy(of: photoID, in: projectID, missing: missing, with: image)
            }
        } catch {
            if asking {
                failure = LibraryFailure(kind: .restorePhoto, error: error)
            }
        }
        return trayRestoreOutcome(of: photoID, in: projectID, missing: missing)
    }

    /// Copies `photo` into project `projectID`'s tray as tray photo `id`, in its place in `pick`.
    private func importTrayPhoto(_ photo: IncomingPhoto, id: UUID, pick: [UUID], limit: ImageImporter.CopyLimit, in projectID: UUID) async {
        defer {
            let remaining = (importingTray[projectID] ?? 1) - 1
            importingTray[projectID] = remaining > 0 ? remaining : nil
        }
        let request = CopyRequest(projectID: projectID, assetIdentifier: photo.assetIdentifier, crop: ImageCrop()) { source, destination in
            try await ImageImporter.makeCopy(of: source, at: destination, limit: limit)
        }
        do {
            // The project may be deleted, or another pick bring the same original in first, while
            // the copy is written.
            try await adoptCopy(request, from: photo.load) {
                project(projectID) != nil
            } place: { image in
                guard let tray = project(projectID)?.tray,
                      image.assetIdentifier.map({ original in !tray.contains { $0.image.assetIdentifier == original } }) ?? true else {
                    return false
                }
                update(projectID) { project in
                    project.tray.insert(TrayPhoto(id: id, image: image), inPickOrder: pick)
                }
                return true
            }
        } catch {
            failure = LibraryFailure(kind: .importPhoto, error: error)
        }
    }

    /// Gives tray photo `photoID` `image` as its copy, in place of `missing`, whose file it
    /// deletes. Returns false, changing nothing, once the photo is gone or has another copy.
    private func replaceTrayCopy(of photoID: UUID, in projectID: UUID, missing: PlacedImage, with image: PlacedImage) -> Bool {
        guard trayPhoto(photoID, in: projectID)?.image.id == missing.id else {
            return false
        }
        update(projectID, deletingImages: [missing]) { project in
            guard let index = project.tray.firstIndex(where: { $0.id == photoID }) else {
                return
            }
            project.tray[index].image = image
        }
        return true
    }

    /// How a restore of tray photo `photoID`'s `missing` copy went, judged by whether it still has
    /// that copy.
    private func trayRestoreOutcome(of photoID: UUID, in projectID: UUID, missing: PlacedImage) -> RestoreOutcome {
        trayPhoto(photoID, in: projectID)?.image.id == missing.id ? .unavailable : .restored
    }

    /// How much of a photo the tray keeps: as much as a cell's copy, which keeps enough of a wide
    /// photo for a panorama too, so the photo can go in any cell.
    private func trayCopyLimit(for project: Project) -> ImageImporter.CopyLimit {
        ImageImporter.CopyLimit(slideWidth: project.aspectRatio.pixelWidth, slideHeight: project.aspectRatio.pixelHeight, isPanorama: false)
    }
}
