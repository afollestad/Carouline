//
//  CellActions.swift
//  Carouline
//

import Foundation

/// What a cell can ask its screen to do.
struct CellActions {
    let choosePhoto: (CellAddress) -> Void
    /// Nil without a camera, as in the simulator.
    let takePhoto: ((CellAddress) -> Void)?
    let removePhoto: (CellAddress) -> Void
    /// Selects the photo to frame it.
    let select: (CellAddress) -> Void
    let setCrop: (ImageCrop, CellAddress) -> Void
    /// Brings a missing photo back from the library, asking for access if need be.
    let restorePhoto: (CellAddress) -> Void
    /// Brings a missing photo back from the library if that needs no asking, as when one is
    /// found missing.
    let restorePhotoQuietly: (CellAddress) -> Void
    /// The photo held to put in whichever cell is tapped next, if any.
    var held: HeldPhoto?
    /// Holds a photo to put in whichever cell is tapped next, as moving one without a drag does.
    let hold: (HeldPhoto) -> Void
    /// Puts the held photo in a cell, or lets it go when the cell is the one it's held from.
    let land: (CellAddress) -> Void
    /// Puts the held photo, one from the tray, in a picture layer in place of its picture.
    let landInLayer: (LayerAddress) -> Void
    /// Puts a photo dragged from the tray or another cell in a cell.
    let dropHeld: (HeldPhoto, CellAddress) -> Void
    /// Copies photos dropped from another app into a cell, and its slide's other empty cells.
    let dropPhotos: ([IncomingPhoto], CellAddress) -> Void

    static let preview = CellActions(
        choosePhoto: { _ in },
        takePhoto: { _ in },
        removePhoto: { _ in },
        select: { _ in },
        setCrop: { _, _ in },
        restorePhoto: { _ in },
        restorePhotoQuietly: { _ in },
        hold: { _ in },
        land: { _ in },
        landInLayer: { _ in },
        dropHeld: { _, _ in },
        dropPhotos: { _, _ in }
    )
}
