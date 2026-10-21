//
//  ProjectDebugLaunch.swift
//  Carouline
//

#if DEBUG
import SwiftUI

/// Selects `-DebugSelectCell`'s photo or `-DebugSelectLayer`'s layer in the open project, holds
/// `-DebugHoldPhoto`'s photo, and opens `-DebugSheet`'s sheet, after a moment, since a
/// presentation on the first frame doesn't render, and the strip can't scroll to a slide before it
/// has measured the slides.
struct ProjectDebugLaunch: ViewModifier {
    let library: ProjectLibrary
    let projectID: UUID
    let layerActions: LayerActions
    let selectCell: (CellAddress) -> Void
    let selectLayer: (LayerAddress) -> Void
    /// The layer selected, once `selectLayer` has run.
    let selectedLayer: () -> LayerAddress?
    let present: (ProjectPresentation) -> Void
    let hold: (HeldPhoto) -> Void
    @Environment(DebugSettings.self) private var debug: DebugSettings?

    func body(content: Content) -> some View {
        content.task {
            await open()
        }
    }

    private func open() async {
        guard debug?.selectedCell != nil || debug?.selectedLayer != nil || debug?.heldPhoto != nil
            || (debug?.sheet?.opensInProject) == true else {
            return
        }
        try? await Task.sleep(for: .milliseconds(500))
        let slides = library.project(projectID)?.slides ?? []
        if let held = debug?.heldPhoto.flatMap(heldPhoto) {
            hold(held)
        }
        if let (slide, cell) = debug?.selectedCell, slides.indices.contains(slide) {
            selectCell(CellAddress(projectID: projectID, slideID: slides[slide].id, index: cell))
        }
        if let (slide, layer) = debug?.selectedLayer, slides.indices.contains(slide), slides[slide].layers.indices.contains(layer) {
            selectLayer(LayerAddress(projectID: projectID, slideID: slides[slide].id, layerID: slides[slide].layers[layer].id))
        }
        let layerSlideID = selectedLayer()?.slideID ?? slides.first?.id
        switch debug?.sheet {
        case .export: present(.export)
        case .layout: present(.layout(.newSlide))
        case .layers: layerSlideID.map { layerActions.openSheet($0, []) }
        case .addLayer: layerSlideID.map { layerActions.openSheet($0, [.add]) }
        case .editLayer: selectedLayer().map { layerActions.edit($0) }
        case .newProject, .customRatio, nil: break
        }
    }

    /// `-DebugHoldPhoto`'s photo, if the project has it.
    private func heldPhoto(_ hold: DebugSettings.Hold) -> HeldPhoto? {
        guard let project = library.project(projectID) else {
            return nil
        }
        switch hold {
        case .cell(let slide, let cell):
            guard project.slides.indices.contains(slide) else {
                return nil
            }
            let address = CellAddress(projectID: projectID, slideID: project.slides[slide].id, index: cell)
            return library.photo(at: address).map { .cell(address, imageID: $0.id) }
        case .tray(let index):
            return project.tray.indices.contains(index) ? .tray(projectID: projectID, photoID: project.tray[index].id) : nil
        }
    }
}
#endif
