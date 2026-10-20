//
//  ProjectPresentation.swift
//  Carouline
//

import CoreGraphics
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
    /// sheets where the screen `prefersSheets`, as on a compact width, where a wider screen's
    /// popover pointing at what opened them would only adapt to one. A popover shown as a sheet
    /// never writes a dragged-to detent back to `presentationDetents`' selection, so the next time
    /// anything applies the selection again, the last one set comes back.
    func opensAsSheet(prefersSheets: Bool) -> Bool {
        switch self {
        case .layout: true
        case .export, .layers: prefersSheets
        case .photoPicker, .camera: false
        }
    }

    /// Whether a tap on the strip's background closes it, and only that, leaving the selection as a
    /// tap outside any sheet does: a slide's layers, whose sheet leaves the slides taking taps, so
    /// UIKit never closes it on a tap there. Their popover, and the others, close on a tap outside
    /// themselves.
    var closesOnBackgroundTap: Bool {
        if case .layers = self { true } else { false }
    }
}

/// Whether what's open on the project screen opened as a sheet or a popover, and the strip's size,
/// which decides it for a slide's layers. Not observed, since each is set to what the screen
/// already shows, so a write redraws nothing.
final class OpenedStyle {
    var prefersSheets: Bool?
    var stripSize: CGSize = .zero

    /// Whether `presentation` would open as a sheet rather than a popover pointing at what opened
    /// it: on a compact width, and for a slide's layers, on a strip with no room for their popover
    /// beside the slide, such as an iPad's in portrait or iPhone Duo's in landscape. A popover until
    /// the strip has measured itself, as previews and snapshots never do.
    func prefersSheets(for presentation: ProjectPresentation?, isCompact: Bool, in project: Project?) -> Bool {
        if isCompact {
            return true
        }
        guard case .layers(let slideID) = presentation, stripSize != .zero, let project,
              let slide = project.slides.first(where: { $0.id == slideID }) else {
            return false
        }
        return !SlideStrip.layersPopoverFits(span: slide.span, aspectRatio: project.aspectRatio, in: stripSize)
    }
}
