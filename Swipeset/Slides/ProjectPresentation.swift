//
//  ProjectPresentation.swift
//  Swipeset
//

import Foundation

/// What the project screen opens over itself.
enum ProjectPresentation: Hashable {
    case layout(LayoutPurpose)
    case photoPicker
    case camera(CellAddress)
    case style
    case export
    /// A slide's layers sheet.
    case layers(UUID)
}
