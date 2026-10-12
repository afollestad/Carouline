//
//  ProjectLibrary+Images.swift
//  Swipeset
//

import Foundation

extension ProjectLibrary {
    func photo(at address: CellAddress) -> PlacedImage? {
        cell(at: address)?.image
    }

    /// Copies the photo `source` produces into the cell at `address`, replacing any photo there,
    /// framed by `crop`. `source` runs first, so a slow load from the picker shows as importing
    /// too, and a nil from it, as from a picker that hands back nothing, leaves the cell as it was.
    /// A failure shows as `failureKind`, or not at all when that's nil, and `replacing`, when
    /// given, is the only photo the copy may take the place of.
    func importPhoto(
        into address: CellAddress,
        assetIdentifier: String?,
        crop: ImageCrop = ImageCrop(),
        failingAs failureKind: LibraryFailure.Kind? = .importPhoto,
        replacing expectedImageID: UUID? = nil,
        from source: @escaping @Sendable () async throws -> PhotoSource?
    ) async {
        let token = UUID()
        importTokens[address] = token
        importingCells.insert(address)
        defer {
            if importTokens[address] == token {
                importTokens[address] = nil
                importingCells.remove(address)
            }
        }

        let imageID = UUID()
        let staging = store.paths.imports.appending(path: PlacedImage.fileName(for: imageID))
        var picked: URL?
        defer {
            for file in [picked, staging].compactMap(\.self) {
                try? FileManager.default.removeItem(at: file)
            }
        }
        do {
            guard let photo = try await source() else {
                return
            }
            if case .file(let url) = photo {
                picked = url
            }
            try FileManager.default.createDirectory(at: store.paths.imports, withIntermediateDirectories: true)
            let size = try await ImageImporter.makeCopy(of: photo, at: staging)
            guard importTokens[address] == token,
                  try await store.adoptImage(at: staging, as: imageID, in: address.projectID) else {
                return
            }
            let image = PlacedImage(
                id: imageID,
                assetIdentifier: assetIdentifier,
                pixelWidth: Int(size.width),
                pixelHeight: Int(size.height),
                crop: crop
            )
            // The cell may have gone, a newer pick replaced this one, or the photo it was meant
            // for been removed or replaced, while the copy was written.
            guard importTokens[address] == token,
                  expectedImageID == nil || self.photo(at: address)?.id == expectedImageID,
                  place(image, at: address) else {
                write { await $0.deleteImages([imageID], in: address.projectID) }
                return
            }
        } catch {
            if let failureKind {
                failure = LibraryFailure(kind: failureKind, error: error)
            }
        }
    }

    /// How a restore went.
    enum RestoreOutcome: Equatable {
        case restored
        /// The library can't be read without asking, which only the user's tap should do.
        case needsAccess
        case denied
        /// The photo has no library original, or the original is gone.
        case unavailable
    }

    /// Copies the photo at `address` in again from its library original, keeping its framing,
    /// when its own copy went missing. Asks for access to the library only when `asking`, so a
    /// restore on sight never prompts; one that asks reports what went wrong.
    @discardableResult
    func restorePhoto(at address: CellAddress, from photos: any PhotoLibrarySource, asking: Bool) async -> RestoreOutcome {
        guard let image = photo(at: address), let assetIdentifier = image.assetIdentifier else {
            return .unavailable
        }
        if !photos.canReadWithoutAsking {
            guard asking else {
                return .needsAccess
            }
            guard await photos.requestReadAccess() else {
                failure = LibraryFailure(kind: .restorePhoto, error: RestoreError.denied)
                return .denied
            }
        }
        await importPhoto(
            into: address,
            assetIdentifier: assetIdentifier,
            crop: image.crop,
            failingAs: asking ? .restorePhoto : nil,
            replacing: image.id
        ) {
            guard let original = await photos.image(for: assetIdentifier, maxPixelSize: ImageImporter.maximumPixelSize) else {
                throw RestoreError.originalGone
            }
            return .image(original)
        }
        return photo(at: address)?.id == image.id ? .unavailable : .restored
    }

    func removePhoto(at address: CellAddress) {
        place(nil, at: address)
    }

    /// Frames the photo at `address` with `crop`, if there is one and it moved.
    func setCrop(_ crop: ImageCrop, at address: CellAddress) {
        guard let image = photo(at: address), image.crop != crop else {
            return
        }
        update(address.projectID) { project in
            guard let slideIndex = project.slides.firstIndex(where: { $0.id == address.slideID }) else {
                return
            }
            project.slides[slideIndex].cells[address.index].image?.crop = crop
        }
    }

    /// Puts `image` in the cell at `address`, deleting the copy it replaces once that's saved.
    /// Returns false, changing nothing, when the cell no longer exists.
    @discardableResult
    func place(_ image: PlacedImage?, at address: CellAddress) -> Bool {
        guard let cell = cell(at: address) else {
            return false
        }
        update(address.projectID, deletingImages: cell.image.map { [$0.id] } ?? []) { project in
            guard let slideIndex = project.slides.firstIndex(where: { $0.id == address.slideID }) else {
                return
            }
            project.slides[slideIndex].cells[address.index].image = image
        }
        return true
    }

    private func cell(at address: CellAddress) -> Cell? {
        guard let slide = project(address.projectID)?.slides.first(where: { $0.id == address.slideID }),
              slide.cells.indices.contains(address.index) else {
            return nil
        }
        return slide.cells[address.index]
    }
}

/// Why a photo couldn't come back from the library.
nonisolated enum RestoreError: Error {
    case denied
    case originalGone
}
