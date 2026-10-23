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
    /// Whether the slide takes photos dropped on it: not while anything is selected or held, nor
    /// while a slide's layers are open.
    var acceptsDrops = false
    /// Tells the strip whether a drop hovers over the slide.
    var onDropHover: (_ slideID: UUID, _ isOver: Bool) -> Void = { _, _ in }
    @State private var isConfirmingDelete = false
    /// Which of the caption's popovers is open, if either.
    @State private var openPopover: CaptionPopoverKind?
    /// What a choice in the caption's popover does once the popover has gone.
    @State private var afterPopover: (() -> Void)?
    /// The cell a drop over the slide would land in.
    @State private var dropTarget: Int?
    /// An icon button's glyph frame, which with a glass button's padding stands its circle as tall
    /// as the options capsule beside it, where the glyph alone falls a little short.
    @ScaledMetric(relativeTo: .subheadline) private var iconSide: CGFloat = 18
    @Environment(ProjectTour.self) var tour: ProjectTour?

    /// The room between the slide and its caption, which a caption tip's arrow reaches across, to
    /// the top of the caption's frame, just above its glass.
    private static let captionSpacing: CGFloat = 12
    /// A fingertip's target, which the caption's row holds whatever its glass's height.
    static let captionHeight: CGFloat = 44

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
                isAnythingSelected: isAnythingSelected,
                dropTarget: dropTarget
            )
            .frame(width: size.width, height: size.height)
            // From the slide rather than the card, where the system's dialog pointed on a phone, since
            // under the caption alone there isn't room for it.
            .confirmationPopover("Delete \(numbersText)?", isPresented: $isConfirmingDelete, message: deletionMessage) {
                Button(deleteTitle, role: .destructive, action: onDelete)
            }
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
                        screenPoint: screenPoint,
                        heldPhoto: cellActions.held,
                        placeHeld: cellActions.landInLayer
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
            // Over the layers, which would otherwise take a drop on the cell under them.
            .onDrop(of: SlideDrop.types, delegate: SlideDrop(
                slide: slide,
                projectID: projectID,
                canvas: LayerCanvas(size: size, span: slide.span, screenPoint: screenPoint),
                isEnabled: acceptsDrops,
                importing: importingIndexes,
                targetedCell: $dropTarget,
                onHover: onDropHover,
                actions: cellActions
            ))
            .alignmentGuide(.slideCenter) { $0[VerticalAlignment.center] }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(spokenNumbers) of \(count), \(slide.layout.name)\(spokenLayers)")
            // Over the caption, which comes after it, so a tip grown past a short slide still shows
            // and takes its taps.
            .zIndex(1)
            caption
        }
        // Over the slide and its caption, where the tip finds the caption's buttons. Not while
        // one of their popovers is open over it.
        .overlayPreferenceValue(TourTargetBounds.self) { targets in
            if openPopover == nil {
                captionTip(at: targets)
                    // From the slide, as glass over a slide takes its scheme.
                    .environment(\.colorScheme, slide.style.background.isLight ? .light : .dark)
            }
        }
        // A wide screen's popover pointing at its slide, from the card, not its caption's glass
        // button, whose style the popover would take on. A sheet comes from the screen.
        .popover(isPresented: layerActions.showsPopover ? layerActions.isShowingSheet(slide.id) : .constant(false)) {
            layerActions.sheet(slide.id)
                .frame(idealWidth: LayersSheet.popoverSize.width, idealHeight: LayersSheet.popoverSize.height)
        }
    }

    /// The slide's layout button, its options and its layers, side by side under it. The layout and
    /// layers have buttons of their own, since they're what a slide is changed for most.
    private var caption: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    tour?.finish(.changeLayout)
                    onChangeLayout()
                } label: {
                    Label("Change Layout", systemImage: "rectangle.split.2x2")
                        .labelStyle(.iconOnly)
                        .frame(width: iconSide, height: iconSide)
                }
                .buttonBorderShape(.circle)
                .accessibilityLabel("\(spokenNumbers) Layout")
                .accessibilityValue(slide.layout.name)
                .accessibilityHint("Chooses another layout for the slide")
                .tourTarget(.layoutButton)
                Button {
                    openPopover = .options
                } label: {
                    HStack(spacing: 8) {
                        Text(numbersText)
                        Image(systemName: "ellipsis")
                    }
                }
                .accessibilityLabel("\(spokenNumbers) Options")
                .tourTarget(.optionsButton)
                .popover(isPresented: isShowing(.options), arrowEdge: .bottom) {
                    CaptionPopover(groups: optionGroups, header: { widthChoice }, onGone: { popoverGone(finishing: .slideMenu) })
                }
                Button {
                    openPopover = .layers
                } label: {
                    Label("Layers", systemImage: "square.3.layers.3d")
                        .labelStyle(.iconOnly)
                        .frame(width: iconSide, height: iconSide)
                }
                .buttonBorderShape(.circle)
                .accessibilityLabel("\(spokenNumbers) Layers")
                .accessibilityHint("Adds a layer to the slide, or edits its layers")
                .tourTarget(.layersButton)
                .popover(isPresented: isShowing(.layers), arrowEdge: .bottom) {
                    CaptionPopover(groups: [layerChoices], header: { EmptyView() }, onGone: { popoverGone(finishing: .layers) })
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.primary)
            .buttonStyle(.glass)
        }
        // Not while the slide's layers sheet is open: the delete confirmation can't show while it's
        // up, and moving or resizing the slide would close an iPad's popover, which this card
        // presents. Nor the layout, which the sheet would have to close for.
        .disabled(layerActions.isShowingSheet(slide.id).wrappedValue)
        .frame(height: Self.captionHeight)
    }

    /// Which of the caption's popovers is open, if either.
    private enum CaptionPopoverKind {
        case options
        case layers
    }

    private func isShowing(_ kind: CaptionPopoverKind) -> Binding<Bool> {
        Binding {
            openPopover == kind
        } set: { isShowing in
            if !isShowing, openPopover == kind {
                openPopover = nil
            }
        }
    }

    private var layerChoices: [CaptionChoice] {
        [
            CaptionChoice(title: "Add Text Layer…", systemImage: LayerKind.text.systemImage) {
                chooseInPopover { layerActions.addLayer(slide.id, .text) }
            },
            CaptionChoice(title: "Add Image Layer…", systemImage: LayerKind.image.systemImage) {
                chooseInPopover { layerActions.addLayer(slide.id, .image) }
            },
            CaptionChoice(title: "Edit Layers…", systemImage: "square.3.layers.3d") {
                chooseInPopover { layerActions.openSheet(slide.id, []) }
            }
        ]
    }

    private var optionGroups: [[CaptionChoice]] {
        [
            [
                CaptionChoice(title: "Move Left", systemImage: "arrow.left", isEnabled: canMoveLeft) {
                    chooseInPopover { onMove(-1) }
                },
                CaptionChoice(title: "Move Right", systemImage: "arrow.right", isEnabled: canMoveRight) {
                    chooseInPopover { onMove(1) }
                }
            ],
            [
                CaptionChoice(title: deleteTitle, systemImage: "trash", isDestructive: true) {
                    chooseInPopover { isConfirmingDelete = true }
                }
            ]
        ]
    }

    /// A panorama's width, once it has a photo, since the first one sets the width to fit it.
    @ViewBuilder
    private var widthChoice: some View {
        if slide.layout == .panorama, slide.cells.first?.image != nil {
            Menu {
                Picker("Width", selection: Binding { slide.span } set: { span in chooseInPopover { onSetSpan(span) } }) {
                    ForEach(Slide.panoramaSpans, id: \.self) { span in
                        Text("\(span) Slides").tag(span)
                    }
                }
            } label: {
                CaptionRow(title: "Width", systemImage: "arrow.left.and.right") {
                    Text("\(slide.span) Slides")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("Width")
            .accessibilityValue("\(slide.span) slides")
            Divider()
                .padding(.vertical, 4)
        }
    }

    /// Closes the caption's popover and does `action` once it has gone, since a sheet, a popover or
    /// a confirmation asked for as it goes never shows, and moving the slide would move the popover.
    private func chooseInPopover(_ action: @escaping () -> Void) {
        afterPopover = action
        // At once rather than animated, since the choice waits for the popover to go, and its
        // fade would hold a sheet back by half a second.
        var closing = Transaction()
        closing.disablesAnimations = true
        withTransaction(closing) {
            openPopover = nil
        }
    }

    /// Finishes the tour's tip about the popover that just closed, now that the next can't come on
    /// under it, then does what it was closed for, if anything.
    private func popoverGone(finishing step: TourStep) {
        tour?.finish(step)
        let action = afterPopover
        afterPopover = nil
        action?()
    }

    /// A photo or a layer selected anywhere on the strip, while which a finger held down may start
    /// a drag on the selection or a pinch anywhere, rather than a menu.
    private var isAnythingSelected: Bool {
        session.selection != nil || layerSession.selection != nil
    }

    /// The cells with a photo on its way in, which take no drop.
    private var importingIndexes: Set<Int> {
        Set(slide.cells.indices.filter { importingCells.contains(CellAddress(projectID: projectID, slideID: slide.id, index: $0)) })
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
        numbers.slidesName
    }

    /// `numbersText` as VoiceOver should read it, rather than trusting it to read the dash.
    private var spokenNumbers: String {
        numbers.count == 1 ? "Slide \(numbers.lowerBound)" : "Slides \(numbers.lowerBound) to \(numbers.upperBound)"
    }

    private var deleteTitle: String {
        slide.layout == .panorama ? "Delete Panorama" : "Delete Slide"
    }

    /// What deleting the slide takes with it: its photos' copies, whose originals stay in the photo
    /// library, and its layers.
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
    /// The cell a drop over the slide would land in.
    let dropTarget: Int?

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
                blur: blur,
                isDropTarget: dropTarget == index
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
