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

    static let preview = CellActions(choosePhoto: { _ in }, takePhoto: { _ in }, removePhoto: { _ in })
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

    var body: some View {
        ZStack {
            PlaceholderCell(background: background)
            if let image = cell.image {
                CellPhoto(image: image, projectID: address.projectID) {
                    MissingPhoto(position: position, menu: photoMenu)
                }
                .id(image.id)
                .accessibilityElement()
                .accessibilityLabel(position.capitalizingFirstLetter)
                .accessibilityAddTraits(.isImage)
                .accessibilityActions {
                    photoMenu
                }
                .contextMenu {
                    photoMenu
                }
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
        // Glass over the slide takes its scheme from the slide's background rather than the
        // system's, or a dark-mode button on a white slide turns pale gray under a white symbol.
        .environment(\.colorScheme, background.isLight ? .light : .dark)
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
            actions: .preview
        )
    }
    .frame(width: 320, height: 400)
    .environment(\.imageLoader, MockImageLoader(missing: Set(slide.cells[2].image.map { [$0.id] } ?? [])))
}
