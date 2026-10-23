//
//  CellView.swift
//  Carouline
//

import SwiftUI

/// One cell of a slide on the project screen: a button to fill it, its photo, or what's left
/// when the photo's copy is gone.
struct CellView: View {
    let cell: Cell
    let address: CellAddress
    let background: RGBColor
    /// Where the cell sits, as in "photo 2 of 3", for VoiceOver.
    let position: String
    /// The empty cells in the cell's slide, which one pick for an empty cell can fill.
    let emptyCellCount: Int
    let isImporting: Bool
    let actions: CellActions
    let session: CropSession
    /// Whether the cell is a panorama's, whose first photo sets how many slides it spans.
    var isPanorama = false
    /// Whether a photo or a layer is selected anywhere on the strip, while which a finger held down
    /// may start a drag on the selection or a pinch anywhere, rather than a menu.
    var isAnythingSelected = false
    /// The photo's blur, as a Gaussian's sigma in points.
    var blur: CGFloat = 0
    /// Whether a drop over the slide would land here.
    var isDropTarget = false
    /// How far a panorama's controls move either way to stay under the strip's middle.
    var stripReach: CGFloat = 0
    @State private var size: CGSize = .zero
    @State private var isMissing = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.imageLoader) private var loader

    var body: some View {
        ZStack {
            if let image = cell.image {
                photo(image)
            } else {
                // Glass over what's behind the slide, as the strip's other chrome is, so an empty
                // cell reads as a space to fill rather than part of the slide.
                Color.clear
                    .glassEffect(.regular, in: .rect)
                if !isImporting, let held = actions.held {
                    PlaceHereButton(position: position, held: held, stripReach: stripReach) {
                        actions.land(address)
                    }
                } else if !isImporting {
                    AddPhotoButton(
                        position: position,
                        emptyCellCount: emptyCellCount,
                        isPanorama: isPanorama,
                        offersSources: actions.takePhoto != nil,
                        labelWidth: stripReach > 0 && size.width > 0 ? max(0, size.width - 2 * stripReach) : nil,
                        stripReach: stripReach
                    ) {
                        sourceButtons
                    } choose: {
                        actions.choosePhoto(address)
                    }
                }
            }
            if isImporting {
                importingSpinner
                    .followsStripMiddle(reach: stripReach)
            }
        }
        .overlay {
            if isDropTarget {
                Rectangle()
                    .strokeBorder(.tint, lineWidth: 3)
                    .accessibilityHidden(true)
            }
        }
        .controlSize(isCompact ? .small : .regular)
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
        // Glass takes its scheme from what it sits on rather than the system's, or a dark-mode
        // button on a white slide turns pale gray under a white symbol.
        .environment(\.colorScheme, isOnLight ? .light : .dark)
    }

    /// Whether the cell's glass sits on something light: for an empty cell, the screen behind its
    /// glass; for a missing photo, the placeholder; and otherwise the slide's background.
    private var isOnLight: Bool {
        if cell.image == nil {
            colorScheme == .light
        } else if isMissing {
            PlaceholderCell.isLight(on: background, in: colorScheme)
        } else {
            background.isLight
        }
    }

    /// A spinner on an empty cell's glass, or on a glass circle of its own over a photo it's
    /// replacing, rather than glass on glass.
    @ViewBuilder
    private var importingSpinner: some View {
        if cell.image == nil {
            ProgressView()
                .accessibilityLabel("Adding \(position)")
        } else {
            ProgressView()
                .padding(isCompact ? 6 : 12)
                .glassEffect(.regular, in: Circle())
                .accessibilityLabel("Adding \(position)")
        }
    }

    private var isSelected: Bool {
        session.selection == address
    }

    /// The fill in the photo's place while it loads and when it's missing, in the screen's scheme
    /// rather than the one the cell's glass takes below.
    private func placeholder(isLoading: Bool) -> some View {
        PlaceholderCell(background: background, isLoading: isLoading)
            .environment(\.colorScheme, colorScheme)
    }

    /// Shorter than this, as a cell of three rows on a wide slide with a border can be, the regular
    /// controls overflow the cell.
    private static let compactHeight: CGFloat = 52

    private var isCompact: Bool {
        size.height > 0 && size.height < Self.compactHeight
    }

    private func photo(_ image: PlacedImage) -> some View {
        let isSelected = isSelected
        var shown = image
        // Only the selected cell reads the live crop, so a drag redraws it alone.
        if isSelected, let liveCrop = session.liveCrop {
            shown.crop = liveCrop
        }
        let photo = CellPhoto(image: shown, projectID: address.projectID, blur: blur, isMissing: $isMissing) { absence in
            switch absence {
            case .loading:
                placeholder(isLoading: true)
            case .missing:
                ZStack {
                    placeholder(isLoading: false)
                    MissingPhoto(menu: missingMenu(image))
                        .followsStripMiddle(reach: stripReach)
                        .task {
                            actions.restorePhotoQuietly(address)
                        }
                }
            }
        }
        .id(image.id)
        // Over the photo, rather than a modifier on it, so turning dragging off and on leaves the
        // photo and what it has loaded alone.
        .overlay {
            if canDrag {
                dragSurface(image)
            }
        }
        .overlay {
            if isSelected {
                Rectangle()
                    .strokeBorder(.tint, lineWidth: 3)
                    .accessibilityHidden(true)
            } else if isHeldHere {
                // Marching round the photo on its way out, as a cut or a move marks its source.
                Rectangle()
                    .strokeBorder(.tint, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .accessibilityHidden(true)
            }
        }
        // Dragged and pinched by the strip's selection gesture, rather than one of its own, which
        // would claim a pinch's first finger. Its tap still keeps a tap on it from finishing.
        .onTapGesture {
            if actions.held != nil {
                actions.land(address)
            } else if !isSelected, !isMissing {
                // A missing photo has nothing to frame; its own menu offers what can be done.
                select()
            }
        }
        return accessible(photo, image: image, isSelected: isSelected)
    }

    /// `photo` as one element for VoiceOver, with the menu's choices as its actions and, while
    /// it's selected, steps to move it in place of dragging.
    private func accessible(_ photo: some View, image: PlacedImage, isSelected: Bool) -> some View {
        photo
            .accessibilityElement()
            .accessibilityLabel(isMissing ? "\(position.capitalizingFirstLetter), unavailable" : position.capitalizingFirstLetter)
            .accessibilityAddTraits(isMissing ? [] : isSelected ? [.isImage, .isSelected] : [.isImage])
            .accessibilityHint(hint)
            .accessibilityDragPoint(.center, description: "Photo", isEnabled: canDrag)
            .accessibilityDropPoint(.center, description: "In place of \(position)", isEnabled: true)
            .accessibilityAction {
                if actions.held != nil {
                    actions.land(address)
                } else if !isMissing {
                    select()
                }
            }
            .accessibilityActions {
                if actions.held != nil {
                    EmptyView()
                } else if isMissing {
                    missingMenu(image)
                } else {
                    if isSelected {
                        Button("Move Photo Left") { nudge(image, x: -1, y: 0) }
                        Button("Move Photo Right") { nudge(image, x: 1, y: 0) }
                        Button("Move Photo Up") { nudge(image, x: 0, y: -1) }
                        Button("Move Photo Down") { nudge(image, x: 0, y: 1) }
                    }
                    moveButton(image)
                    photoMenu
                }
            }
            // No menu while framing a photo or moving a layer, where a finger held down may start a
            // drag or a pinch, and the bar below offers the same choices, nor while a photo is held,
            // when a tap on the cell puts it here.
            .contextMenu {
                if isAnythingSelected || actions.held != nil {
                    EmptyView()
                } else if isMissing {
                    missingMenu(image)
                } else {
                    moveButton(image)
                    photoMenu
                }
            }
    }

    private func select() {
        session.cellSize = size
        actions.select(address)
    }

    /// Whether the photo can be dragged to another cell: not while anything is selected or held,
    /// nor while its copy is missing or another is on its way in, where the strip's own gestures,
    /// a tap, or the cell's menu take a finger held down.
    private var canDrag: Bool {
        !isAnythingSelected && actions.held == nil && !isMissing && !isImporting
    }

    /// A clear surface a long press lifts the photo from, to drop on another cell.
    private func dragSurface(_ image: PlacedImage) -> some View {
        Color.clear
            .contentShape(.rect)
            .draggable(HeldPhoto.cell(address, imageID: image.id)) {
                PhotoDragPreview(image: image, projectID: address.projectID, loader: loader)
            }
    }

    /// Whether the held photo is this cell's own, on its way to another.
    private var isHeldHere: Bool {
        if case .cell(let source, _) = actions.held { source == address } else { false }
    }

    /// What a tap on the photo does, for VoiceOver.
    private var hint: String {
        switch actions.held {
        case .cell where isHeldHere: "Keeps the photo here"
        case .cell: "Swaps the photo being moved with this one"
        case .tray: "Puts the held photo here in place of this one"
        case nil: isSelected || isMissing ? "" : "Selects the photo to move and zoom it"
        }
    }

    /// Holds the photo to put in whichever cell is tapped next.
    private func moveButton(_ image: PlacedImage) -> some View {
        Button("Move Photo…", systemImage: "arrow.up.and.down.and.arrow.left.and.right") {
            actions.hold(.cell(address, imageID: image.id))
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
    private func missingMenu(_ image: PlacedImage) -> some View {
        if image.assetIdentifier != nil {
            Button("Restore from Photos", systemImage: "arrow.clockwise") {
                actions.restorePhoto(address)
            }
        }
        photoMenu
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

/// A plus filling an empty cell, which offers the library and the camera when there is one, and
/// goes straight to the library when there isn't.
private struct AddPhotoButton<Sources: View>: View {
    let position: String
    let emptyCellCount: Int
    let isPanorama: Bool
    /// Whether there's more than the library to choose from.
    let offersSources: Bool
    /// A panorama's slide, which the button covers and moves with to stay in view, rather than the
    /// whole cell, which a menu would open from the middle of, off screen.
    let labelWidth: CGFloat?
    let stripReach: CGFloat
    @ViewBuilder let sources: () -> Sources
    let choose: () -> Void
    @Environment(\.controlSize) private var controlSize

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
        // Plain, since the cell's own glass is behind it, and the whole cell, or a panorama's slide
        // in view, an easy target.
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel("Add \(position)")
        .accessibilityHint(hint)
        .accessibilityDropPoint(.center, description: "Into \(position)", isEnabled: true)
        .followsStripMiddle(reach: stripReach)
    }

    private var hint: String {
        if isPanorama {
            "Fills the panorama with a photo, which sets how many slides it spans"
        } else if emptyCellCount > 1 {
            "Fills this cell, or up to \(emptyCellCount) empty cells in order, with photos"
        } else {
            "Fills this cell with a photo"
        }
    }

    private var label: some View {
        Image(systemName: "plus")
            .font(controlSize == .small ? .body.weight(.semibold) : .title2.weight(.semibold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: labelWidth ?? .infinity, maxHeight: .infinity)
            .contentShape(.rect)
    }
}

/// What fills an empty cell while a photo is held: a button that puts it there.
private struct PlaceHereButton: View {
    let position: String
    let held: HeldPhoto
    /// How far its glyph moves to stay in view on a panorama, whose whole cell still takes the tap,
    /// rather than dropping the held photo for a tap beside the glyph.
    let stripReach: CGFloat
    let place: () -> Void
    @Environment(\.controlSize) private var controlSize

    var body: some View {
        Button(action: place) {
            Image(systemName: "square.and.arrow.down")
                .font(controlSize == .small ? .body.weight(.semibold) : .title2.weight(.semibold))
                .foregroundStyle(Color.primary)
                .followsStripMiddle(reach: stripReach)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
        }
        // Plain, as the add button is, since the cell's own glass is behind it.
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel("Place in \(position)")
        .accessibilityHint(held.isFromCell ? "Moves the photo here" : "Puts the held photo here")
    }
}

/// What a cell shows when its photo's copy can't be read: a warning, and the ways to fill it
/// again. VoiceOver reads the cell's own label and actions instead.
private struct MissingPhoto<MenuContent: View>: View {
    let menu: MenuContent
    @Environment(\.controlSize) private var controlSize

    var body: some View {
        VStack(spacing: 8) {
            // Left out of a cell too short for both.
            if controlSize != .small {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
            }
            Menu {
                menu
            } label: {
                Text("Photo Unavailable")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.glass)
        }
        .padding(controlSize == .small ? 2 : 8)
        .accessibilityHidden(true)
    }
}

extension String {
    /// The string with its first letter uppercased, for a label that starts with a position.
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
            emptyCellCount: 2,
            isImporting: index == 3,
            actions: .preview,
            session: CropSession(selection: CellAddress(projectID: projectID, slideID: slide.id, index: 0))
        )
    }
    .frame(width: 320, height: 400)
    .environment(\.imageLoader, MockImageLoader(missing: Set(slide.cells[2].image.map { [$0.id] } ?? [])))
}
