//
//  TrayPhotoPreview.swift
//  Carouline
//

import SwiftUI

/// A tray photo shown large, as a long press on its thumbnail lifts it: the whole photo, its shape,
/// and the slides it's on.
struct TrayPhotoPreview: View {
    let photo: TrayPhoto
    let projectID: UUID
    /// The slides it's on, as "Slides 2 and 5", or nil when it's on none.
    let usedOn: String?
    @State private var isMissing = false

    /// Large enough to judge a photo by, and within what a phone's menu leaves for its preview.
    private static let maximumSize = CGSize(width: 320, height: 400)

    var body: some View {
        // Whole, at its own shape, rather than within the thumbnails' range of shapes.
        var whole = photo.image
        whole.crop = ImageCrop()
        return VStack(alignment: .leading, spacing: 0) {
            CellPhoto(image: whole, projectID: projectID, isMissing: $isMissing) { absence in
                PlaceholderCell(background: .white, isLoading: absence == .loading)
            }
            .frame(width: size.width, height: size.height)
            Text(caption)
                .font(.footnote)
                .foregroundStyle(Color.primary)
                .padding(12)
        }
        .frame(width: size.width)
    }

    /// The photo's own shape, as large as fits `maximumSize`.
    private var size: CGSize {
        let pixels = photo.image.pixelSize
        guard pixels.width > 0, pixels.height > 0 else {
            return Self.maximumSize
        }
        let scale = min(Self.maximumSize.width / pixels.width, Self.maximumSize.height / pixels.height)
        return CGSize(width: (pixels.width * scale).rounded(), height: (pixels.height * scale).rounded())
    }

    private var caption: String {
        let shape = Orientation(of: photo.image.pixelSize).name.capitalizingFirstLetter
        return "\(shape) · \(usedOn.map { "On \($0)" } ?? "Not on a slide yet")"
    }
}

#Preview {
    TrayPhotoPreview(
        photo: TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 1365)),
        projectID: UUID(),
        usedOn: "Slides 2 and 5"
    )
}
