//
//  SlideCard.swift
//  Swipeset
//

import SwiftUI

/// One slide in the strip: its cells, and the caption under it with the slide's options.
struct SlideCard: View {
    let slide: Slide
    let projectID: UUID
    /// The slide's numbers in the carousel: one, or a panorama's run.
    let numbers: ClosedRange<Int>
    let count: Int
    let canMoveLeft: Bool
    let canMoveRight: Bool
    let style: SlideStyle
    let size: CGSize
    let importingCells: Set<CellAddress>
    /// Whether a picture is on its way onto the slide as a layer.
    var isImportingLayer = false
    let cellActions: CellActions
    let session: CropSession
    let layerSession: LayerSession
    let layerActions: LayerActions
    let onChangeLayout: () -> Void
    let onMove: (Int) -> Void
    let onDelete: () -> Void
    let onSetSpan: (Int) -> Void
    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(spacing: 12) {
            CardPhotos(
                slide: slide,
                projectID: projectID,
                numbers: numbers,
                style: style,
                size: size,
                importingCells: importingCells,
                cellActions: cellActions,
                session: session,
                layerSession: layerSession,
                isAnythingSelected: isAnythingSelected
            )
            .frame(width: size.width, height: size.height)
            .overlay {
                SlideLayers(
                    layers: slide.layers,
                    projectID: projectID,
                    slideID: slide.id,
                    span: slide.span,
                    background: style.background,
                    size: size,
                    interaction: LayerInteraction(
                        session: layerSession,
                        actions: layerActions,
                        selectedLayerID: layerSession.selection?.slideID == slide.id ? layerSession.selection?.layerID : nil,
                        isAnythingSelected: isAnythingSelected,
                        isPhotoSelected: session.selection != nil,
                        isDrafting: layerSession.draftSlideID == slide.id
                    )
                )
            }
            // Over the layers, so a cut still shows across one that crosses it.
            .overlay {
                if slide.span > 1 {
                    PanoramaSeams(span: slide.span)
                }
            }
            // Where the picture lands once it's copied.
            .overlay {
                if isImportingLayer {
                    ProgressView()
                        .padding(14)
                        .glassEffect(.regular, in: .circle)
                        // From the slide, as glass over a slide takes its scheme.
                        .environment(\.colorScheme, style.background.isLight ? .light : .dark)
                        .position(
                            x: size.width * LayerPlacement.middle(ofSpan: slide.span).centerX / CGFloat(max(1, slide.span)),
                            y: size.height / 2
                        )
                        .accessibilityLabel("Adding a picture")
                }
            }
            // A hairline, so a slide the color of the screen still shows its edges.
            .overlay {
                Rectangle()
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .alignmentGuide(.slideCenter) { $0[VerticalAlignment.center] }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(spokenNumbers) of \(count), \(slide.layout.name)\(spokenLayers)")
            Menu {
                options
            } label: {
                HStack(spacing: 8) {
                    Text(numbersText)
                    Image(systemName: "ellipsis")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("\(spokenNumbers) Options")
            .frame(height: 44)
        }
        // From the card, not its caption's glass button, whose style the sheet would take on. A
        // sheet on iPhone, and on iPad a popover pointing at its slide.
        .popover(isPresented: layerActions.isShowingSheet(slide.id)) {
            layerActions.sheet(slide.id)
                .frame(idealWidth: LayersSheet.popoverSize.width, idealHeight: LayersSheet.popoverSize.height)
        }
        .confirmationDialog("Delete \(numbersText)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button(deleteTitle, role: .destructive, action: onDelete)
        } message: {
            Text(deletionMessage)
        }
    }

    @ViewBuilder
    private var options: some View {
        Button("Change Layout…", systemImage: "rectangle.split.2x2", action: onChangeLayout)
        Button("Add Layer…", systemImage: "square.2.layers.3d.top.filled") {
            layerActions.openSheet(slide.id, [.add])
        }
        Button("Edit Layers…", systemImage: "square.3.layers.3d") {
            layerActions.openSheet(slide.id, [])
        }
        // Once there's a photo, since the first one sets the width to fit it.
        if slide.layout == .panorama, slide.cells.first?.image != nil {
            Picker(selection: Binding { slide.span } set: { onSetSpan($0) }) {
                ForEach(Slide.panoramaSpans, id: \.self) { span in
                    Text("\(span) Slides").tag(span)
                }
            } label: {
                Label("Width", systemImage: "arrow.left.and.right")
            }
            .pickerStyle(.menu)
        }
        Button("Move Left", systemImage: "arrow.left") {
            onMove(-1)
        }
        .disabled(!canMoveLeft)
        Button("Move Right", systemImage: "arrow.right") {
            onMove(1)
        }
        .disabled(!canMoveRight)
        Divider()
        Button(deleteTitle, systemImage: "trash", role: .destructive) {
            isConfirmingDelete = true
        }
    }

    /// A photo or a layer selected anywhere on the strip, while which a long press is the start
    /// of a drag rather than a menu.
    private var isAnythingSelected: Bool {
        session.selection != nil || layerSession.selection != nil
    }

    /// The slide's layers, as VoiceOver adds them to its label.
    private var spokenLayers: String {
        switch slide.layers.count {
        case 0: ""
        case 1: ", 1 layer"
        case let count: ", \(count) layers"
        }
    }

    /// "Slide 3", or a panorama's "Slides 2–4".
    private var numbersText: String {
        numbers.count == 1 ? "Slide \(numbers.lowerBound)" : "Slides \(numbers.lowerBound)–\(numbers.upperBound)"
    }

    /// `numbersText` as VoiceOver should read it, rather than trusting it to read the dash.
    private var spokenNumbers: String {
        numbers.count == 1 ? "Slide \(numbers.lowerBound)" : "Slides \(numbers.lowerBound) to \(numbers.upperBound)"
    }

    private var deleteTitle: String {
        slide.layout == .panorama ? "Delete Panorama" : "Delete Slide"
    }

    /// Where cell `index` sits, for VoiceOver.
    private var deletionMessage: String {
        let layers = slide.layers.count
        switch (slide.cells.compactMap(\.image).count, layers) {
        case (0, 0): return slide.layout == .panorama ? "This panorama has no photo yet." : "This slide has no photos yet."
        case (0, 1): return "Its layer is deleted."
        case (0, _): return "Its \(layers) layers are deleted."
        case (let photos, _):
            let photoNote = photos == 1
                ? "Its photo is removed from the project. The original stays in your photo library."
                : "Its \(photos) photos are removed from the project. The originals stay in your photo library."
            return switch layers {
            case 0: photoNote
            case 1: "\(photoNote) Its layer is deleted too."
            default: "\(photoNote) Its \(layers) layers are deleted too."
            }
        }
    }
}

/// A slide's cells, each with its photo or the way to add one. The only part of the card that
/// reads a blur the layers sheet's slider is dragging, so each step redraws the photos alone.
private struct CardPhotos: View {
    let slide: Slide
    let projectID: UUID
    let numbers: ClosedRange<Int>
    let style: SlideStyle
    let size: CGSize
    let importingCells: Set<CellAddress>
    let cellActions: CellActions
    let session: CropSession
    let layerSession: LayerSession
    let isAnythingSelected: Bool

    var body: some View {
        let shownBlur = layerSession.blurringSlideID == slide.id ? layerSession.slideBlur : slide.blur
        let blur = LayerGeometry.blurRadius(shownBlur, slideWidth: size.width / CGFloat(max(1, slide.span)))
        SlideView(slide: slide, style: style, revealsEmptyCells: true) { index in
            let address = CellAddress(projectID: projectID, slideID: slide.id, index: index)
            CellView(
                cell: slide.cells[index],
                address: address,
                background: style.background,
                position: position(of: index),
                emptyCellCount: slide.emptyCellCount(skipping: importingIndexes),
                isImporting: importingCells.contains(address),
                actions: cellActions,
                session: session,
                isPanorama: slide.layout == .panorama,
                isAnythingSelected: isAnythingSelected,
                blur: blur
            )
        }
    }

    private func position(of index: Int) -> String {
        if slide.layout == .panorama {
            "panorama photo on slides \(numbers.lowerBound) to \(numbers.upperBound)"
        } else {
            "slide \(numbers.lowerBound), photo \(index + 1) of \(slide.cells.count)"
        }
    }

    /// The cells with a photo on its way in, which a pick can't fill.
    private var importingIndexes: Set<Int> {
        Set(slide.cells.indices.filter { importingCells.contains(CellAddress(projectID: projectID, slideID: slide.id, index: $0)) })
    }
}

#Preview {
    let project = SampleProjects.all[0]
    let slide = project.slides[2]
    SlideCard(
        slide: slide,
        projectID: project.id,
        numbers: 3...3,
        count: project.carouselSlideCount,
        canMoveLeft: true,
        canMoveRight: true,
        style: project.style,
        size: CGSize(width: 300, height: 375),
        importingCells: [],
        cellActions: .preview,
        session: CropSession(),
        layerSession: LayerSession(),
        layerActions: .preview,
        onChangeLayout: {},
        onMove: { _ in },
        onDelete: {},
        onSetSpan: { _ in }
    )
    .padding()
    .background { GlowBackdrop() }
}
