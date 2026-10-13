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
    /// How the copy is encoded, which names its file.
    var fileFormat: ImageFileFormat

    init(
        id: UUID = UUID(),
        assetIdentifier: String?,
        pixelWidth: Int,
        pixelHeight: Int,
        crop: ImageCrop = ImageCrop(),
        fileFormat: ImageFileFormat = .jpeg
    ) {
        self.id = id
        self.assetIdentifier = assetIdentifier
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.crop = crop
        self.fileFormat = fileFormat
    }

    /// Reads a missing `fileFormat` as JPEG, which every copy was before transparent ones.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        assetIdentifier = try container.decodeIfPresent(String.self, forKey: .assetIdentifier)
        pixelWidth = try container.decode(Int.self, forKey: .pixelWidth)
        pixelHeight = try container.decode(Int.self, forKey: .pixelHeight)
        crop = try container.decode(ImageCrop.self, forKey: .crop)
        fileFormat = try container.decodeIfPresent(ImageFileFormat.self, forKey: .fileFormat) ?? .jpeg
    }

    /// Leaves out a JPEG's `fileFormat`, so a project of JPEG copies saves as it always has.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(assetIdentifier, forKey: .assetIdentifier)
        try container.encode(pixelWidth, forKey: .pixelWidth)
        try container.encode(pixelHeight, forKey: .pixelHeight)
        try container.encode(crop, forKey: .crop)
        if fileFormat != .jpeg {
            try container.encode(fileFormat, forKey: .fileFormat)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case assetIdentifier
        case pixelWidth
        case pixelHeight
        case crop
        case fileFormat
    }

    var pixelSize: CGSize {
        CGSize(width: pixelWidth, height: pixelHeight)
    }

    var fileName: String {
        Self.fileName(for: id, format: fileFormat)
    }

    static func fileName(for id: UUID, format: ImageFileFormat) -> String {
        "\(id.uuidString).\(format.fileExtension)"
    }
}

/// How an image copy is encoded: JPEG for a photo, and PNG for a picture with transparency.
nonisolated enum ImageFileFormat: String, Codable, Hashable, Sendable {
    case jpeg
    case png

    var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        }
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
