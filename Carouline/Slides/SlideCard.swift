//
//  SlideCard.swift
//  Carouline
//

import SwiftUI
import TipKit

/// One slide in the strip: its cells, and the caption under it with the slide's options.
struct SlideCard: View {
    let slide: Slide
    let projectID: UUID
    /// The slide's numbers in the carousel: one, or a panorama's run.
    let numbers: ClosedRange<Int>
    let count: Int
    let canMoveLeft: Bool
    let canMoveRight: Bool
    let size: CGSize
    /// How many of the slide's points a point on screen covers, as the strip scales it.
    var screenPoint: CGFloat = 1
    /// Where the strip's selection gesture finds the slide while it holds the selection.
    var frames: SlideFrames?
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
    @Environment(ProjectTour.self) private var tour: ProjectTour?

    /// The tour's tips' room from the slide's sides, and their widest, which keeps one to a phone's
    /// width over an iPad's or a panorama's wider slide.
    private static let tipInset: CGFloat = 12
    private static let tipMaxWidth: CGFloat = 400
    /// The room between the slide and its caption, which the menu tip's arrow reaches across, to
    /// the top of the caption's frame, just above its glass.
    private static let captionSpacing: CGFloat = 12

    var body: some View {
        // Measured only while the slide holds the selection, so a scroll measures nothing.
        let holdsSelection = session.selection?.slideID == slide.id || layerSession.selection?.slideID == slide.id
        VStack(spacing: Self.captionSpacing) {
            CardPhotos(
                slide: slide,
                projectID: projectID,
                numbers: numbers,
                size: size,
                importingCells: importingCells,
                cellActions: cellActions,
                session: session,
                layerSession: layerSession,
                isAnythingSelected: isAnythingSelected
            )
            .frame(width: size.width, height: size.height)
            .onGeometryChange(for: CGRect?.self) { proxy in
                holdsSelection ? proxy.frame(in: .named(SelectionGesture.space)) : nil
            } action: { frame in
                frames?.frames[slide.id] = frame.map { SlideFrame(frame: $0, size: size) }
            }
            .onDisappear {
                frames?.frames[slide.id] = nil
            }
            .overlay {
                SlideLayers(
                    layers: slide.layers,
                    projectID: projectID,
                    slideID: slide.id,
                    span: slide.span,
                    background: slide.style.background,
                    size: size,
                    interaction: LayerInteraction(
                        session: layerSession,
                        actions: layerActions,
                        selectedLayerID: layerSession.selection?.slideID == slide.id ? layerSession.selection?.layerID : nil,
                        isAnythingSelected: isAnythingSelected,
                        isDrafting: layerSession.draftSlideID == slide.id,
                        screenPoint: screenPoint
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
                        .environment(\.colorScheme, slide.style.background.isLight ? .light : .dark)
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
            // Over the layers, which the layer tip points at, and past the shadow, under which a
            // tip's close button doesn't draw.
            .overlay {
                tourTips
                    // From the slide, as glass over a slide takes its scheme.
                    .environment(\.colorScheme, slide.style.background.isLight ? .light : .dark)
            }
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
            // Not while the slide's layers sheet is open: the delete confirmation can't show while
            // it's up, and moving or resizing the slide would close an iPad's popover, which this
            // card presents.
            .disabled(layerActions.isShowingSheet(slide.id).wrappedValue)
            .accessibilityLabel("\(spokenNumbers) Options")
            .frame(height: 44)
        }
        // A wide screen's popover pointing at its slide, from the card, not its caption's glass
        // button, whose style the popover would take on. A phone's sheet comes from the screen.
        .popover(isPresented: layerActions.showsPopover ? layerActions.isShowingSheet(slide.id) : .constant(false)) {
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
        Button("Change Layout…", systemImage: "rectangle.split.2x2") {
            choose(onChangeLayout)
        }
        Button("Add Layer…", systemImage: "square.2.layers.3d.top.filled") {
            choose { layerActions.openSheet(slide.id, [.add]) }
        }
        Button("Edit Layers…", systemImage: "square.3.layers.3d") {
            choose { layerActions.openSheet(slide.id, []) }
        }
        // Once there's a photo, since the first one sets the width to fit it.
        if slide.layout == .panorama, slide.cells.first?.image != nil {
            Picker(selection: Binding { slide.span } set: { span in choose { onSetSpan(span) } }) {
                ForEach(Slide.panoramaSpans, id: \.self) { span in
                    Text("\(span) Slides").tag(span)
                }
            } label: {
                Label("Width", systemImage: "arrow.left.and.right")
            }
            .pickerStyle(.menu)
        }
        Button("Move Left", systemImage: "arrow.left") {
            choose { onMove(-1) }
        }
        .disabled(!canMoveLeft)
        Button("Move Right", systemImage: "arrow.right") {
            choose { onMove(1) }
        }
        .disabled(!canMoveRight)
        Divider()
        Button(deleteTitle, systemImage: "trash", role: .destructive) {
            choose { isConfirmingDelete = true }
        }
    }

    /// Does what the slide's menu offers, which finishes the tour's tip about the menu. Opening the
    /// menu would be sooner, but SwiftUI hands it to UIKit, which reports no opening.
    private func choose(_ action: () -> Void) {
        tour?.finish(through: .slideMenu)
        action()
    }

    /// A photo or a layer selected anywhere on the strip, while which a finger held down may start
    /// a drag on the selection or a pinch anywhere, rather than a menu.
    private var isAnythingSelected: Bool {
        session.selection != nil || layerSession.selection != nil
    }

    /// The tour's tips on the slide in front: one along its foot pointing down at its menu, its
    /// arrow past the slide, or one pointing at its top layer, below a layer in the slide's upper
    /// half and above one in its lower half, so it never covers the layer it asks the user to tap.
    /// Inline rather than popovers, which TipKit leaves on screen while a sheet opens, and after
    /// which the strip presents no popover again.
    @ViewBuilder
    private var tourTips: some View {
        if let tip = tour?.menuTip(on: slide.id) {
            TipView(tip, arrowEdge: .bottom)
                .tourTipStyle()
                .frame(maxWidth: Self.tipMaxWidth)
                .padding([.horizontal, .top], Self.tipInset)
                .padding(.bottom, -Self.captionSpacing)
                .frame(maxHeight: .infinity, alignment: .bottom)
        } else if let tip = tour?.layerTip(on: slide.id), let layer = slide.layers.last {
            let frame = LayerGeometry.frame(of: layer, canvas: size, span: slide.span)
            let isBelow = frame.midY < size.height / 2
            ZStack {
                Color.clear
                    .frame(width: frame.width, height: frame.height)
                    .tipAnchor(TourAnchor.layer)
                    .position(x: frame.midX, y: frame.midY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                TipView(tip, arrowEdge: isBelow ? .top : .bottom, anchorID: TourAnchor.layer)
                    .tourTipStyle()
                    .frame(maxWidth: Self.tipMaxWidth)
                    .padding(.horizontal, Self.tipInset)
                    .padding(isBelow ? .top : .bottom, isBelow ? frame.maxY : size.height - frame.minY)
                    .frame(maxHeight: .infinity, alignment: isBelow ? .top : .bottom)
            }
        }
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
/// reads a blur or style the layers sheet is editing, so each step redraws the photos alone,
/// rather than the card, which on a wide screen hosts the sheet's popover.
private struct CardPhotos: View {
    let slide: Slide
    let projectID: UUID
    let numbers: ClosedRange<Int>
    let size: CGSize
    let importingCells: Set<CellAddress>
    let cellActions: CellActions
    let session: CropSession
    let layerSession: LayerSession
    let isAnythingSelected: Bool

    var body: some View {
        let isStyling = layerSession.stylingSlideID == slide.id
        let style = isStyling ? layerSession.slideStyle : slide.style
        let blur = LayerGeometry.blurRadius(isStyling ? layerSession.slideBlur : slide.blur, slideWidth: size.width / CGFloat(max(1, slide.span)))
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
