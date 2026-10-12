//
//  SelectionBar.swift
//  Swipeset
//

import SwiftUI

/// Glass controls for the selected photo along the bottom of the project screen: replace or
/// remove it, zoom it, reset its framing, and finish. Replacing and removing share a menu, which
/// leaves the slider room to move in.
struct SelectionBar: View {
    /// The height the strip keeps clear for the bar, so selecting a photo never moves a slide.
    static let reservedHeight: CGFloat = 76

    let photo: PlacedImage
    let session: CropSession
    let hasCamera: Bool
    let onChoosePhoto: () -> Void
    let onTakePhoto: () -> Void
    let onReset: () -> Void
    let onRemove: () -> Void
    /// Saves the slider's crop once it's let go.
    let onCommitZoom: () -> Void
    let onDone: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    Section("Replace Photo") {
                        Button("Choose from Library", systemImage: "photo.on.rectangle", action: onChoosePhoto)
                        if hasCamera {
                            Button("Take Photo", systemImage: "camera", action: onTakePhoto)
                        }
                    }
                    Button("Remove Photo", systemImage: "trash", role: .destructive, action: onRemove)
                } label: {
                    Label("Photo Options", systemImage: "photo")
                }
                zoomSlider
                Button("Reset Framing", systemImage: "arrow.counterclockwise", action: onReset)
                    .disabled(crop == ImageCrop())
                Button("Done", systemImage: "checkmark", action: onDone)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
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

    private var crop: ImageCrop {
        session.liveCrop ?? photo.crop
    }

    private var zoomSlider: some View {
        Slider(value: zoom, in: 1...ImageCrop.maximumScale) {
            Text("Zoom")
        } onEditingChanged: { isEditing in
            if !isEditing {
                onCommitZoom()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .glassEffect(.regular, in: Capsule())
    }

    private var zoom: Binding<Double> {
        Binding {
            crop.scale
        } set: { scale in
            // Until the cell has measured itself there's nothing to frame the zoom in.
            guard session.cellSize.width > 0, session.cellSize.height > 0 else {
                return
            }
            session.liveCrop = CropGeometry.zoomed(crop, to: scale, imageSize: photo.pixelSize, cellSize: session.cellSize)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        SelectionBar(
            photo: PlacedImage(assetIdentifier: nil, pixelWidth: 3072, pixelHeight: 2048, crop: ImageCrop(scale: 2)),
            session: CropSession(),
            hasCamera: true,
            onChoosePhoto: {},
            onTakePhoto: {},
            onReset: {},
            onRemove: {},
            onCommitZoom: {},
            onDone: {}
        )
    }
    .background(Color(.systemGroupedBackground))
}
