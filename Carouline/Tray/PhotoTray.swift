//
//  PhotoTray.swift
//  Carouline
//

import SwiftUI
import UniformTypeIdentifiers

/// Glass along the bottom of the project screen with the photos gathered to see before they go on
/// a slide: a button to gather more, then the photos in the order they were added, each marked
/// once it's on a slide, with how many cells hold it once that's more than one.
struct PhotoTray: View {
    let project: Project
    /// How many photos are on their way in, which hold places at the end.
    let importingCount: Int
    let actions: TrayActions
    /// Whether images from another app are over the tray, to drop into it.
    @State private var isDropTargeted = false

    /// The glass's height: a thumbnail with room above and below, within the band the strip keeps
    /// clear along the bottom.
    static let height: CGFloat = 56

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            if project.tray.isEmpty && importingCount == 0 {
                emptyTray
            } else {
                HStack(spacing: 10) {
                    addButton
                    photos
                }
            }
        }
        .onDrop(of: [.image], isTargeted: $isDropTargeted) { providers in
            actions.addDropped(IncomingPhoto.dropped(providers))
            return true
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
        // The bar's height holds the photos, not more text.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// One button to gather the first photos, saying what the tray is for.
    private var emptyTray: some View {
        Button(action: actions.addPhotos) {
            Label("Add Photos", systemImage: "photo.badge.plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 24)
                .frame(height: Self.height)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .overlay {
            dropHighlight(in: Capsule())
        }
        .accessibilityHint("Gathers photos to see here before they go on a slide")
        .tourTarget(.addPhotos)
    }

    private var addButton: some View {
        Button(action: actions.addPhotos) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primary)
                .frame(width: Self.height, height: Self.height)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Add Photos")
        .accessibilityHint("Gathers more photos into the tray")
        .tourTarget(.addPhotos)
    }

    private var photos: some View {
        let holding = project.trayPhotoPlaces
        let count = project.tray.count
        return ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(Array(project.tray.enumerated()), id: \.element.id) { index, photo in
                    let places = holding[photo.id] ?? []
                    TrayThumbnail(
                        photo: photo,
                        projectID: project.id,
                        places: places,
                        position: "photo \(index + 1) of \(count)",
                        usedOn: places.isEmpty ? nil : project.slidesName(at: places.slideIndexes),
                        actions: actions
                    )
                }
                ForEach(0..<importingCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.fill.tertiary)
                        .frame(width: TrayThumbnail.height, height: TrayThumbnail.height)
                        .loadingPulse()
                        .accessibilityHidden(true)
                }
            }
            // Padded rather than `contentMargins`, and past the glass's rounded ends.
            .padding(.horizontal, 14)
            .frame(height: Self.height)
        }
        .scrollIndicators(.hidden)
        .frame(height: Self.height)
        // Glass doesn't clip what's on it, and a photo scrolled past its ends would show outside.
        // Clipped before the glass, since a clip after it leaves what's on the glass unclipped.
        .clipShape(.capsule)
        .glassEffect(.regular, in: .capsule)
        .overlay {
            dropHighlight(in: Capsule())
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tray")
        .tourTarget(.trayPhotos)
    }
}

extension PhotoTray {
    /// A tint ring round `shape` while images from another app are over the tray.
    @ViewBuilder
    private func dropHighlight(in shape: some InsettableShape) -> some View {
        if isDropTargeted {
            shape
                .strokeBorder(.tint, lineWidth: 3)
                .accessibilityHidden(true)
        }
    }
}

#Preview("Photos") {
    let project = SampleProjects.all[0]
    VStack {
        Spacer()
        PhotoTray(project: project, importingCount: 1, actions: .preview)
    }
    .background { GlowBackdrop() }
}

#Preview("Empty") {
    VStack {
        Spacer()
        PhotoTray(project: Project(name: "Empty", aspectRatio: .portrait), importingCount: 0, actions: .preview)
    }
    .background { GlowBackdrop() }
}
