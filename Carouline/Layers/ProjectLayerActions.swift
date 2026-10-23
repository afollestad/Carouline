//
//  ProjectLayerActions.swift
//  Carouline
//

import SwiftUI

/// The layer actions the project screen hands its slides, built from the state they share with it.
struct ProjectLayerActions {
    let library: ProjectLibrary
    let projectID: UUID
    let session: LayerSession
    @Binding var presenter: PresentationQueue<ProjectPresentation>
    /// Whether slides present their layers sheets as popovers, rather than the screen as a sheet.
    let showsPopovers: Bool
    /// The text size outside the strip, which caps its own, for the layers sheet.
    let dynamicTypeSize: DynamicTypeSize
    /// Selects a layer, or none, as the screen does, saving what was selected.
    let select: (LayerAddress?) -> Void
    /// The photo selected to frame, which a picture's import mustn't take the selection from.
    let photoSelection: () -> CellAddress?
    /// Where missing pictures are restored from.
    let photoLibrary: any PhotoLibrarySource
    /// Whether a missing picture, by its copy's ID, is yet to be restored quietly, noting that it
    /// now has been, so one whose original is gone isn't tried on every redraw.
    let restoresQuietly: (UUID) -> Bool

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
                guard let layer = library.layer(at: address) ?? session.draftLayer(address.layerID) else {
                    return
                }
                open(address.slideID, at: [.editor(for: layer)])
            },
            openSheet: open,
            addLayer: { slideID, kind in
                open(slideID, at: [])
                session.addsOnOpening = kind
            },
            importImage: { slideID, assetIdentifier, source in
                Task {
                    await importImage(into: slideID, assetIdentifier: assetIdentifier, from: source)
                }
            },
            restoreImage: { address, imageID in
                Task {
                    await library.restoreLayerImage(at: address, missing: imageID, from: photoLibrary, asking: true)
                }
            },
            restoreImageQuietly: { address, imageID in
                guard restoresQuietly(imageID) else {
                    return
                }
                Task {
                    await library.restoreLayerImage(at: address, missing: imageID, from: photoLibrary, asking: false)
                }
            },
            isShowingSheet: { slideID in
                Binding {
                    presenter.current == .layers(slideID)
                } set: { isPresented in
                    if !isPresented {
                        presenter.dismiss(.layers(slideID))
                    }
                }
            },
            showsPopover: showsPopovers,
            sheet: sheet
        )
    }

    /// Opens slide `slideID`'s layers sheet at `path`, past its list.
    private func open(_ slideID: UUID, at path: [LayersPage]) {
        // Clears an add asked for by a sheet that something else opened in place of.
        session.addsOnOpening = nil
        session.sheetPath = path
        presenter.present(.layers(slideID))
    }

    /// Copies the picture `source` produces onto slide `slideID` as a new layer, on a panorama's
    /// slide in the middle of the strip as it lands, then selects it and opens its editor, as long
    /// as the slide's sheet is still open and nothing else has been selected meanwhile. Otherwise
    /// it just lands on its slide, leaving the selection, the strip and the sheet as they are. The
    /// editor opens only from the page it was picked from.
    func importImage(into slideID: UUID, assetIdentifier: String?, from source: @escaping @Sendable () async throws -> PhotoSource?) async {
        let selection = session.selection
        let photo = photoSelection()
        let path = session.sheetPath
        guard let address = await library.importImageLayer(
            into: slideID,
            of: projectID,
            assetIdentifier: assetIdentifier,
            front: { session.frontSlideIndex(of: slideID) },
            from: source
        ) else {
            return
        }
        AccessibilityNotification.Announcement("Picture added").post()
        guard presenter.current == .layers(slideID), session.selection == selection, photoSelection() == photo else {
            return
        }
        select(address)
        if session.sheetPath == path {
            session.sheetPath = [.image(address.layerID)]
        }
    }

    /// Deletes the layer at `address`. A new text layer is still only its draft, which is
    /// discarded rather than the library's, and its editor goes back to the list as a deleted
    /// layer's does.
    private func delete(_ address: LayerAddress) {
        if session.isDraftNew, session.draftLayerID == address.layerID {
            session.discardDraft()
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
            dynamicTypeSize: dynamicTypeSize
        ) {
            // However it went: one whose slide was deleted under it closes without its binding
            // being set.
            presenter.dismiss(.layers(slideID))
            presenter.presentPending()
        }
    }
}
