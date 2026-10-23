//
//  TrayPressOverlay.swift
//  Carouline
//

import SwiftUI

/// A tray photo held down, over the project screen: magnified above its place in the tray while the
/// finger runs along it, then carried above the finger once it rises off the tray, so the cell
/// under the finger stays in view.
struct TrayPressOverlay: ViewModifier {
    let project: Project
    @Environment(TrayPress.self) private var press: TrayPress?
    @Environment(\.imageLoader) private var loader

    /// Between the magnified photo and the tray's glass.
    private static let loupeGap: CGFloat = 12
    /// How far in from the screen's sides the magnified photo stays, as the tray's glass does.
    private static let margin: CGFloat = 16
    /// How far above the finger a carried photo's middle rides, so the cell under the finger shows.
    private static let carryLift: CGFloat = 56

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    let origin = proxy.frame(in: .global).origin
                    if let press, let photo = project.tray.first(where: { $0.id == press.photoID }) {
                        switch press.phase {
                        case .scrubbing:
                            if let anchor = press.anchor {
                                loupe(photo, over: anchor.offsetBy(dx: -origin.x, dy: -origin.y), within: proxy.size.width)
                            }
                        case .carrying:
                            if let location = press.location {
                                carried(photo, at: CGPoint(x: location.x - origin.x, y: location.y - origin.y))
                            }
                        }
                    }
                }
                // Gliding from photo to photo, and in and out, but following the finger, and a
                // photo the tray scrolls, as they go.
                .animation(.smooth(duration: 0.15), value: press?.photoID)
                .animation(.smooth(duration: 0.15), value: press?.phase)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .sensoryFeedback(.selection, trigger: press?.photoID) { _, photoID in
                photoID != nil
            }
    }

    /// `photo` magnified above `anchor`, its place along the tray's glass, kept within the screen.
    private func loupe(_ photo: TrayPhoto, over anchor: CGRect, within width: CGFloat) -> some View {
        let size = TrayLoupe.size(of: photo)
        let x = max(Self.margin + size.width / 2, min(anchor.midX, width - Self.margin - size.width / 2))
        return TrayLoupe(photo: photo, projectID: project.id)
            .position(x: x, y: anchor.minY - Self.loupeGap - size.height / 2)
            .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
    }

    private func carried(_ photo: TrayPhoto, at location: CGPoint) -> some View {
        PhotoDragPreview(image: photo.image, projectID: project.id, loader: loader)
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            .position(x: location.x, y: location.y - Self.carryLift)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
    }
}

#Preview {
    let project = SampleProjects.all[0]
    let press = TrayPress(carrying: project.tray[0].id, at: CGPoint(x: 200, y: 300))
    Color.clear
        .modifier(TrayPressOverlay(project: project))
        .environment(press)
        .background { GlowBackdrop() }
}
