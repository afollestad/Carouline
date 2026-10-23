//
//  TrayLoupe.swift
//  Carouline
//

import SwiftUI

/// A tray photo shown large above the tray while a finger holds it: whole, at its own shape. The
/// photo alone, without glass or a caption, which over slides of any color wouldn't read.
struct TrayLoupe: View {
    let photo: TrayPhoto
    let projectID: UUID

    /// Large enough to judge a photo by, and small enough to leave most of the slide above in view,
    /// within a phone's width with room either side.
    static let maximumSize = CGSize(width: 260, height: 260)
    private static let cornerRadius: CGFloat = 12

    var body: some View {
        let size = Self.size(of: photo)
        WholeTrayPhoto(photo: photo, projectID: projectID)
            .frame(width: size.width, height: size.height)
            .clipShape(.rect(cornerRadius: Self.cornerRadius))
            // A hairline, so a photo the color of the slides behind still shows its edges.
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
    }

    static func size(of photo: TrayPhoto) -> CGSize {
        TrayPhotoPreview.size(of: photo.image.pixelSize, fitting: maximumSize)
    }
}

#Preview {
    TrayLoupe(
        photo: TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 1365)),
        projectID: UUID()
    )
    .padding()
    .background { GlowBackdrop() }
}
