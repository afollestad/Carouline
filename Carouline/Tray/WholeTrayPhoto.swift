//
//  WholeTrayPhoto.swift
//  Carouline
//

import SwiftUI

/// A tray photo whole, at its own shape rather than within the thumbnails' range of shapes, decoded
/// at the size it's shown. The thumbnail's decode stands in meanwhile, so a photo shown larger never
/// flashes white first.
struct WholeTrayPhoto: View {
    let photo: TrayPhoto
    let projectID: UUID
    @State private var isMissing = false
    @Environment(\.imageLoader) private var loader

    var body: some View {
        var whole = photo.image
        whole.crop = ImageCrop()
        return CellPhoto(image: whole, projectID: projectID, isMissing: $isMissing) { absence in
            if absence == .loading, let decoded = loader.anyCachedImage(of: photo.image, in: projectID) {
                Image(decorative: decoded, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                PlaceholderCell(background: .white, isLoading: absence == .loading)
            }
        }
    }
}

#Preview {
    WholeTrayPhoto(
        photo: TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 1365)),
        projectID: UUID()
    )
    .frame(width: 240, height: 160)
}
