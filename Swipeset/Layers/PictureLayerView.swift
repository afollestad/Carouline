//
//  PictureLayerView.swift
//  Swipeset
//

import SwiftUI

/// A picture in its frame, inside its border: a ring of its border color around an opaque
/// picture, and an outline tracing a transparent one's shape. An opaque picture's blur stays in
/// its frame, and a transparent one's spreads past its edges, as it does in the export.
struct PictureLayerView: View {
    let picture: ImageLayer
    let projectID: UUID
    let background: RGBColor
    let size: CGSize
    @State private var isMissing = false
    @Environment(\.missingPictureActions) private var missingActions

    var body: some View {
        let border = LayerGeometry.borderWidth(of: picture, inFrame: size)
        let pictureSize = CGSize(width: max(0, size.width - 2 * border), height: max(0, size.height - 2 * border))
        let blur = LayerGeometry.blurRadius(of: picture, pictureSize: pictureSize)
        let isTransparent = picture.image.fileFormat == .png
        CellPhoto(image: picture.image, projectID: projectID, blur: isTransparent ? 0 : blur, isMissing: $isMissing) {
            MissingLayerPicture(background: background)
        }
        .frame(width: pictureSize.width, height: pictureSize.height)
        .modifier(SpreadingBlur(radius: isTransparent && !isMissing ? blur : 0, size: pictureSize))
        .padding(border)
        .background {
            if picture.image.fileFormat == .jpeg {
                picture.borderColor.color
            } else if border > 0, !isMissing {
                PictureOutline(picture: picture, projectID: projectID, size: size)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(isMissing ? "Image layer, unavailable" : "Image layer")
        .accessibilityAddTraits(isMissing ? [] : .isImage)
        // The placeholder's menu, which VoiceOver passes over within the one element.
        .accessibilityActions {
            if isMissing, let missingActions, missingActions.canRestore {
                Button("Restore from Photos", action: missingActions.restore)
            }
        }
    }
}

/// What a missing picture's placeholder offers on the strip: restoring its copy from the photo
/// library, which it also tries once as it's shown, and deleting its layer. Thumbnails and
/// previews, which have none, show just the placeholder.
struct MissingPictureActions {
    /// Whether the picture came from the photo library, which it can come back from.
    let canRestore: Bool
    let restore: () -> Void
    let restoreQuietly: () -> Void
    let delete: () -> Void
}

extension EnvironmentValues {
    @Entry var missingPictureActions: MissingPictureActions?
}

/// A transparent picture's outline, filling the layer's frame of `size`. It renders from the
/// picture at about the size it's shown, up to `LayerImageEffects.screenSide`, whenever the
/// picture, its border or its color changes, keeping the last render on screen meanwhile, and
/// otherwise scales with the layer, so moving and pinching render again only past a size bucket.
/// A render already made shows on the first frame, as a layer drawn anew needs.
private struct PictureOutline: View {
    let picture: ImageLayer
    let projectID: UUID
    let size: CGSize
    @Environment(\.imageLoader) private var loader
    @Environment(\.displayScale) private var displayScale
    @State private var outline: CGImage?
    /// Whether this view has rendered yet, after which a change waits for the next one.
    @State private var hasRendered = false

    /// Long enough for a slider's next step to arrive, so a drag renders where it rests rather
    /// than at every step, and short enough that the outline still reads as following it.
    private static let settleDelay = Duration.milliseconds(60)

    /// What the outline is rendered from, short of the picture's blur, which it ignores.
    private struct Source: Hashable {
        let imageID: UUID
        let width: Double
        let color: RGBColor
        let pixels: Int
    }

    var body: some View {
        let pixels = min(ImageRequest.bucket(for: max(size.width, size.height) * displayScale), LayerImageEffects.screenSide)
        let cached = LayerImageEffects.cachedScreenOutline(for: picture, pixels: pixels)
        ZStack {
            if let shown = cached ?? outline {
                Image(decorative: shown, scale: 1)
                    .resizable()
            }
        }
        .task(id: Source(imageID: picture.image.id, width: picture.borderWidth, color: picture.borderColor, pixels: pixels)) {
            if let cached {
                outline = cached
                return
            }
            // Only a change waits, since a first outline has nothing to stand in for it.
            if hasRendered {
                try? await Task.sleep(for: Self.settleDelay)
            }
            hasRendered = true
            let request = ImageRequest(projectID: projectID, image: picture.image, displayedPixels: CGFloat(pixels))
            guard !Task.isCancelled, let image = await loader.image(request), !Task.isCancelled else {
                return
            }
            let rendered = await LayerImageEffects.screenOutline(of: image, for: picture)
            // A newer border's render takes over from a slower, older one.
            guard !Task.isCancelled, let rendered else {
                return
            }
            LayerImageEffects.keepScreenOutline(rendered, for: picture, pixels: pixels)
            outline = rendered
        }
        .accessibilityHidden(true)
    }
}

/// A transparent picture of `size`'s blur, spreading past its edges, rendered once, smaller,
/// into a layer with room for the spread, rather than on every frame the strip scrolls.
private struct SpreadingBlur: ViewModifier {
    let radius: CGFloat
    let size: CGSize

    func body(content: Content) -> some View {
        if radius > 0 {
            let shrink = ScreenBlur.shrink(for: radius)
            let reach = LayerImageEffects.blurReach * radius / shrink
            content
                .scaleEffect(1 / shrink)
                .frame(width: size.width / shrink, height: size.height / shrink)
                .blur(radius: radius / shrink)
                .padding(reach)
                .drawingGroup()
                .padding(-reach)
                .scaleEffect(shrink)
                .frame(width: size.width, height: size.height)
        } else {
            content
        }
    }
}

/// What a picture layer shows when its copy can't be read: the fill a missing photo shows, with
/// a warning, which on the strip is a menu of what can be done about it.
private struct MissingLayerPicture: View {
    let background: RGBColor
    @Environment(\.missingPictureActions) private var actions
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            PlaceholderCell(background: background)
            if let actions {
                Menu {
                    if actions.canRestore {
                        Button("Restore from Photos", systemImage: "arrow.clockwise", action: actions.restore)
                    }
                    Button("Delete Layer", systemImage: "trash", role: .destructive, action: actions.delete)
                } label: {
                    Label("Image Unavailable", systemImage: "exclamationmark.triangle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                // From the placeholder under it, as glass over a slide takes its scheme.
                .environment(\.colorScheme, PlaceholderCell.isLight(on: background, in: colorScheme) ? .light : .dark)
                .task {
                    actions.restoreQuietly()
                }
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    let sticker = ImageLayer(
        image: PlacedImage(assetIdentifier: nil, pixelWidth: 600, pixelHeight: 600, fileFormat: .png),
        borderWidth: 0.05
    )
    let photo = ImageLayer(image: PlacedImage(assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 1536), borderWidth: 0.04)
    HStack(spacing: 24) {
        PictureLayerView(picture: sticker, projectID: UUID(), background: .white, size: CGSize(width: 160, height: 160))
        PictureLayerView(picture: photo, projectID: UUID(), background: .white, size: CGSize(width: 160, height: 125))
    }
    .padding()
    .background(.teal)
}
