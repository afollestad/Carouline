//
//  TrayThumbnail.swift
//  Carouline
//

import SwiftUI

/// One photo in the tray: a tap puts it on a slide, and a long press shows it large, with what
/// else it can do.
struct TrayThumbnail: View {
    let photo: TrayPhoto
    let projectID: UUID
    /// Whether it's on a slide, which a badge marks.
    let isUsed: Bool
    /// Where it sits in the tray, as in "photo 3 of 12", for VoiceOver.
    let position: String
    /// The slides it's on, as "Slides 2 and 5", for its preview, or nil when it's on none.
    let usedOn: String?
    let actions: TrayActions
    @State private var isMissing = false
    @Environment(\.imageLoader) private var loader

    /// Tall enough to make out what's in a photo, with room above and below in the bar's glass.
    static let height: CGFloat = 44

    var body: some View {
        Button {
            if isMissing {
                actions.restore(photo.id)
            } else {
                actions.place(photo.id)
            }
        } label: {
            PhotoThumbnail(image: photo.image, projectID: projectID, height: Self.height, isMissing: $isMissing)
                .overlay(alignment: .topTrailing) {
                    if isUsed {
                        UsedBadge()
                    }
                }
                // Over the photo, rather than a modifier on it, so turning dragging off for a
                // missing copy leaves the photo and what it has loaded alone.
                .overlay {
                    if !isMissing {
                        dragSurface
                    }
                }
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .contextMenu {
            menu
        } preview: {
            TrayPhotoPreview(photo: photo, projectID: projectID, usedOn: usedOn)
                // A preview renders apart from the tray, where it would find the sample loader.
                .environment(\.imageLoader, loader)
        }
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .accessibilityDragPoint(.center, description: "Photo", isEnabled: !isMissing)
        .accessibilityActions {
            menu
        }
        .task(id: isMissing) {
            if isMissing {
                actions.restoreQuietly(photo.id)
            }
        }
    }

    /// A clear surface a long press lifts the photo from, to drop on a cell.
    private var dragSurface: some View {
        Color.clear
            .contentShape(.rect)
            .draggable(HeldPhoto.tray(projectID: projectID, photoID: photo.id)) {
                PhotoDragPreview(image: photo.image, projectID: projectID, loader: loader)
            }
    }

    @ViewBuilder
    private var menu: some View {
        if isMissing {
            if photo.image.assetIdentifier != nil {
                Button("Restore from Photos", systemImage: "arrow.clockwise") {
                    actions.restore(photo.id)
                }
            }
        } else {
            if let roomInFront = actions.roomInFront {
                Button("Add to \(roomInFront)", systemImage: "plus.square.on.square") {
                    actions.place(photo.id)
                }
            }
            Button("Choose a Cell…", systemImage: "hand.tap") {
                actions.hold(photo.id)
            }
            Button("Start a Slide…", systemImage: "plus.rectangle.on.rectangle") {
                actions.startSlide(photo.id)
            }
        }
        Divider()
        Button("Remove from Tray", systemImage: "trash", role: .destructive) {
            actions.remove(photo.id)
        }
    }

    private var label: String {
        let shape = Orientation(of: photo.image.pixelSize).name
        if isMissing {
            return "\(position.capitalizingFirstLetter), unavailable"
        }
        return "\(position.capitalizingFirstLetter), \(shape)\(isUsed ? ", on a slide" : "")"
    }

    private var hint: String {
        if isMissing {
            photo.image.assetIdentifier == nil ? "" : "Restores the photo from your library"
        } else {
            actions.placeHint
        }
    }
}

/// A check on solid accent in a thumbnail's corner, marking a photo that's on a slide. White on
/// the accent, which a faint tint would wash out on the glass.
private struct UsedBadge: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(Color.accentColor, in: .circle)
            .padding(3)
            .accessibilityHidden(true)
    }
}

/// How a photo's shape reads.
nonisolated enum Orientation {
    case portrait
    case landscape
    case square
    /// Twice as wide as it's high or more, as a panorama's photo is.
    case wide

    init(of size: CGSize) {
        let aspect = size.height > 0 ? size.width / size.height : 1
        self = if aspect >= 2 {
            .wide
        } else if aspect > 1.05 {
            .landscape
        } else if aspect < 0.95 {
            .portrait
        } else {
            .square
        }
    }

    var name: String {
        switch self {
        case .portrait: "portrait"
        case .landscape: "landscape"
        case .square: "square"
        case .wide: "panoramic"
        }
    }
}

#Preview {
    HStack {
        TrayThumbnail(
            photo: TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 1365)),
            projectID: UUID(),
            isUsed: true,
            position: "photo 1 of 2",
            usedOn: "Slide 2",
            actions: .preview
        )
        TrayThumbnail(
            photo: TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 1536, pixelHeight: 2048)),
            projectID: UUID(),
            isUsed: false,
            position: "photo 2 of 2",
            usedOn: nil,
            actions: .preview
        )
    }
    .padding()
}
