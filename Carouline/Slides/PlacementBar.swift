//
//  PlacementBar.swift
//  Carouline
//

import SwiftUI

/// Glass controls along the bottom of the project screen while a photo is held to put in whichever
/// cell is tapped next: the photo, what to do, a new slide to start with it, and a way to let go.
struct PlacementBar: View {
    let photo: PlacedImage
    let projectID: UUID
    let held: HeldPhoto
    let onNewSlide: () -> Void
    let onCancel: () -> Void
    @State private var isMissing = false

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 12) {
                    PhotoThumbnail(image: photo, projectID: projectID, height: 36, isMissing: $isMissing)
                        .accessibilityHidden(true)
                    Text(held.isFromCell ? "Tap a cell to move this photo." : "Tap a cell or a picture for this photo.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 6)
                .padding(.trailing, 16)
                .frame(height: 48)
                .glassEffect(.regular, in: Capsule())
                Button("New Slide", systemImage: "plus.rectangle.on.rectangle", action: onNewSlide)
                    .accessibilityHint(held.isFromCell ? "Moves the photo to a new slide" : "Starts a new slide with the photo")
                Button("Cancel", systemImage: "xmark", action: onCancel)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.cancelAction)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
        // The bar's width holds the controls, not more text.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

#Preview {
    VStack {
        Spacer()
        PlacementBar(
            photo: PlacedImage(assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 1365),
            projectID: UUID(),
            held: .tray(projectID: UUID(), photoID: UUID()),
            onNewSlide: {},
            onCancel: {}
        )
    }
    .background { GlowBackdrop() }
}
