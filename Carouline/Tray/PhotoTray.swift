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
            Image(systemName: "photo.badge.plus")
                .font(.title3.weight(.semibold))
                // Past this, the wide glyph crowds its circle, which keeps the tray's height.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
        TrayPhotoStrip(project: project, importingCount: importingCount, actions: actions)
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

/// The tray's photos along their capsule of glass, which a finger held on them magnifies one by
/// one, scrolling by itself at either end, or carries up onto a cell. Apart from the tray, so the
/// scroll a press drives each frame redraws the photos alone.
private struct TrayPhotoStrip: View {
    let project: Project
    let importingCount: Int
    let actions: TrayActions
    @State private var scroll = ScrollPosition()
    /// Scrolls the tray along each frame while a finger is held at either end.
    @State private var edgeTicker = FrameTicker()
    @Environment(TrayPress.self) private var press: TrayPress?
    @Environment(\.shownPopovers) private var popovers

    var body: some View {
        let holding = project.trayPhotoPlaces
        let count = project.tray.count
        ScrollView(.horizontal) {
            LazyHStack(spacing: TrayLayout.spacing) {
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
            .padding(.horizontal, TrayLayout.inset)
            .frame(height: PhotoTray.height)
        }
        .scrollPosition($scroll)
        .scrollIndicators(.hidden)
        // Held still under a finger held on a photo, as it slides along, scrolling itself at the
        // ends instead.
        .scrollDisabled(press?.photoID != nil)
        .frame(height: PhotoTray.height)
        .onScrollGeometryChange(for: TrayScroll.self) { geometry in
            TrayScroll(offset: geometry.visibleRect.minX, maxOffset: max(0, geometry.contentSize.width - geometry.visibleRect.width))
        } action: { _, scroll in
            press?.trayScrolled(to: scroll.offset, maxOffset: scroll.maxOffset)
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            press?.setCapsule(frame)
        }
        .onChange(of: TrayLayout(photos: project.tray, importingCount: importingCount), initial: true) { _, layout in
            press?.setLayout(layout)
        }
        .gesture(TrayPressGesture(
            onBegin: { location in
                press?.begin(at: location)
                followEdge()
            },
            onMove: { location in
                press?.move(to: location)
                followEdge()
            },
            onEnd: end(at:),
            onCancel: {
                edgeTicker.stop()
                press?.cancel()
            }
        ))
        .gesture(TraySecondaryClick { location in
            if let photoID = press?.photo(at: location) {
                openMenu(photoID)
            }
        })
        .onDisappear {
            edgeTicker.stop()
            press?.cancel()
        }
        // Glass doesn't clip what's on it, and a photo scrolled past its ends would show outside.
        // Clipped before the glass, since a clip after it leaves what's on the glass unclipped.
        .clipShape(.capsule)
        .glassEffect(.regular, in: .capsule)
    }

    /// Scrolls the tray along each frame while the finger is at an end it can still scroll toward,
    /// as the strip does along a panorama for a layer held at its edge.
    private func followEdge() {
        guard press?.isAtEdge == true else {
            edgeTicker.stop()
            return
        }
        if !edgeTicker.isRunning {
            edgeTicker.start { seconds in
                if let offset = press?.scrolled(by: seconds) {
                    scroll.scrollTo(x: offset)
                } else if press?.isAtEdge != true {
                    edgeTicker.stop()
                }
            }
        }
    }

    /// Lands a photo carried off the tray in the cell it's let go over, or opens the actions of one
    /// lifted in the tray.
    private func end(at location: CGPoint) {
        edgeTicker.stop()
        press?.move(to: location)
        switch press?.end() {
        case .menu(let photoID): openMenu(photoID)
        case .drop(let photoID, let address): actions.drop(photoID, address)
        case nil: break
        }
    }

    /// Opens `photoID`'s actions, once any popover still closing has gone, which would cancel them.
    private func openMenu(_ photoID: UUID) {
        popovers.whenGone {
            press?.menuPhotoID = photoID
        }
    }
}

/// Where the tray is scrolled to along its photos, and how far it scrolls.
private struct TrayScroll: Equatable {
    let offset: CGFloat
    let maxOffset: CGFloat
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
