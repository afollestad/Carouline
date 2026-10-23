//
//  TrayPhotoPreview.swift
//  Carouline
//

import SwiftUI

/// A tray photo atop its actions' popover, as a lift after holding it opens them: the whole photo,
/// its shape, and the slides it's on.
struct TrayPhotoPreview: View {
    let photo: TrayPhoto
    let projectID: UUID
    /// The slides it's on, as "Slides 2 and 5", or nil when it's on none.
    let usedOn: String?

    /// Large enough to make out which photo it is, and small enough to leave a phone's screen room
    /// for the actions under it.
    private static let maximumSize = CGSize(width: 240, height: 160)

    var body: some View {
        let size = Self.size(of: photo.image.pixelSize, fitting: Self.maximumSize)
        VStack(alignment: .leading, spacing: 8) {
            WholeTrayPhoto(photo: photo, projectID: projectID)
                .frame(width: size.width, height: size.height)
                .clipShape(.rect(cornerRadius: 8))
            Text(caption)
                .font(.footnote)
                .foregroundStyle(Color.primary)
        }
        // In line with the actions' icons.
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// A photo of `pixels`, at its own shape, as large as fits `maximumSize`.
    static func size(of pixels: CGSize, fitting maximumSize: CGSize) -> CGSize {
        guard pixels.width > 0, pixels.height > 0 else {
            return maximumSize
        }
        let scale = min(maximumSize.width / pixels.width, maximumSize.height / pixels.height)
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
