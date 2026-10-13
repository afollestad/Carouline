//
//  ProjectLayerActions.swift
//  Swipeset
//

import SwiftUI

/// The layer actions the project screen hands its slides, built from the state they share with it.
struct ProjectLayerActions {
    let library: ProjectLibrary
    let projectID: UUID
    let session: LayerSession
    @Binding var presenter: PresentationQueue<ProjectPresentation>
    /// The text size outside the strip, which caps its own, for the layers sheet.
    let dynamicTypeSize: DynamicTypeSize
    /// Selects a layer, or none, as the screen does, saving what was selected.
    let select: (LayerAddress?) -> Void

    var actions: LayerActions {
        LayerActions(
            select: { select($0) },
            setPlacement: { placement, address in
                session.commitPlacement(placement, at: address, to: library)
            },
            move: { address, offset in
                // New text joins its slide first, so it has a place in the stack to move from.
                if session.isDraftNew, session.draftLayerID == address.layerID {
                    session.saveDraft(to: library, projectID: projectID, endingEdit: false)
                }
                withAnimation {
                    library.moveLayer(at: address, by: offset)
                }
            },
            delete: delete,
            edit: { address in
                guard let layer = library.layer(at: address) ?? session.draftLayer(address.layerID), LayerActions.canEdit(layer) else {
                    return
                }
                open(address.slideID, at: [.text(address.layerID)])
            },
            openSheet: open,
            isShowingSheet: { slideID in
                Binding {
                    presenter.current == .layers(slideID)
                } set: { isPresented in
                    if !isPresented {
                        presenter.dismiss(.layers(slideID))
                    }
                }
            },
            sheet: sheet
        )
    }

    /// Opens slide `slideID`'s layers sheet at `path`, past its list.
    private func open(_ slideID: UUID, at path: [LayersPage]) {
        session.sheetPath = path
        presenter.present(.layers(slideID))
    }

    /// Deletes the layer at `address`. A new text layer is still only its draft, which is
    /// dropped, with its sheet, rather than the library's.
    private func delete(_ address: LayerAddress) {
        if session.isDraftNew, session.draftLayerID == address.layerID {
            session.draft = nil
            presenter.dismiss(.layers(address.slideID))
            select(nil)
            return
        }
        withAnimation {
            library.deleteLayer(at: address)
        }
    }

    private func sheet(_ slideID: UUID) -> LayersSheet {
        LayersSheet(
            library: library,
            projectID: projectID,
            slideID: slideID,
            session: session,
            actions: actions,
            kinds: [.text],
            dynamicTypeSize: dynamicTypeSize
        ) {
            // However it went: one whose slide was deleted under it never sets `isShowingSheet`.
            presenter.dismiss(.layers(slideID))
            presenter.presentPending()
        }
    }
}
