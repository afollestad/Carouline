//
//  TrayPhoto.swift
//  Carouline
//

import Foundation

/// A photo gathered into a project's tray, to see before it goes on a slide. Each cell it fills
/// takes a clone of its copy, so the tray keeps it however often it's used, and removing it from
/// the tray leaves those cells their photos.
nonisolated struct TrayPhoto: Codable, Hashable, Identifiable, Sendable {
    /// Stays put when `image` is restored under a new ID, so the cells cloned from it still name
    /// it.
    let id: UUID
    /// The tray's own copy, which is never cropped.
    var image: PlacedImage

    init(id: UUID = UUID(), image: PlacedImage) {
        self.id = id
        self.image = image
    }

    /// Whether a cell's `image` is this photo: a clone of it, or from the same library original,
    /// as a photo picked straight into a cell is.
    func matches(_ image: PlacedImage) -> Bool {
        image.trayPhotoID == id || (self.image.assetIdentifier != nil && image.assetIdentifier == self.image.assetIdentifier)
    }
}

nonisolated extension [TrayPhoto] {
    /// Puts `photo` in among the others of its pick, `pick`, in the order they were picked, however
    /// their copies finish: after the last earlier one that's here, or else before the first later
    /// one, or else at the end.
    mutating func insert(_ photo: TrayPhoto, inPickOrder pick: [UUID]) {
        guard let order = pick.firstIndex(of: photo.id) else {
            append(photo)
            return
        }
        let earlier = Set(pick[..<order])
        let later = Set(pick[(order + 1)...])
        if let index = lastIndex(where: { earlier.contains($0.id) }) {
            insert(photo, at: index + 1)
        } else if let index = firstIndex(where: { later.contains($0.id) }) {
            insert(photo, at: index)
        } else {
            append(photo)
        }
    }
}
