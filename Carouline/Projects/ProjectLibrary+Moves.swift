//
//  ProjectLibrary+Moves.swift
//  Carouline
//

import Foundation

extension ProjectLibrary {
    /// Puts `held` in the cell at `address`, in place of any photo there: a clone of a tray photo,
    /// or a photo from another cell, moved there and swapped with the one it finds. One from
    /// another project's window lands as a clone, leaving its own where it was. A cell with a photo
    /// on its way in takes none.
    func land(_ held: HeldPhoto, at address: CellAddress) async {
        guard !importingCells.contains(address) else {
            return
        }
        switch held {
        case .tray(let projectID, let photoID):
            guard let photo = trayPhoto(photoID, in: projectID) else {
                return
            }
            // Another project's tray isn't this one's, so its clone stands for none of this one's photos.
            let trayPhotoID = projectID == address.projectID ? photoID : nil
            await placeClone(of: photo.image, from: projectID, trayPhotoID: trayPhotoID, at: address, crop: ImageCrop())
        case .cell(let source, let imageID):
            if source.projectID == address.projectID {
                movePhoto(from: source, imageID: imageID, to: address)
            } else if let image = photo(at: source), image.id == imageID {
                let crop = slide(containing: address)?.layout == .panorama ? ImageCrop() : image.crop
                await placeClone(of: image, from: source.projectID, trayPhotoID: nil, at: address, crop: crop)
            }
        }
    }

    /// Moves photo `imageID` from the cell at `source` to the one at `destination`, in the same
    /// project, swapping it with any photo there, in one save that deletes no copy. Each keeps its
    /// framing, which doesn't depend on its cell's shape, except one moving into a panorama,
    /// which shows all of itself, as a layout changed to a panorama does. An empty panorama
    /// spreads across as many slides as its new photo fills, its layers shifting together with the
    /// photo; one with a photo keeps its width.
    /// Returns false, changing nothing, for a photo that's gone or been replaced, a cell that's
    /// gone, or either cell with a photo on its way in.
    @discardableResult
    func movePhoto(from source: CellAddress, imageID: UUID, to destination: CellAddress) -> Bool {
        guard source != destination,
              source.projectID == destination.projectID,
              let moving = photo(at: source), moving.id == imageID,
              let target = cell(at: destination),
              !importingCells.contains(source), !importingCells.contains(destination) else {
            return false
        }
        let displaced = target.image
        update(source.projectID) { project in
            guard let sourceSlide = project.slides.firstIndex(where: { $0.id == source.slideID }),
                  let destinationSlide = project.slides.firstIndex(where: { $0.id == destination.slideID }) else {
                return
            }
            let old = project.slides[destinationSlide]
            project.slides[destinationSlide].cells[destination.index].image = Self.framed(moving, in: old)
            project.slides[sourceSlide].cells[source.index].image = displaced.map { Self.framed($0, in: project.slides[sourceSlide]) }
            if old.layout == .panorama, displaced == nil {
                project.slides[destinationSlide].setSpan(Slide.panoramaSpan(fitting: moving.pixelSize, in: project.aspectRatio))
                project.slides[destinationSlide].keepLayers(from: old, slideSize: project.aspectRatio.exportSize)
            }
        }
        return true
    }

    /// Copies `photos`, as a drop brings them, into the cell at `address` and, when there are
    /// several, the slide's other empty cells, as a pick does, and into the tray past those, so
    /// none is lost.
    func importPhotos(_ photos: [IncomingPhoto], into address: CellAddress) async {
        let targets = cellsToFill(from: address, count: photos.count)
        let extras = Array(photos.dropFirst(targets.count))
        await withTaskGroup(of: Void.self) { group in
            for (photo, target) in zip(photos, targets) {
                group.addTask {
                    await self.importPhoto(into: target, assetIdentifier: photo.assetIdentifier, from: photo.load)
                }
            }
            if !extras.isEmpty {
                group.addTask {
                    await self.importToTray(extras, in: address.projectID)
                }
            }
        }
    }

    /// The first empty cell of slide `slideID` in reading order, passing over those with a photo
    /// on its way in.
    func emptyCell(in slideID: UUID, of projectID: UUID) -> CellAddress? {
        let slideAddress = CellAddress(projectID: projectID, slideID: slideID, index: 0)
        guard let slide = slide(containing: slideAddress),
              let index = slide.firstEmptyCell(skipping: importingIndexes(in: slideAddress)) else {
            return nil
        }
        return CellAddress(projectID: projectID, slideID: slideID, index: index)
    }

    /// Puts a clone of `image`, a copy in project `sourceProjectID`, in the cell at `address`,
    /// framed by `crop` and standing for tray photo `trayPhotoID`, if any, as the cell's latest
    /// change. A clone takes no room of its own, and leaves `image` where it is. `replacing`, when
    /// given, is the only photo it may take the place of. Returns whether it's placed; a failure
    /// shows as `failureKind`, or not at all when that's nil.
    @discardableResult
    func placeClone(
        of image: PlacedImage,
        from sourceProjectID: UUID,
        trayPhotoID: UUID?,
        at address: CellAddress,
        crop: ImageCrop,
        replacing expectedImageID: UUID? = nil,
        failingAs failureKind: LibraryFailure.Kind? = .importPhoto
    ) async -> Bool {
        let clone = PlacedImage(
            assetIdentifier: image.assetIdentifier,
            pixelWidth: image.pixelWidth,
            pixelHeight: image.pixelHeight,
            crop: crop,
            fileFormat: image.fileFormat,
            trayPhotoID: trayPhotoID
        )
        var isPlaced = false
        await trackingImport(into: address) { isCurrent in
            do {
                guard try await store.cloneImage(named: image.fileName, from: sourceProjectID, as: clone.fileName, in: address.projectID) else {
                    return
                }
            } catch {
                if let failureKind {
                    failure = LibraryFailure(kind: failureKind, error: error)
                }
                return
            }
            // The cell may go, a newer change replace this one, or the photo it's meant for be
            // removed or replaced, while the clone is made.
            guard isCurrent(), expectedImageID == nil || photo(at: address)?.id == expectedImageID, place(clone, at: address) else {
                write { await $0.deleteImages([clone.fileName], in: address.projectID) }
                return
            }
            isPlaced = true
        }
        return isPlaced
    }

    /// `image` framed for a cell of `slide`: whole for a panorama's, and as it was for any other.
    private static func framed(_ image: PlacedImage, in slide: Slide) -> PlacedImage {
        guard slide.layout == .panorama else {
            return image
        }
        var image = image
        image.crop = ImageCrop()
        return image
    }
}
