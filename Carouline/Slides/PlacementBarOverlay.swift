//
//  PlacementBarOverlay.swift
//  Carouline
//

import SwiftUI

/// The placement bar along the bottom of the project screen while a photo is held to put in
/// whichever cell is tapped next, and what lets it go once the photo is gone.
struct PlacementBarOverlay: ViewModifier {
    let library: ProjectLibrary
    @Binding var held: HeldPhoto?
    let onNewSlide: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                bar
            }
            .animation(.smooth(duration: 0.25), value: held)
            .sensoryFeedback(.selection, trigger: held) { _, held in
                held != nil
            }
            // A held photo removed or replaced, here or in another window, leaves nothing to place.
            .onChange(of: heldPhoto?.id) { _, photoID in
                if photoID == nil, held != nil {
                    held = nil
                }
            }
    }

    @ViewBuilder
    private var bar: some View {
        if let held, let photo = heldPhoto {
            PlacementBar(photo: photo, projectID: held.projectID, held: held, onNewSlide: onNewSlide) {
                self.held = nil
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// The held photo's copy, while it's still where it was picked up from.
    private var heldPhoto: PlacedImage? {
        switch held {
        case .cell(let address, let imageID): library.photo(at: address).flatMap { $0.id == imageID ? $0 : nil }
        case .tray(let projectID, let photoID): library.trayPhoto(photoID, in: projectID)?.image
        case nil: nil
        }
    }
}
