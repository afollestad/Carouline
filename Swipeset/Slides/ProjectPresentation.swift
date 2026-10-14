//
//  ProjectPresentation.swift
//  Swipeset
//

import Foundation

/// What the project screen opens over itself.
enum ProjectPresentation: Hashable, Identifiable {
    case layout(LayoutPurpose)
    case photoPicker
    case camera(CellAddress)
    case export
    /// A slide's layers sheet.
    case layers(UUID)

    var id: Self { self }

    /// Whether it opens as the screen's sheet: the layout sheet always, and the export and layers
    /// sheets on a compact width, where a wider screen's popover pointing at what opened them
    /// would only adapt to one. A popover shown as a sheet never writes a dragged-to detent back
    /// to `presentationDetents`' selection, so the next time anything applies the selection again,
    /// the last one set comes back.
    func opensAsSheet(isCompact: Bool) -> Bool {
        switch self {
        case .layout: true
        case .export, .layers: isCompact
        case .photoPicker, .camera: false
        }
    }
}
