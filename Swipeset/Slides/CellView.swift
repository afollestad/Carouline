//
//  CellView.swift
//  Swipeset
//

import SwiftUI

/// What a cell can ask its screen to do.
struct CellActions {
    let choosePhoto: (CellAddress) -> Void
    /// Nil without a camera, as in the simulator.
    let takePhoto: ((CellAddress) -> Void)?
    let removePhoto: (CellAddress) -> Void
    /// Selects the photo to frame it.
    let select: (CellAddress) -> Void
    let setCrop: (ImageCrop, CellAddress) -> Void

    static let preview = CellActions(
        choosePhoto: { _ in },
        takePhoto: { _ in },
        removePhoto: { _ in },
        select: { _ in },
        setCrop: { _, _ in }
    )
}

/// One cell of a slide on the project screen: a button to fill it, its photo, or what's left
/// when the photo's copy is gone.
struct CellView: View {
    let cell: Cell
    let address: CellAddress
    let background: RGBColor
    /// Where the cell sits, as in "photo 2 of 3", for VoiceOver.
    let position: String
    let isImporting: Bool
    let actions: CellActions
    let session: CropSession
    @State private var size: CGSize = .zero
    /// The crop when the current drag or pinch began, which the gesture's values build on.
    @State private var gestureStart: ImageCrop?

    var body: some View {
        ZStack {
            PlaceholderCell(background: background)
            if let image = cell.image {
                photo(image)
            } else if !isImporting {
                AddPhotoButton(position: position, offersSources: actions.takePhoto != nil) {
                    sourceButtons
                } choose: {
                    actions.choosePhoto(address)
                }
            }
            if isImporting {
                ProgressView()
                    .padding(12)
                    .glassEffect(.regular, in: Circle())
                    .accessibilityLabel("Adding \(position)")
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            self.size = size
            if isSelected {
                session.cellSize = size
            }
        }
        // A selection made elsewhere, as on launch, still needs the cell's size for the zoom slider.
        .onChange(of: isSelected, initial: true) { _, isSelected in
            if isSelected {
                session.cellSize = size
            }
        }
        // Glass over the slide takes its scheme from the slide's background rather than the
        // system's, or a dark-mode button on a white slide turns pale gray under a white symbol.
        .environment(\.colorScheme, background.isLight ? .light : .dark)
    }

    private var isSelected: Bool {
        session.selection == address
    }

    private func photo(_ image: PlacedImage) -> some View {
        let isSelected = isSelected
        var shown = image
        // Only the selected cell reads the live crop, so a drag redraws it alone.
        if isSelected, let liveCrop = session.liveCrop {
            shown.crop = liveCrop
        }
        return CellPhoto(image: shown, projectID: address.projectID) {
            MissingPhoto(position: position, menu: photoMenu)
        }
        .id(image.id)
        .overlay {
            if isSelected {
                Rectangle()
                    .strokeBorder(.tint, lineWidth: 3)
                    .accessibilityHidden(true)
            }
        }
        .gesture(cropGesture(for: image), isEnabled: isSelected)
        .onTapGesture {
            if !isSelected {
                select()
            }
        }
        .accessibilityElement()
        .accessibilityLabel(position.capitalizingFirstLetter)
        .accessibilityAddTraits(isSelected ? [.isImage, .isSelected] : [.isImage])
        .accessibilityHint(isSelected ? "" : "Selects the photo to move and zoom it")
        .accessibilityAction {
            select()
        }
        .accessibilityActions {
            if isSelected {
                Button("Move Photo Left") { nudge(image, x: -1, y: 0) }
                Button("Move Photo Right") { nudge(image, x: 1, y: 0) }
                Button("Move Photo Up") { nudge(image, x: 0, y: -1) }
                Button("Move Photo Down") { nudge(image, x: 0, y: 1) }
            }
            photoMenu
        }
        // No menu while framing, where a long press is the start of a drag, and the bar below
        // offers the same choices.
        .contextMenu {
            if !isSelected {
                photoMenu
            }
        }
    }

    private func select() {
        session.cellSize = size
        actions.select(address)
    }

    /// Drags pan and pinches zoom about where they started, together in one gesture, each
    /// measured from the crop at the gesture's start so the photo tracks the fingers exactly.
    private func cropGesture(for image: PlacedImage) -> some Gesture {
        SimultaneousGesture(DragGesture(minimumDistance: 0), MagnifyGesture())
            .onChanged { value in
                let start = gestureStart ?? session.liveCrop ?? image.crop
                gestureStart = start
                var crop = start
                if let magnify = value.second {
                    crop = CropGeometry.zoomed(
                        crop,
                        by: magnify.magnification,
                        about: magnify.startLocation,
                        imageSize: image.pixelSize,
                        cellSize: size
                    )
                }
                if let drag = value.first {
                    crop = CropGeometry.panned(crop, by: drag.translation, imageSize: image.pixelSize, cellSize: size)
                }
                session.liveCrop = crop
            }
            .onEnded { _ in
                if let crop = session.liveCrop {
                    actions.setCrop(crop, address)
                }
                session.liveCrop = nil
                gestureStart = nil
            }
    }

    /// Moves the photo a tenth of the cell, for VoiceOver, which can't drag.
    private func nudge(_ image: PlacedImage, x: CGFloat, y: CGFloat) {
        let crop = CropGeometry.panned(
            image.crop,
            by: CGSize(width: x * size.width / 10, height: y * size.height / 10),
            imageSize: image.pixelSize,
            cellSize: size
        )
        actions.setCrop(crop, address)
    }

    @ViewBuilder
    private var sourceButtons: some View {
        Button("Choose from Library", systemImage: "photo.on.rectangle") {
            actions.choosePhoto(address)
        }
        if let takePhoto = actions.takePhoto {
            Button("Take Photo", systemImage: "camera") {
                takePhoto(address)
            }
        }
    }

    @ViewBuilder
    private var photoMenu: some View {
        Section("Replace Photo") {
            sourceButtons
        }
        Button("Remove Photo", systemImage: "trash", role: .destructive) {
            actions.removePhoto(address)
        }
    }
}

/// A glass circle with a plus, which offers the library and the camera when there is one, and
/// goes straight to the library when there isn't.
private struct AddPhotoButton<Sources: View>: View {
    let position: String
    /// Whether there's more than the library to choose from.
    let offersSources: Bool
    @ViewBuilder let sources: () -> Sources
    let choose: () -> Void

