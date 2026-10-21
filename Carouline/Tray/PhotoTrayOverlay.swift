//
//  PhotoTrayOverlay.swift
//  Carouline
//

import SwiftUI
import UIKit

/// The tray along the bottom of the project screen while nothing else is there: no photo or layer
/// selected, no photo held to place, no slide's layers open, and no keyboard up. In its place, the
/// question about tray photos a pick left out, until it's answered.
struct PhotoTrayOverlay: ViewModifier {
    let library: ProjectLibrary
    let project: Project
    let removals: TrayRemovals
    let isShown: Bool
    let actions: TrayActions
    /// Whether the keyboard is on screen, as renaming the project raises it. The tray would ride up
    /// on it over the slides, which stay where they are. Read from where the keyboard is headed,
    /// which UIKit reports for every change, docked, floating or gone.
    @State private var isKeyboardUp = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isShown && !isKeyboardUp {
                    bar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.25), value: isShown && !isKeyboardUp)
            .animation(.smooth(duration: 0.25), value: removalPhotos.isEmpty)
            // Photos gone from the tray some other way, as from another window, leave nothing to
            // ask about, and a question kept for them would come back should one be added again.
            .onChange(of: removalPhotos.isEmpty) { _, isEmpty in
                if isEmpty, removals.pending?.projectID == project.id {
                    removals.forget()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                      let screen = notification.object as? UIScreen else {
                    return
                }
                isKeyboardUp = frame.intersects(screen.bounds)
            }
    }

    @ViewBuilder
    private var bar: some View {
        let photos = removalPhotos
        if photos.isEmpty {
            PhotoTray(project: project, importingCount: library.importingTray[project.id] ?? 0, actions: actions)
        } else {
            TrayRemovalBar(photos: photos, projectID: project.id) {
                removals.keep()
            } onRemove: {
                withAnimation {
                    removals.remove(from: library)
                }
            }
        }
    }

    /// The tray photos waiting on an answer about removing them, which are none once all of them
    /// have gone some other way.
    private var removalPhotos: [TrayPhoto] {
        guard let pending = removals.pending, pending.projectID == project.id else {
            return []
        }
        return project.tray.filter { $0.image.assetIdentifier.map(pending.originals.contains) == true }
    }
}
