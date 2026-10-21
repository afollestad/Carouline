//
//  ProjectLibrary+Layers.swift
//  Carouline
//

import Foundation

extension ProjectLibrary {
    func layer(at address: LayerAddress) -> Layer? {
        slide(address.slideID, in: address.projectID)?.layers.first { $0.id == address.layerID }
    }

    /// Adds `layer` on top of slide `slideID`'s layers, or replaces the one with its ID, kept in
    /// range on the slide. An image it replaces is deleted once the change is saved. A text
    /// layer with no text deletes the one it would replace, since none is ever saved. Returns
    /// false, changing nothing, when the slide is gone.
    @discardableResult
    func saveLayer(_ layer: Layer, in slideID: UUID, of projectID: UUID) -> Bool {
        guard let slide = slide(slideID, in: projectID) else {
            return false
        }
        let address = LayerAddress(projectID: projectID, slideID: slideID, layerID: layer.id)
        if case .text(let text) = layer.content, text.isBlank {
            deleteLayer(at: address)
            return true
        }
        let saved = layer.clamped(span: slide.span)
        let current = slide.layers.first { $0.id == layer.id }
        guard current != saved else {
            return true
        }
        let replaced = current?.image.flatMap { $0.id == saved.image?.id ? nil : $0 }
        update(projectID, deletingImages: replaced.map { [$0] } ?? []) { project in
            guard let index = project.slides.firstIndex(where: { $0.id == slideID }) else {
                return
            }
            if let layerIndex = project.slides[index].layers.firstIndex(where: { $0.id == layer.id }) {
                project.slides[index].layers[layerIndex] = saved
            } else {
                project.slides[index].layers.append(saved)
            }
        }
        return true
    }

    /// Copies the picture `source` produces onto slide `slideID` as a new layer on top, in the
    /// slide's middle, returning where it went, or nil when there was nothing to copy, the copy
    /// failed, or the slide went meanwhile. Each import adds a layer of its own, so a second pick
    /// for the slide never replaces the first, however long either takes.
    func importImageLayer(
        into slideID: UUID,
        of projectID: UUID,
        assetIdentifier: String?,
        from source: @escaping @Sendable () async throws -> PhotoSource?
    ) async -> LayerAddress? {
        importingLayers[slideID, default: 0] += 1
        defer {
            let remaining = (importingLayers[slideID] ?? 1) - 1
            importingLayers[slideID] = remaining > 0 ? remaining : nil
        }
        let slideWidth = project(projectID)?.aspectRatio.pixelWidth ?? 0
        let request = CopyRequest(projectID: projectID, assetIdentifier: assetIdentifier, crop: ImageCrop()) { photo, destination in
            try await ImageImporter.makeLayerCopy(of: photo, at: destination, slideWidth: slideWidth)
        }
        var address: LayerAddress?
        do {
            try await adoptCopy(request, from: source) {
                true
            } place: { image in
                guard let span = slide(slideID, in: projectID)?.span else {
                    return false
                }
                let layer = Layer(content: .image(ImageLayer(image: image)), placement: .middle(ofSpan: span))
                guard saveLayer(layer, in: slideID, of: projectID) else {
                    return false
                }
                address = LayerAddress(projectID: projectID, slideID: slideID, layerID: layer.id)
                return true
            }
        } catch {
            failure = LibraryFailure(kind: .importPhoto, error: error)
        }
        return address
    }

    /// Gives the picture layer at `address` tray photo `photoID` as its picture, as a held photo
    /// tapped onto it does, keeping its border, blur and shadow and where it sits. Its old copy goes
    /// once that's saved. A layer that's gone, or isn't a picture, is left as it is.
    func replaceLayerImage(at address: LayerAddress, withTrayPhoto photoID: UUID) async {
        guard let photo = trayPhoto(photoID, in: address.projectID), layer(at: address)?.image != nil else {
            return
        }
        importingLayers[address.slideID, default: 0] += 1
        defer {
            let remaining = (importingLayers[address.slideID] ?? 1) - 1
            importingLayers[address.slideID] = remaining > 0 ? remaining : nil
        }
        let slideWidth = project(address.projectID)?.aspectRatio.pixelWidth ?? 0
        let original = photo.image.assetIdentifier
        let request = CopyRequest(projectID: address.projectID, assetIdentifier: original, crop: ImageCrop()) { source, destination in
            try await ImageImporter.makeLayerCopy(of: source, at: destination, slideWidth: slideWidth)
        }
        do {
            try await adoptCopy(request, from: trayCopySource(of: photo, in: address.projectID)) {
                true
            } place: { image in
                guard var layer = layer(at: address), case .image(var picture) = layer.content else {
                    return false
                }
                picture.image = image
                layer.content = .image(picture)
                return saveLayer(layer, in: address.slideID, of: address.projectID)
            }
        } catch {
            failure = LibraryFailure(kind: .importPhoto, error: error)
        }
    }