    var body: some View {
        Group {
            if offersSources {
                Menu(content: sources) {
                    label
                }
            } else {
                Button(action: choose) {
                    label
                }
            }
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Add \(position)")
        .accessibilityHint("Fills this cell with a photo")
    }

    private var label: some View {
        Image(systemName: "plus")
            .font(.title3.weight(.semibold))
            .frame(width: 28, height: 28)
    }
}

/// What a cell shows when its photo's copy can't be read: a warning, and the ways to fill it again.
private struct MissingPhoto<MenuContent: View>: View {
    let position: String
    let menu: MenuContent

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(Color.secondary)
                .accessibilityHidden(true)
            Menu {
                menu
            } label: {
                Text("Photo Unavailable")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("\(position.capitalizingFirstLetter), unavailable")
            .accessibilityHint("Replace or remove the missing photo")
        }
        .padding(8)
    }
}

private extension String {
    var capitalizingFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}

#Preview {
    let projectID = UUID()
    let slide = Slide(layout: .grid, cells: [
        Cell(image: PlacedImage(assetIdentifier: nil, pixelWidth: 3072, pixelHeight: 2048)),
        Cell(),
        Cell(image: PlacedImage(id: UUID(), assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 3072)),
        Cell()
    ])
    SlideView(slide: slide, style: .standard) { index in
        CellView(
            cell: slide.cells[index],
            address: CellAddress(projectID: projectID, slideID: slide.id, index: index),
            background: .white,
            position: "photo \(index + 1) of 4",
            isImporting: index == 3,
            actions: .preview,
            session: CropSession(selection: CellAddress(projectID: projectID, slideID: slide.id, index: 0))
        )
    }
    .frame(width: 320, height: 400)
    .environment(\.imageLoader, MockImageLoader(missing: Set(slide.cells[2].image.map { [$0.id] } ?? [])))
}
