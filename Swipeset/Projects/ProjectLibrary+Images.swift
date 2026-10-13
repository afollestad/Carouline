//
//  ProjectLibrary+Images.swift
//  Swipeset
//

import Foundation

extension ProjectLibrary {
    func photo(at address: CellAddress) -> PlacedImage? {
        cell(at: address)?.image
    }

    /// How many photos a pick for the cell at `address` can take: one for each empty cell in its
    /// slide when it's empty, or one to replace its photo. Cells with a photo on its way in count
    /// as full, so a second pick can't replace the first while it loads.
    func pickLimit(for address: CellAddress) -> Int {
        guard let slide = slide(containing: address), cell(at: address)?.image == nil else {
            return 1
        }
        return max(1, slide.emptyCellCount(skipping: importingIndexes(in: address)))
    }

    /// The cells, by `Slide.cellsToFill`, that `count` photos picked for the cell at `address` go
    /// in, passing over those with a photo on its way in.
    func cellsToFill(from address: CellAddress, count: Int) -> [CellAddress] {
        let slide = slide(containing: address)
        let indexes = slide?.cellsToFill(from: address.index, count: count, skipping: importingIndexes(in: address)) ?? []
        return indexes.map { CellAddress(projectID: address.projectID, slideID: address.slideID, index: $0) }
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

        let limit = copyLimit(for: address)
        let request = CopyRequest(projectID: address.projectID, assetIdentifier: assetIdentifier, crop: crop) { photo, destination in
            try await ImageImporter.makeCopy(of: photo, at: destination, limit: limit)
        }
        do {
            // The cell may go, a newer pick replace this one, or the photo it's meant for be removed
            // or replaced, while the copy is written.
            try await adoptCopy(request, from: source) {
                importTokens[address] == token
            } place: { image in
                (expectedImageID == nil || self.photo(at: address)?.id == expectedImageID) && place(image, at: address)
            }
        } catch {
            if let failureKind {
                failure = LibraryFailure(kind: failureKind, error: error)
            }
        }
    }

    /// A copy for `adoptCopy`: the project it joins, what it keeps of its photo, and how it's made.
    struct CopyRequest {
        let projectID: UUID
        let assetIdentifier: String?
        let crop: ImageCrop
        let make: @Sendable (PhotoSource, URL) async throws -> ImageImporter.Copy
    }

    /// Copies the photo `source` produces into `request`'s project and offers it to `place`,
    /// deleting it again if `place` turns it down, or if `isCurrent` says the import has been
    /// overtaken meanwhile. A nil from `source` changes nothing. The picked and staged files go
    /// whatever happens.
    func adoptCopy(
        _ request: CopyRequest,
        from source: @Sendable () async throws -> PhotoSource?,
        isCurrent: () -> Bool,
        place: (PlacedImage) -> Bool
    ) async throws {
        let imageID = UUID()
        // Named for the import alone, since its format, and so its file name, comes from the copy.
        let staging = store.paths.imports.appending(path: imageID.uuidString)
        var picked: URL?
        defer {
            for file in [picked, staging].compactMap(\.self) {
                try? FileManager.default.removeItem(at: file)
            }
        }
        guard let photo = try await source() else {
            return
        }
        if case .file(let url) = photo {
            picked = url
        }
        try FileManager.default.createDirectory(at: store.paths.imports, withIntermediateDirectories: true)
        let copy = try await request.make(photo, staging)
        let image = PlacedImage(
            id: imageID,
            assetIdentifier: request.assetIdentifier,
            pixelWidth: Int(copy.size.width),
            pixelHeight: Int(copy.size.height),
            crop: request.crop,
            fileFormat: copy.format
        )
        guard isCurrent(), try await store.adoptImage(at: staging, as: image.fileName, in: request.projectID) else {
            return
        }
        guard isCurrent(), place(image) else {
            write { await $0.deleteImages([image.fileName], in: request.projectID) }
            return
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
        if let refused = await readAccess(to: photos, asking: asking) {
            return refused
        }
        // Asked for at the copy's size, so a large copy's original doesn't come back as all of a
        // 48-megapixel photo, nor a cell's past what its copy keeps.
        let maxPixelSize = copyLimit(for: address).longestSide(width: image.pixelWidth, height: image.pixelHeight)
        await importPhoto(
            into: address,
            assetIdentifier: assetIdentifier,
            crop: image.crop,
            failingAs: asking ? .restorePhoto : nil,
            replacing: image.id
        ) {
            guard let original = await photos.image(for: assetIdentifier, maxPixelSize: maxPixelSize) else {
                throw RestoreError.originalGone
            }
            return .image(original)
        }
        return photo(at: address)?.id == image.id ? .unavailable : .restored
    }

    /// Why `photos` can't be read for a restore, or nil when it can: asking for access only when
    /// `asking`, and reporting a refusal then.
    func readAccess(to photos: any PhotoLibrarySource, asking: Bool) async -> RestoreOutcome? {
        guard !photos.canReadWithoutAsking else {
            return nil
        }
        guard asking else {
            return .needsAccess
        }
        guard await photos.requestReadAccess() else {
            failure = LibraryFailure(kind: .restorePhoto, error: RestoreError.denied)
            return .denied
        }
        return nil
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
    /// A photo filling an empty panorama spreads it across as many slides as the photo fills;
    /// one replacing or restoring a photo keeps the width it had. Returns false, changing
    /// nothing, when the cell no longer exists.
    @discardableResult
    func place(_ image: PlacedImage?, at address: CellAddress) -> Bool {
        guard let cell = cell(at: address) else {
            return false
        }
        update(address.projectID, deletingImages: cell.image.map { [$0] } ?? []) { project in
            guard let slideIndex = project.slides.firstIndex(where: { $0.id == address.slideID }) else {
                return
            }
            if let image, cell.image == nil, project.slides[slideIndex].layout == .panorama {
                project.slides[slideIndex].setSpan(Slide.panoramaSpan(fitting: image.pixelSize, in: project.aspectRatio))
            }
            project.slides[slideIndex].cells[address.index].image = image
        }
        return true
    }

    private func cell(at address: CellAddress) -> Cell? {
        guard let slide = slide(containing: address), slide.cells.indices.contains(address.index) else {
            return nil
        }
        return slide.cells[address.index]
    }

    private func slide(containing address: CellAddress) -> Slide? {
        project(address.projectID)?.slides.first { $0.id == address.slideID }
    }

    /// How much of a photo the cell at `address` keeps, for its project's slides.
    private func copyLimit(for address: CellAddress) -> ImageImporter.CopyLimit {
        ImageImporter.CopyLimit(
            slideHeight: project(address.projectID).map { Int($0.aspectRatio.exportSize.height) } ?? 0,
            isPanorama: slide(containing: address)?.layout == .panorama
        )
    }

    /// The cells of `address`'s slide with a photo on its way in.
    private func importingIndexes(in address: CellAddress) -> Set<Int> {
        Set(importingCells.filter { $0.projectID == address.projectID && $0.slideID == address.slideID }.map(\.index))
    }
}

/// Why a photo couldn't come back from the library.
nonisolated enum RestoreError: Error {
    case denied
    case originalGone
}
