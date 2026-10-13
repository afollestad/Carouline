//
//  PictureLayerView.swift
//  Swipeset
//

import SwiftUI

/// A picture in its frame, inside its border: a ring of its border color around an opaque
/// picture, and an outline tracing a transparent one's shape.
struct PictureLayerView: View {
    let picture: ImageLayer
    let projectID: UUID
    let background: RGBColor
    let size: CGSize
    @State private var isMissing = false

    var body: some View {
        let border = LayerGeometry.borderWidth(of: picture, inFrame: size)
        CellPhoto(image: picture.image, projectID: projectID, isMissing: $isMissing) {
            MissingLayerPicture(background: background)
        }
        .frame(width: max(0, size.width - 2 * border), height: max(0, size.height - 2 * border))
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
    }
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

/// What a picture layer shows when its copy can't be read: the fill a missing photo shows, with
/// a warning.
private struct MissingLayerPicture: View {
    let background: RGBColor

    var body: some View {
        ZStack {
            PlaceholderCell(background: background)
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(Color.secondary)
                .accessibilityHidden(true)
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
