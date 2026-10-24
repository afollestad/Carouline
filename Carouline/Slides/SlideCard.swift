//
//  SlideCard.swift
//  Carouline
//

import SwiftUI
import TipKit

/// One slide in the strip: its cells, and the caption under it with the slide's options, as wide
/// as the strip lays it out, which is the slide's width or its caption's where that's wider.
struct SlideCard: View {
    let slide: Slide
    let projectID: UUID
    /// The slide's numbers in the carousel: one, or a panorama's run.
    let numbers: ClosedRange<Int>
    let count: Int
    let canMoveLeft: Bool
    let canMoveRight: Bool
    let size: CGSize
    /// Whether the card builds its photos and layers, as only those near the strip's middle do, so
    /// a project's photos never all decode at once. The rest show a `SlidePlaceholder`.
    var buildsPhotos = true
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
    /// Tells the strip the caption's own width, which it finds every caption's buttons and their
    /// room from, past their labels.
    var onCaptionWidth: (CGFloat) -> Void = { _ in }
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
    @Environment(TrayPress.self) private var trayPress: TrayPress?
    @Environment(\.shownPopovers) private var popovers

    /// The room between the slide and its caption, which a caption tip's arrow reaches across, to
    /// the top of the caption's frame, just above its glass.
    private static let captionSpacing: CGFloat = 12
    /// A fingertip's target, which the caption's row holds whatever its glass's height.
    static let captionHeight: CGFloat = 44
    /// The caption's text, which `CaptionLabelWidths` measures its labels in.
    static let captionFont: Font = .subheadline.weight(.medium)

    /// How far what follows the strip's middle along a panorama moves either way, as its caption does.
    var stripReach: CGFloat {
        StripMiddle.reach(span: slide.span, cardWidth: size.width)
    }

    var body: some View {
        // Measured only while the slide holds the selection, so a scroll measures nothing, and only
        // while it's built, so a selection scrolled far off isn't moved by a pinch on the strip.
        let holdsSelection = buildsPhotos && (session.selection?.slideID == slide.id || layerSession.selection?.slideID == slide.id)
        // And only while a tray photo is carried over the strip, for the cell it would land in.
        let isCarriedOver = buildsPhotos && trayPress?.phase == .carrying
        VStack(spacing: Self.captionSpacing) {
            // One view either way, so the modifiers on it stay put as the card builds its photos.
            ZStack {
                if buildsPhotos {
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
                } else {
                    SlidePlaceholder(size: size, background: slide.style.background)
                }
            }
            .frame(width: size.width, height: size.height)
            // From the slide, or a panorama's slide in view, rather than the card, where the system's
            // dialog pointed on a phone, since under the caption alone there isn't room for it.
            .background {
                Color.clear
                    .frame(width: size.width - 2 * stripReach)
                    .confirmationPopover("Delete \(numbersText)?", isPresented: $isConfirmingDelete, message: deletionMessage) {
                        Button(deleteTitle, role: .destructive, action: onDelete)
                    }
                    .followsStripMiddle(reach: stripReach)
            }
            .onGeometryChange(for: CGRect?.self) { proxy in
                holdsSelection ? proxy.frame(in: .named(SelectionGesture.space)) : nil
            } action: { frame in
                frames?.frames[slide.id] = frame.map { SlideFrame(frame: $0, size: size) }
            }
            .onGeometryChange(for: CGRect?.self) { proxy in
                isCarriedOver ? proxy.frame(in: .global) : nil
            } action: { frame in
                let card = frame.map {
                    TrayPress.Card(frame: SlideFrame(frame: $0, size: size), slide: slide, projectID: projectID, importing: importingIndexes)
                }
                trayPress?.setCard(card, for: slide.id)
            }
            .onDisappear {
                frames?.frames[slide.id] = nil
                trayPress?.setCard(nil, for: slide.id)
            }
            .reportsPanoramaFront(slide.id, span: slide.span, to: layerSession)
            .overlay {
                if buildsPhotos {
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
                    let placement = LayerPlacement.middle(ofSpan: slide.span, front: layerSession.frontSlideIndex(of: slide.id))
                    ProgressView()
                        .padding(14)
                        .glassEffect(.regular, in: .circle)
                        // From the slide, as glass over a slide takes its scheme.
                        .environment(\.colorScheme, slide.style.background.isLight ? .light : .dark)
                        .position(x: size.width * placement.centerX / CGFloat(max(1, slide.span)), y: size.height / 2)
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
            // tip's close button doesn't draw. Only on a built card, as the one in front always is.
            .overlay {
                if buildsPhotos {
                    tourTips
                        // From the slide, as glass over a slide takes its scheme.
                        .environment(\.colorScheme, slide.style.background.isLight ? .light : .dark)
                }
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
            // One element for a slide without its photos, still found and scrolled to by its label.
            .accessibilityElement(children: buildsPhotos ? .contain : .ignore)
            .accessibilityLabel("\(spokenNumbers) of \(count), \(slide.layout.name)\(spokenLayers)")
            // Over the caption, which comes after it, so a tip grown past a short slide still shows
            // and takes its taps.
            .zIndex(1)
            // Measured at its own width, rather than squeezed into a card the strip hasn't widened
            // for it yet, and moved within the card, as wide as the strip lays it out.
            caption
                .fixedSize(horizontal: true, vertical: false)
                .onGeometryChange(for: CGFloat.self, of: \.size.width, action: onCaptionWidth)
                .followsStripMiddle(reach: stripReach)
        }
        // Over the slide and its caption, where the tip finds the caption's buttons. Not while
        // one of their popovers is open over it, nor on a card that isn't built.
        .overlayPreferenceValue(TourTargetBounds.self) { targets in
            if buildsPhotos, openPopover == nil {
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
                .countsAsPopover()
        }
    }

    /// The slide's layout button, its options and its layers, side by side under it. The layout and
    /// layers have buttons of their own, since they're what a slide is changed for most.
    private var caption: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    popovers.whenGone {
                        tour?.finish(.changeLayout)
                        onChangeLayout()
                    }
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
                // Not while a photo is on its way in, which the library leaves the layout alone for.
                .disabled(!importingIndexes.isEmpty)
                Button {
                    popovers.whenGone { openPopover = .options }
                } label: {
                    HStack(spacing: 8) {
                        // Tabular, so the caption is as wide as any other of its `slidesNameShape`,
                        // which the strip lays its card out by before it's measured.
                        Text(numbersText)
                            .monospacedDigit()
                        Image(systemName: "ellipsis")
                    }
                }
                .accessibilityLabel("\(spokenNumbers) Options")
                .tourTarget(.optionsButton)
                .popover(isPresented: isShowing(.options), arrowEdge: .bottom) {
                    CaptionPopover(groups: optionGroups, header: { widthChoice }, onGone: { popoverGone(finishing: .slideMenu) })
                }
                Button {
                    popovers.whenGone { openPopover = .layers }
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
            .font(Self.captionFont)
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
