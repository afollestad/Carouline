//
//  AddImageLayerPage.swift
//  Carouline
//

import SwiftUI

/// The layers sheet's page for picking a picture to add as a layer: one of the tray's photos, or
/// one from the library, through the picker.
struct AddImageLayerPage: View {
    let library: ProjectLibrary
    let projectID: UUID
    let slideID: UUID
    /// Adds a tray photo's picture as a layer.
    let onAdd: (TrayPhoto) -> Void
    /// Opens the picker for a picture from the library.
    let chooseFromLibrary: () -> Void
    let close: () -> Void

    @Environment(\.layersSheetMargin) private var margin

    /// Large enough to tell photos apart, with three or four to a phone's row.
    private static let thumbnailHeight: CGFloat = 96

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button(action: chooseFromLibrary) {
                    Label("Choose from Library…", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                // Solid, with white on it, which keeps its contrast on the sheet's glass.
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(library.importingLayers[slideID] != nil)
                let tray = library.project(projectID)?.tray ?? []
                if tray.isEmpty {
                    Text("Photos you gather in the tray show here too.")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                } else {
                    Text("From the Tray")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.thumbnailHeight * 0.75), spacing: 8)], spacing: 8) {
                        ForEach(Array(tray.enumerated()), id: \.element.id) { index, photo in
                            thumbnail(photo, position: "Photo \(index + 1) of \(tray.count)")
                        }
                    }
                }
            }
            // The top is `LayerPage`'s.
            .padding([.horizontal, .bottom], margin)
        }
        .layerPage("Add Image", close: close)
    }

    private func thumbnail(_ photo: TrayPhoto, position: String) -> some View {
        Button {
            onAdd(photo)
        } label: {
            TrayPhotoTile(photo: photo, projectID: projectID, height: Self.thumbnailHeight)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .disabled(library.importingLayers[slideID] != nil)
        .accessibilityLabel("\(position), \(Orientation(of: photo.image.pixelSize).name)")
        .accessibilityHint("Adds the photo to the slide as a layer")
    }
}

/// A tray photo filling a square of `height`, cropped to it, so a grid of them lines up.
private struct TrayPhotoTile: View {
    let photo: TrayPhoto
    let projectID: UUID
    let height: CGFloat
    @State private var isMissing = false

    var body: some View {
        var whole = photo.image
        whole.crop = ImageCrop()
        return CellPhoto(image: whole, projectID: projectID, isMissing: $isMissing) { absence in
            PlaceholderCell(background: .white, isLoading: absence == .loading)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 8))
        .opacity(isMissing ? 0.4 : 1)
    }
}

#Preview {
    NavigationStack {
        AddImageLayerPage(
            library: ProjectLibrary(store: MockProjectStore(), projects: SampleProjects.all),
            projectID: SampleProjects.sampleID(1),
            slideID: SampleProjects.sampleID(11),
            onAdd: { _ in },
            chooseFromLibrary: {},
            close: {}
        )
    }
    .tint(.accentColor)
}
