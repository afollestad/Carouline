//
//  ProjectPresentation.swift
//  Carouline
//

import SwiftUI

/// What the project screen opens over itself.
enum ProjectPresentation: Hashable, Identifiable {
    case layout(LayoutPurpose)
    case photoPicker(PickTarget)
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

/// What's open over the project screen, as its presentation modifiers read and close it, and
/// whether it shows as a sheet or a popover.
struct ProjectPresenting {
    @Binding var presenter: PresentationQueue<ProjectPresentation>
    let openedStyle: OpenedStyle
    let isCompact: Bool
    /// The screen's project, which a slide's layers sheet goes with.
    let project: Project?

    /// Whether `shown` is open, as a presentation modifier reads and dismisses it. A dismissal
    /// closes `shown` only while it's still open, never one opened since.
    func isPresenting(_ shown: ProjectPresentation) -> Binding<Bool> {
        Binding {
            presenter.current == shown
        } set: { isPresented in
            if !isPresented {
                presenter.dismiss(shown)
            }
        }
    }

    /// Whether the export and layers sheets show as sheets, as on a compact width, or as popovers
    /// pointing at what opened them, held to how what's open opened.
    var presentsAsSheets: Bool {
        openedStyle.prefersSheets ?? prefersSheets(for: presenter.current)
    }

    func prefersSheets(for presentation: ProjectPresentation?) -> Bool {
        openedStyle.prefersSheets(for: presentation, isCompact: isCompact, in: project)
    }

    /// `shownSheet`, as the screen's sheet reads and dismisses it. A dismissal closes the item
    /// shown only while it's still open, never one opened since.
    var sheetItem: Binding<ProjectPresentation?> {
        let shown = shownSheet
        return Binding {
            shownSheet
        } set: { item in
            if item == nil, let shown {
                presenter.dismiss(shown)
            }
        }
    }

    /// What's open, when it opens as the screen's sheet. A layers sheet goes with its slide, should
    /// another window delete it, as the slide's own popover would.
    var shownSheet: ProjectPresentation? {
        guard let current = presenter.current, current.opensAsSheet(prefersSheets: presentsAsSheets) else {
            return nil
        }
        if case .layers(let slideID) = current, project?.slides.contains(where: { $0.id == slideID }) != true {
            return nil
        }
        return current
    }

    /// The pick open, as the photo picker reads and closes it.
    var pickTarget: Binding<PickTarget?> {
        Binding {
            guard case .photoPicker(let target) = presenter.current else {
                return nil
            }
            return target
        } set: { target in
            if target == nil {
                presenter.dismiss { if case .photoPicker = $0 { true } else { false } }
            }
        }
    }

    /// The cell the camera is open for, as its cover reads and closes it.
    var cameraTarget: Binding<CellAddress?> {
        Binding {
            guard case .camera(let target) = presenter.current else {
                return nil
            }
            return target
        } set: { target in
            if target == nil {
                presenter.dismiss { if case .camera = $0 { true } else { false } }
            }
        }
    }
}
