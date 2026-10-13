//
//  ProjectLibrary+Layers.swift
//  Swipeset
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

    /// Gives the layer at `address` `content`, as its editor leaves it, keeping the rest of the
    /// layer as it is now, so an edit never undoes a move made meanwhile. A picture keeps the
    /// copy it shows, since an editor changes its border and blur, never which picture it is.
    func setContent(_ content: LayerContent, at address: LayerAddress) {
        guard var layer = layer(at: address) else {
            return
        }
        switch (content, layer.content) {
        case (.text, .text):
            layer.content = content
        case (.image(var edited), .image(let shown)):
            edited.image = shown.image
            layer.content = .image(edited)
        default:
            return
        }
        saveLayer(layer, in: address.slideID, of: address.projectID)
    }

    /// Moves, sizes or turns the layer at `address`, kept in range on its slide, if it changed.
    func setPlacement(_ placement: LayerPlacement, at address: LayerAddress) {
        guard let slide = slide(address.slideID, in: address.projectID),
              let layer = slide.layers.first(where: { $0.id == address.layerID }) else {
            return
        }
        let placement = placement.clamped(span: slide.span)
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
