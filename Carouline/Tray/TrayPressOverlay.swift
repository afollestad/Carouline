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
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

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
                                loupe(photo, over: anchor.offsetBy(dx: -origin.x, dy: -origin.y), within: proxy.size)
                            }
                        case .carrying:
                            if let location = press.location {
                                carried(photo, at: CGPoint(x: location.x - origin.x, y: location.y - origin.y), within: proxy.size)
                            }
                        }
                    }
                }
                // Each photo growing out of the tray as the last shrinks back into it, with a little
                // spring, but following the finger, and a photo the tray scrolls, as they go.
                .animation(.spring(duration: 0.3, bounce: 0.3), value: press?.photoID)
                .animation(.smooth(duration: 0.15), value: press?.phase)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .sensoryFeedback(.selection, trigger: press?.photoID) { _, photoID in
                photoID != nil
            }
    }

    /// `photo` magnified above `anchor`, its place along the tray's glass, kept within the screen
    /// `container`, and growing out of its place and shrinking back into it.
    private func loupe(_ photo: TrayPhoto, over anchor: CGRect, within container: CGSize) -> some View {
        let size = TrayLoupe.size(of: photo)
        let x = max(Self.margin + size.width / 2, min(anchor.midX, container.width - Self.margin - size.width / 2))
        return TrayLoupe(photo: photo, projectID: project.id)
            .position(x: x, y: anchor.minY - Self.loupeGap - size.height / 2)
            // One of its own for each photo, so the next grows as this one shrinks.
            .id(photo.id)
            .transition(growing(from: CGPoint(x: anchor.midX, y: anchor.minY), within: container))
    }

    private func carried(_ photo: TrayPhoto, at location: CGPoint, within container: CGSize) -> some View {
        let center = CGPoint(x: location.x, y: location.y - Self.carryLift)
        return PhotoDragPreview(image: photo.image, projectID: project.id, loader: loader)
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            .position(center)
            .transition(growing(from: center, within: container))
    }

    /// Growing out of and shrinking into `point`, in `container`'s coordinates, or only fading under
    /// Reduce Motion. A point within the whole container, which a view placed by `position` fills,
    /// rather than one of its own edges.
    private func growing(from point: CGPoint, within container: CGSize) -> AnyTransition {
        guard !reducesMotion else {
            return .opacity
        }
        let anchor = UnitPoint(x: point.x / max(1, container.width), y: point.y / max(1, container.height))
        return .scale(scale: 0.5, anchor: anchor).combined(with: .opacity)
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
