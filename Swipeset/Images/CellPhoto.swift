//
//  CellPhoto.swift
//  Swipeset
//

import SwiftUI

/// A cell's photo, framed by its crop and decoded at the size it's shown, with `missing`
/// in its place when the copy can't be read.
struct CellPhoto<Missing: View>: View {
    let image: PlacedImage
    let projectID: UUID
    /// The photo's blur, as a Gaussian's sigma in points.
    var blur: CGFloat = 0
    /// Whether the copy turned out unreadable, for the cell to offer what it can do about it.
    @Binding var isMissing: Bool
    @ViewBuilder let missing: () -> Missing
    @Environment(\.imageLoader) private var loader
    @Environment(\.displayScale) private var displayScale
    /// The last decode, kept on screen while a sharper one loads for a bigger size.
    @State private var loaded: CGImage?

    var body: some View {
        GeometryReader { proxy in
            let frame = CropGeometry.frame(imageSize: image.pixelSize, cellSize: proxy.size, crop: image.crop)
            let request = ImageRequest(
                projectID: projectID,
                image: image,
                displayedPixels: max(frame.width, frame.height) * displayScale
            )
            ZStack {
                if let shown = loaded ?? loader.cachedImage(request) {
                    photo(shown, frame: frame, cell: proxy.size)
                } else if isMissing {
                    missing()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .task(id: request) {
                let decoded = await loader.image(request)
                loaded = decoded ?? loaded
                isMissing = decoded == nil
            }
        }
        .clipped()
        // Clipping hides the photo past the cell but leaves it there to touch, so a wide photo in
        // a narrow cell would take long presses meant for its neighbors.
        .contentShape(.rect)
    }
}

extension CellPhoto {
    /// `image` drawn across `frame` in a cell of `cell`, blurred when the photo is: kept sharp at
    /// its edges, as the export's blur is, and rendered once, smaller, into its own layer, rather
    /// than on every frame the strip scrolls. Only the photo within the blur's reach of the cell
    /// renders, since the cell clips the rest and the blur draws nothing in from farther, so a
    /// zoomed photo renders no larger than its cell. Not at all when there's no blur, so every
    /// other photo draws as it did.
    @ViewBuilder
    private func photo(_ image: CGImage, frame: CGRect, cell: CGSize) -> some View {
        let reach = LayerImageEffects.blurReach * blur
        let region = frame.intersection(CGRect(origin: .zero, size: cell).insetBy(dx: -reach, dy: -reach))
        let shrink = ScreenBlur.shrink(for: blur)
        let small = CGSize(width: region.width / shrink, height: region.height / shrink)
        // A cell not yet measured has nothing to blur.
        if blur > 0, small.width > 0, small.height > 0 {
            // The soft pixel at the edge of the small render, magnified.
            let overdraw = shrink / displayScale
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: frame.width / shrink, height: frame.height / shrink)
                .offset(x: (frame.minX - region.minX) / shrink, y: (frame.minY - region.minY) / shrink)
                .frame(width: small.width, height: small.height, alignment: .topLeading)
                .clipped()
                .blur(radius: blur / shrink, opaque: true)
                .drawingGroup()
                // Drawn past its edge by that pixel, so it lands outside the cell's clip where the
                // photo's edge meets the cell's, while the photo stretches too little to see.
                .scaleEffect(
                    x: (region.width + 2 * overdraw) / small.width,
                    y: (region.height + 2 * overdraw) / small.height
                )
                .frame(width: region.width, height: region.height)
                .position(x: region.midX, y: region.midY)
        } else {
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
    }
}

/// How the screen renders a blur.
enum ScreenBlur {
    /// How many times smaller than it's shown a blur renders before it's scaled up: as much as a
    /// quarter, while the blur stays two points or more across there, which hides the coarser
    /// pixels, as `SlideBackdrop` blurs small and scales up.
    static func shrink(for radius: CGFloat) -> CGFloat {
        min(4, max(1, (radius / 2).rounded(.down)))
    }
}

extension CellPhoto where Missing == EmptyView {
    /// The photo with nothing in its place when it's missing, as thumbnails show it.
    init(image: PlacedImage, projectID: UUID, blur: CGFloat = 0) {
        self.init(image: image, projectID: projectID, blur: blur, isMissing: .constant(false)) {
            EmptyView()
        }
    }
}

#Preview {
    @Previewable @State var isMissing = false
    CellPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 3072, pixelHeight: 2048), projectID: UUID(), isMissing: $isMissing) {
        Text("Missing")
    }
    .frame(width: 200, height: 300)
}
