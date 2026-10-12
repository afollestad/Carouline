//
//  PlacedImage.swift
//  Swipeset
//

import CoreGraphics
import Foundation

/// A photo filling a cell: the app's own copy, where it came from, and how it's framed.
nonisolated struct PlacedImage: Codable, Hashable, Identifiable, Sendable {
    /// Names the copy, so every replacement or restore gets a new ID and a new file, and the old
    /// one can go once the project no longer refers to it.
    let id: UUID
    /// The Photos asset the copy came from, used to restore the copy if it goes missing. Camera
    /// photos never reach the library, so they have none.
    var assetIdentifier: String?
    /// The copy's size, upright, so a cell can frame the photo before it loads.
    var pixelWidth: Int
    var pixelHeight: Int
    var crop: ImageCrop

    init(id: UUID = UUID(), assetIdentifier: String?, pixelWidth: Int, pixelHeight: Int, crop: ImageCrop = ImageCrop()) {
        self.id = id
        self.assetIdentifier = assetIdentifier
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.crop = crop
    }

    var pixelSize: CGSize {
        CGSize(width: pixelWidth, height: pixelHeight)
    }

    var fileName: String {
        Self.fileName(for: id)
    }

    static func fileName(for id: UUID) -> String {
        "\(id.uuidString).jpg"
    }
}

/// How a photo sits in its cell, independent of the cell's size, so the same framing holds on
/// screen, in an export, and in a cell reshaped by a new layout or spacing.
nonisolated struct ImageCrop: Codable, Hashable, Sendable {
    /// The zoom past the smallest size that fills the cell.
    var scale: Double
    /// The point of the photo shown at the cell's center, in unit coordinates.
    var centerX: Double
    var centerY: Double

    init(scale: Double = 1, centerX: Double = 0.5, centerY: Double = 0.5) {
        self.scale = scale
        self.centerX = centerX
        self.centerY = centerY
    }

    /// Five times past filling the cell is past where a 3072-pixel copy turns soft in a
    /// 1080-pixel export's smallest cells.
    static let maximumScale = 5.0
}
