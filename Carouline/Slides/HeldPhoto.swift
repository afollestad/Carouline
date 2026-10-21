//
//  HeldPhoto.swift
//  Carouline
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A photo on its way to a cell: one from a tray, or one moving from another cell. A drag carries
/// one, and so does placing by tapping, which holds it until a cell is tapped.
nonisolated enum HeldPhoto: Codable, Hashable, Sendable {
    case tray(projectID: UUID, photoID: UUID)
    /// `imageID` names the photo that was picked up, so one replaced since lands nowhere.
    case cell(CellAddress, imageID: UUID)

    /// Whether it's moving from a cell, rather than coming from a tray.
    var isFromCell: Bool {
        if case .cell = self { true } else { false }
    }

    /// The project it comes from.
    var projectID: UUID {
        switch self {
        case .tray(let projectID, _): projectID
        case .cell(let address, _): address.projectID
        }
    }
}

nonisolated extension HeldPhoto: Transferable {
    /// JSON only this app reads, so no type needs declaring, and another app a photo is dragged to
    /// is handed nothing it could misread.
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json).visibility(.ownProcess)
    }
}
