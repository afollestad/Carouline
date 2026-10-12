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
                    Image(decorative: shown, scale: 1)
                        .resizable()
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
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

extension CellPhoto where Missing == EmptyView {
    /// The photo with nothing in its place when it's missing, as thumbnails show it.
    init(image: PlacedImage, projectID: UUID) {
        self.init(image: image, projectID: projectID, isMissing: .constant(false)) {
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
