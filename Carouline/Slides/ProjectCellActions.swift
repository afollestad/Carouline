//
//  ProjectCellActions.swift
//  Carouline
//

import SwiftUI

/// The cell actions the project screen hands its slides, built from the state they share with it.
struct ProjectCellActions {
    let library: ProjectLibrary
    /// Where missing photos are restored from.
    let photoLibrary: any PhotoLibrarySource
    /// Opens the picker for a cell.
    let choosePhotos: (CellAddress) -> Void
    /// Opens the camera for a cell, or nil without a camera, as in the simulator.
    let takePhoto: ((CellAddress) -> Void)?
    /// Selects a photo to frame, as the screen does, saving what was selected.
    let select: (CellAddress) -> Void
    /// Whether a missing photo, by its copy's ID, is yet to be restored quietly, noting that it
    /// now has been, so one whose original is gone isn't tried on every redraw.
    let restoresQuietly: (UUID) -> Bool
    /// The photo held to put in whichever cell is tapped next, if any.
    let held: HeldPhoto?
    let hold: (HeldPhoto) -> Void
    let land: (CellAddress) -> Void
    let landInLayer: (LayerAddress) -> Void

    var actions: CellActions {
        CellActions(
            choosePhoto: choosePhotos,
            takePhoto: takePhoto,
            removePhoto: { address in
                withAnimation {
                    library.removePhoto(at: address)
                }
            },
            select: select,
            setCrop: { crop, address in
                library.setCrop(crop, at: address)
            },
            restorePhoto: { address in
                Task {
                    await library.restorePhoto(at: address, from: photoLibrary, asking: true)
                }
            },
            restorePhotoQuietly: { address in
                guard let imageID = library.photo(at: address)?.id, restoresQuietly(imageID) else {
                    return
                }
                Task {
                    await library.restorePhoto(at: address, from: photoLibrary, asking: false)
                }
            },
            held: held,
            hold: hold,
            land: land,
            landInLayer: landInLayer,
            dropHeld: { held, address in
                Task {
                    await library.land(held, at: address)
                }
            },
            dropPhotos: { photos, address in
                Task {
                    await library.importPhotos(photos, into: address)
                }
            }
        )
    }
}
