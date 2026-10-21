//
//  TrayActions.swift
//  Carouline
//

import Foundation

/// What a project's tray can ask its screen to do, each with a tray photo's ID.
struct TrayActions {
    /// Opens the picker to gather photos into the tray.
    let addPhotos: () -> Void
    /// Copies photos dropped from another app into the tray.
    let addDropped: ([IncomingPhoto]) -> Void
    /// Puts a photo in the front slide's next empty cell, or holds it for a cell to be tapped
    /// when there's none, or starts a slide with it when there's no slide in front.
    let place: (UUID) -> Void
    /// Holds a photo for a cell to be tapped.
    let hold: (UUID) -> Void
    /// Starts a new slide with a photo in its first cell.
    let startSlide: (UUID) -> Void
    let remove: (UUID) -> Void
    /// Brings a missing photo back, asking for access to the library if need be.
    let restore: (UUID) -> Void
    /// Brings a missing photo back if that needs no asking, as when one is found missing.
    let restoreQuietly: (UUID) -> Void
    /// The slide in front, as "Slide 2", when it has an empty cell for `place` to fill, or nil
    /// when `place` holds the photo or starts a slide instead.
    let roomInFront: String?
    /// What `place` does, for VoiceOver.
    let placeHint: String

    static let preview = TrayActions(
        addPhotos: {},
        addDropped: { _ in },
        place: { _ in },
        hold: { _ in },
        startSlide: { _ in },
        remove: { _ in },
        restore: { _ in },
        restoreQuietly: { _ in },
        roomInFront: "Slide 2",
        placeHint: "Adds the photo to Slide 2"
    )
}
