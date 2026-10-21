//
//  SlideDrop.swift
//  Carouline
//

import SwiftUI
import UniformTypeIdentifiers

/// Takes photos dropped on a slide: one dragged from the tray or another cell, or images from
/// another app, landing in the cell under the drop. The whole card takes them, layers and all, and
/// finds the cell from where the drop is, since a layer over a cell would otherwise take it.
struct SlideDrop: DropDelegate {
    let slide: Slide
    let projectID: UUID
    /// The slide's cells' places, as the card draws them.
    let canvas: LayerCanvas
    /// Whether the slide takes drops now: not while anything is selected or held, nor while a
    /// slide's layers are open.
    let isEnabled: Bool
    /// The cells with a photo on its way in, which take none.
    let importing: Set<Int>
    /// The cell a drop would land in, which it marks.
    @Binding var targetedCell: Int?
    /// Tells the strip whether a drop hovers over the slide, so a neighbor peeking in comes to the
    /// front.
    let onHover: (_ slideID: UUID, _ isOver: Bool) -> Void
    let actions: CellActions

    /// The types the card takes: this app's own photos, and images.
    static let types: [UTType] = [.json, .image]

    func validateDrop(info: DropInfo) -> Bool {
        isEnabled && info.hasItemsConforming(to: Self.types)
    }

    func dropEntered(info: DropInfo) {
        onHover(slide.id, true)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let cell = target(at: info.location)
        targetedCell = cell
        guard cell != nil else {
            return DropProposal(operation: .forbidden)
        }
        return DropProposal(operation: info.hasItemsConforming(to: [.json]) ? .move : .copy)
    }

    func dropExited(info: DropInfo) {
        targetedCell = nil
        onHover(slide.id, false)
    }

    func performDrop(info: DropInfo) -> Bool {
        targetedCell = nil
        onHover(slide.id, false)
        guard let index = target(at: info.location) else {
            return false
        }
        let address = CellAddress(projectID: projectID, slideID: slide.id, index: index)
        if let provider = info.itemProviders(for: [.json]).first {
            let held = ItemProviderLoading.load(HeldPhoto.self, from: provider)
            let dropHeld = actions.dropHeld
            Task {
                if let held = try? await held() {
                    dropHeld(held, address)
                }
            }
            return true
        }
        let photos = IncomingPhoto.dropped(info.itemProviders(for: [.image]))
        guard !photos.isEmpty else {
            return false
        }
        actions.dropPhotos(photos, address)
        return true
    }

    /// The cell under `location`, unless it has a photo on its way in.
    private func target(at location: CGPoint) -> Int? {
        SelectionHit.cell(at: location, of: slide, style: slide.style, on: canvas).flatMap { importing.contains($0) ? nil : $0 }
    }
}