    /// Copies the picture of the layer at `address` in again from its library original, when its
    /// copy `missingID` went missing, keeping its transparency, its border and blur, and where it
    /// sits. Asks for access to the library only when `asking`, so a restore on sight never
    /// prompts; one that asks reports what went wrong. A layer no longer showing that copy, deleted
    /// or restored already, is left as it is.
    @discardableResult
    func restoreLayerImage(
        at address: LayerAddress,
        missing missingID: UUID,
        from photos: any PhotoLibrarySource,
        asking: Bool
    ) async -> RestoreOutcome {
        guard let missing = layer(at: address)?.image, missing.id == missingID, let assetIdentifier = missing.assetIdentifier else {
            return .unavailable
        }
        if let refused = await readAccess(to: photos, asking: asking) {
            return refused
        }
        let slideWidth = project(address.projectID)?.aspectRatio.pixelWidth ?? 0
        let request = CopyRequest(projectID: address.projectID, assetIdentifier: assetIdentifier, crop: missing.crop) { photo, destination in
            try await ImageImporter.makeLayerCopy(of: photo, at: destination, slideWidth: slideWidth)
        }
        var isRestored = false
        do {
            try await adoptCopy(request) {
                guard let data = await photos.imageData(for: assetIdentifier) else {
                    throw RestoreError.originalGone
                }
                return .data(data)
            } isCurrent: {
                true
            } place: { image in
                guard var layer = layer(at: address), case .image(var picture) = layer.content, picture.image.id == missing.id else {
                    return false
                }
                picture.image = image
                layer.content = .image(picture)
                isRestored = saveLayer(layer, in: address.slideID, of: address.projectID)
                return isRestored
            }
        } catch {
            if asking {
                failure = LibraryFailure(kind: .restorePhoto, error: error)
            }
        }
        return isRestored ? .restored : .unavailable
    }

    /// Gives the layer at `address` `content`, as its editor leaves it, keeping the rest of the
    /// layer as it is now, so an edit never undoes a move made meanwhile. A picture keeps the
    /// copy it shows, since an editor changes its border and blur, never which picture it is.
    func setContent(_ content: LayerContent, at address: LayerAddress) {
        guard var layer = layer(at: address), let edited = layer.content.editing(content) else {
            return
        }
        layer.content = edited
        saveLayer(layer, in: address.slideID, of: address.projectID)
    }

    /// Moves, sizes or turns the layer at `address`, kept in range on its slide, if it changed.
    func setPlacement(_ placement: LayerPlacement, at address: LayerAddress) {
        guard let slide = slide(address.slideID, in: address.projectID),
              let layer = slide.layers.first(where: { $0.id == address.layerID }) else {
            return
        }
        var moved = layer
        moved.placement = placement
        let placement = moved.clamped(span: slide.span).placement
        guard layer.placement != placement else {
            return
        }
        updateLayer(at: address) { $0.placement = placement }
    }

    /// Deletes the layer at `address`, and its image's copy once that's saved.
    func deleteLayer(at address: LayerAddress) {
        guard let layer = layer(at: address) else {
            return
        }
        update(address.projectID, deletingImages: layer.image.map { [$0] } ?? []) { project in
            guard let index = project.slides.firstIndex(where: { $0.id == address.slideID }) else {
                return
            }
            project.slides[index].layers.removeAll { $0.id == address.layerID }
        }
    }

    /// Moves the layer at `address` `offset` places up its slide's stack, toward the top, if
    /// there's room.
    func moveLayer(at address: LayerAddress, by offset: Int) {
        guard let layers = slide(address.slideID, in: address.projectID)?.layers,
              let index = layers.firstIndex(where: { $0.id == address.layerID }),
              layers.indices.contains(index + offset),
              offset != 0 else {
            return
        }
        update(address.projectID) { project in
            guard let slideIndex = project.slides.firstIndex(where: { $0.id == address.slideID }) else {
                return
            }
            let layer = project.slides[slideIndex].layers.remove(at: index)
            project.slides[slideIndex].layers.insert(layer, at: index + offset)
        }
    }

    /// Restacks slide `slideID`'s layers in the order of `layerIDs`, bottom to top. Does nothing
    /// unless `layerIDs` names each of the slide's layers once, as it wouldn't once another
    /// window had added or deleted one.
    func reorderLayers(in slideID: UUID, of projectID: UUID, to layerIDs: [UUID]) {
        guard let layers = slide(slideID, in: projectID)?.layers,
              layerIDs.count == layers.count,
              Set(layerIDs) == Set(layers.map(\.id)),
              layerIDs != layers.map(\.id) else {
            return
        }
        let byID = Dictionary(uniqueKeysWithValues: layers.map { ($0.id, $0) })
        update(projectID) { project in
            guard let index = project.slides.firstIndex(where: { $0.id == slideID }) else {
                return
            }
            project.slides[index].layers = layerIDs.compactMap { byID[$0] }
        }
    }

    private func updateLayer(at address: LayerAddress, _ change: (inout Layer) -> Void) {
        update(address.projectID) { project in
            guard let index = project.slides.firstIndex(where: { $0.id == address.slideID }),
                  let layerIndex = project.slides[index].layers.firstIndex(where: { $0.id == address.layerID }) else {
                return
            }
            change(&project.slides[index].layers[layerIndex])
        }
    }

    private func slide(_ slideID: UUID, in projectID: UUID) -> Slide? {
        project(projectID)?.slides.first { $0.id == slideID }
    }
}
