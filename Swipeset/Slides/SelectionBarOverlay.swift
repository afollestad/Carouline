//
//  SelectionBarOverlay.swift
//  Swipeset
//

import SwiftUI

/// The selection bar along the bottom of the project screen while a photo is selected, and what
/// keeps the selection to a photo that's still there.
struct SelectionBarOverlay: ViewModifier {
    let library: ProjectLibrary
    let session: CropSession
    /// Replaces the photo at an address from the library, once its zoom is saved.
    let onChoosePhoto: (CellAddress) -> Void
    /// Replaces the photo at an address with a camera capture, once its zoom is saved.
    let onTakePhoto: (CellAddress) -> Void
    let onRemove: (CellAddress) -> Void
    /// Saves the zoom slider's crop once it's let go.
    let onCommitZoom: () -> Void
    let onDone: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                bar
            }
            .animation(.smooth(duration: 0.25), value: session.selection)
            .sensoryFeedback(.selection, trigger: session.selection) { _, selection in
                selection != nil
            }
            // A selected photo deleted with its slide, or dropped by a new layout, leaves nothing
            // to frame, and nothing to bring the strip's scrolling back.
            .onChange(of: selectedPhotoID) { _, photoID in
                if photoID == nil, session.selection != nil {
                    session.liveCrop = nil
                    session.selection = nil
                }
            }
    }

    @ViewBuilder
    private var bar: some View {
        if let selection = session.selection, let photo = library.photo(at: selection) {
            SelectionBar(
                photo: photo,
                session: session,
                hasCamera: CameraPicker.isAvailable,
                onChoosePhoto: { onChoosePhoto(selection) },
                onTakePhoto: { onTakePhoto(selection) },
                onReset: {
                    session.liveCrop = nil
                    library.setCrop(ImageCrop(), at: selection)
                },
                onRemove: { onRemove(selection) },
                onCommitZoom: onCommitZoom,
                onDone: onDone
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var selectedPhotoID: UUID? {
        session.selection.flatMap { library.photo(at: $0)?.id }
    }
}
