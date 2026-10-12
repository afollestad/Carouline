//
//  ProjectLibrary+Images.swift
//  Swipeset
//

import Foundation

extension ProjectLibrary {
    func photo(at address: CellAddress) -> PlacedImage? {
        cell(at: address)?.image
    }

    /// Copies the photo `source` produces into the cell at `address`, replacing any photo there.
    /// `source` runs first, so a slow load from the picker shows as importing too, and a nil from
    /// it, as from a picker that hands back nothing, leaves the cell as it was.
    func importPhoto(
        into address: CellAddress,
        assetIdentifier: String?,
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
            let image = PlacedImage(id: imageID, assetIdentifier: assetIdentifier, pixelWidth: Int(size.width), pixelHeight: Int(size.height))
            // The cell may have gone, or a newer pick replaced this one, while the copy was written.
            guard importTokens[address] == token, place(image, at: address) else {
                write { await $0.deleteImages([imageID], in: address.projectID) }
                return
            }
        } catch {
            failure = LibraryFailure(kind: .importPhoto, error: error)
        }
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
