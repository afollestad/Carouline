//
//  PhotoDragPreview.swift
//  Carouline
//

import SwiftUI

/// A photo as a drag lifts it: whole, at a thumbnail's shape, from whatever decode of it is
/// already in memory. A drag's preview is drawn once, as it lifts, so one that waited for a decode
/// at its own size would only ever show the placeholder.
struct PhotoDragPreview: View {
    let image: PlacedImage
    let projectID: UUID
    /// Where the photo's decodes are, which a preview drawn apart from the screen has to be handed.
    let loader: any ImageLoading

    /// Large enough to make out under a finger.
    private static let height: CGFloat = 96

    var body: some View {
        let width = PhotoThumbnail.width(for: image.pixelSize, height: Self.height)
        Group {
            if let decoded = loader.anyCachedImage(of: image, in: projectID) {
                Image(decorative: decoded, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.fill.secondary)
            }
        }
        .frame(width: width, height: Self.height)
        .clipShape(.rect(cornerRadius: 8))
    }
}

#Preview {
    PhotoDragPreview(
        image: PlacedImage(assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 1365),
        projectID: UUID(),
        loader: MockImageLoader()
    )
}
