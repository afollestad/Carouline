//
//  PhotoTrayOverlay.swift
//  Carouline
//

import SwiftUI
import TipKit
import UIKit

/// The tray along the bottom of the project screen while nothing else is there: no photo or layer
/// selected, no photo held to place, no slide's layers open, and no keyboard up, with the tour's tip
/// about it above, and over the screen, a tray photo held down. In its place, the question about
/// tray photos a pick left out, until it's answered.
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
    @Environment(ProjectTour.self) private var tour: ProjectTour?
    @Environment(TrayPress.self) private var press: TrayPress?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isShown && !isKeyboardUp {
                    bar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .modifier(TrayPressOverlay(project: project))
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
                .overlayPreferenceValue(TourTargetBounds.self) { targets in
                    tourTip(at: targets)
                }
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

    /// The tour's tip about the tray, above it, pointing down at its add button or its photos. Not
    /// while a photo is held, or its actions are open, where they are.
    @ViewBuilder
    private func tourTip(at targets: [TourAnchor.Target: Anchor<CGRect>]) -> some View {
        if let tour, let tip = tour.trayTip, press?.photoID == nil, press?.menuPhotoID == nil {
            let target: TourAnchor.Target = tour.step == .placePhoto ? .trayPhotos : .addPhotos
            if let bounds = targets[target] {
                GeometryReader { proxy in
                    let anchor = tour.anchor(target)
                    ZStack(alignment: .bottom) {
                        anchor.standIn(at: proxy[bounds])
                        TipView(tip, arrowEdge: .bottom, anchorID: anchor)
                            .tourTipStyle()
                            .barTipCorners(pointingAt: proxy[bounds], inBarOf: proxy.size.width, inset: 16)
                            .padding(.horizontal, 16)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, proxy.size.height)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                    // Growing up from the tray, with its stand-in still over the button.
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                }
                // Sized with the tray, so it leaves the slides above as much room.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
