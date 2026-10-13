//
//  SlideStrip.swift
//  Swipeset
//

import SwiftUI

/// Something the strip can scroll to: a slide, or the button after the last one.
enum StripItem: Hashable {
    case slide(UUID)
    case add
}

/// A project's slides side by side, with the button for another after the last.
struct SlideStrip: View {
    let project: Project
    @Binding var position: StripItem?
    let importingCells: Set<CellAddress>
    /// Slides with pictures on their way in as layers.
    var importingLayers: [UUID: Int] = [:]
    let cellActions: CellActions
    let session: CropSession
    let layerSession: LayerSession
    let layerActions: LayerActions
    /// The slide whose layers sheet is open, which the strip holds still for, so the slide the
    /// sheet points at stays put.
    let layersSlideID: UUID?
    /// Taps between the slides, which finish framing a photo or moving a layer.
    let onBackgroundTap: () -> Void
    let onAddSlide: () -> Void
    let onChangeLayout: (UUID) -> Void
    let onMove: (UUID, Int) -> Void
    let onDelete: (UUID) -> Void
    let onSetSpan: (UUID, Int) -> Void
    @State private var size: CGSize = .zero
    /// The strip's size before `bottomRoom` is taken from it.
    @State private var fullSize: CGSize = .zero
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The caption's height and the gap above it, which the slide makes room for.
    private static let captionSpace: CGFloat = 56
    private static let spacing: CGFloat = 20
    private static let addButtonSize: CGFloat = 56
    /// The narrowest an iPad's layers popover can be squeezed beside its slide, and the room its
    /// arrow and the screen's edge take.
    private static let popoverMinWidth: CGFloat = 320
    private static let popoverMargin: CGFloat = 24

    var body: some View {
        Group {
            if project.slides.isEmpty {
                GhostSlide(size: cardSize(span: 1), onAdd: onAddSlide)
                    .padding(.bottom, SelectionBar.reservedHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                strip
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            self.size = size
        }
        .padding(.bottom, bottomRoom)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            fullSize = size
        }
        .animation(.smooth(duration: 0.25), value: bottomRoom)
    }

    /// Room under the slides, so the one being edited shrinks to stay in view: above the keyboard
    /// and the short sheet over it while a phone types a text layer, and above an iPad's layers
    /// popover when the slide leaves it no room beside.
    private var bottomRoom: CGFloat {
        if horizontalSizeClass == .compact {
            return layerSession.keyboardRoom
        }
        guard let slide = project.slides.first(where: { $0.id == layersSlideID }) else {
            return 0
        }
        // Measured at the full size, so the room taken can't change whether room is taken.
        let sideRoom = (fullSize.width - cardSize(span: slide.span, in: fullSize).width) / 2
        guard sideRoom < Self.popoverMinWidth + Self.popoverMargin else {
            return 0
        }
        // The selection bar's room is kept already, and the popover covers it. Half the strip
        // stays for the slide, however short the screen.
        let room = LayersSheet.popoverSize.height + Self.popoverMargin - SelectionBar.reservedHeight
        return min(room, fullSize.height / 2)
    }

    private var strip: some View {
        let numbers = project.slideNumbers
        return ScrollView(.horizontal) {
            LazyHStack(alignment: .slideCenter, spacing: Self.spacing) {
                ForEach(Array(project.slides.enumerated()), id: \.element.id) { index, slide in
                    SlideCard(
                        slide: slide,
                        projectID: project.id,
                        numbers: numbers[index],
                        count: project.carouselSlideCount,
                        canMoveLeft: index > 0,
                        canMoveRight: index < project.slides.count - 1,
                        style: project.style,
                        size: cardSize(span: slide.span),
                        importingCells: importingCells,
                        isImportingLayer: importingLayers[slide.id] != nil,
                        cellActions: cellActions,
                        session: session,
                        layerSession: layerSession,
                        layerActions: layerActions,
                        onChangeLayout: { onChangeLayout(slide.id) },
                        onMove: { onMove(slide.id, $0) },
                        onDelete: { onDelete(slide.id) },
                        onSetSpan: { onSetSpan(slide.id, $0) }
                    )
                    .id(StripItem.slide(slide.id))
                    // The others hold still too while a slide's layers sheet is open, to fingers and
                    // VoiceOver alike, so nothing on them is selected or edited out from under it.
                    .allowsHitTesting(layersSlideID == nil || layersSlideID == slide.id)
                    .accessibilityHidden(layersSlideID != nil && layersSlideID != slide.id)
                }
                AddSlideButton(size: Self.addButtonSize, action: onAddSlide)
                    .id(StripItem.add)
            }
            // Where `scrollPosition` finds the slides and the add button by ID.
            .scrollTargetLayout()
            // Room for the first slide and the add button each to reach the middle. Padding
            // rather than `contentMargins`, which stop view-aligned scrolling from snapping and
            // shift a centered `scrollPosition` off the middle of the screen.
            .padding(.leading, max(0, (size.width - firstCardWidth) / 2))
            .padding(.trailing, max(0, (size.width - Self.addButtonSize) / 2))
            .padding(.bottom, SelectionBar.reservedHeight)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .onTapGesture(perform: onBackgroundTap)
            .gesture(selectionGesture, isEnabled: isAnythingSelected)
        }
        .scrollTargetBehavior(snapping)
        // A drag on the selected photo or layer moves it rather than scrolling past it.
        .scrollDisabled(isAnythingSelected || layersSlideID != nil)
        .sensoryFeedback(.alignment, trigger: layerSession.snapsTaken)
        .scrollPosition(id: $position, anchor: .center)
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    private var isAnythingSelected: Bool {
        session.selection != nil || layerSession.selection != nil
    }

    /// Drags, pinches and twists anywhere on the strip move the selected photo or layer, as
    /// scrolling is locked while one is, so a thin panorama, a small cell or a small layer needn't
    /// be hit exactly. A selected photo's own gesture takes those on it, and a pinch away from it
    /// zooms about its middle, as the zoom slider does. A photo ignores twists. The drag keeps its
    /// least distance, so taps still reach the layers and the space between the slides.
    private var selectionGesture: some Gesture {
        SimultaneousGesture(SimultaneousGesture(DragGesture(), MagnifyGesture()), RotateGesture())
            .onChanged { value in
                let translation = value.first?.first?.translation
                let magnification = value.first?.second?.magnification
                if let image = selectedPhoto {
                    session.frame(
                        image,
                        translation: translation,
                        magnification: magnification,
                        anchor: CGPoint(x: session.cellSize.width / 2, y: session.cellSize.height / 2)
                    )
                } else if let (layer, canvas) = selectedLayer {
                    let gesture = LayerGesture(translation: translation, magnification: magnification, rotation: value.second?.rotation.radians)
                    layerSession.move(layer, by: gesture, on: canvas)
                }
            }
            .onEnded { _ in
                if session.selection != nil {
                    let crop = session.endFraming()
                    if let selection = session.selection, let crop {
                        cellActions.setCrop(crop, selection)
                    }
                } else {
                    let placement = layerSession.endMoving()
                    if let selection = layerSession.selection, let placement {
                        layerActions.setPlacement(placement, selection)
                    }
                }
            }
    }

    /// The selected layer, a new one's draft included, and the slide it moves on at the size the
    /// strip draws it.
    private var selectedLayer: (Layer, LayerCanvas)? {
        guard let selection = layerSession.selection,
              let slide = project.slides.first(where: { $0.id == selection.slideID }),
              let layer = slide.layers.first(where: { $0.id == selection.layerID }) ?? layerSession.draftLayer(selection.layerID) else {
            return nil
        }
        return (layer, LayerCanvas(size: cardSize(span: slide.span), span: slide.span))
    }

    private var selectedPhoto: PlacedImage? {
        guard let selection = session.selection,
              let slide = project.slides.first(where: { $0.id == selection.slideID }),
              slide.cells.indices.contains(selection.index) else {
            return nil
        }
        return slide.cells[selection.index].image
    }

    /// Rests the strip with a slide, or the add button, in the middle of the screen. View-aligned
    /// scrolling would rest a slide's leading edge on the screen's instead, whatever its anchor.
    /// Each offset centers its item past the leading padding, which centers the first, so a
    /// panorama wider than a slide centers too.
    private var snapping: StripSnapping {
        let first = firstCardWidth
        var leadingEdge: CGFloat = 0
        var offsets: [CGFloat] = []
        for slide in project.slides {
            let width = cardSize(span: slide.span).width
            offsets.append(leadingEdge + (width - first) / 2)
            leadingEdge += width + Self.spacing
        }
        return StripSnapping(offsets: offsets + [leadingEdge + (Self.addButtonSize - first) / 2])
    }

    private var firstCardWidth: CGFloat {
        cardSize(span: project.slides.first?.span ?? 1).width
    }

    /// The project's shape, `span` slides wide, fitted to the screen, leaving the slides either
    /// side peeking in at the edges so the strip reads as one to scroll. A panorama fits in the
    /// same room as a slide, so all of it can be framed at once.
    private func cardSize(span: Int, in size: CGSize? = nil) -> CGSize {
        let size = size ?? self.size
        let ratio = project.aspectRatio.widthOverHeight * CGFloat(span)
        let maxWidth = size.width * (horizontalSizeClass == .regular ? 0.7 : 0.82)
        let maxHeight = max(0, size.height - Self.captionSpace - SelectionBar.reservedHeight - 32)
        let width = max(0, min(maxWidth, maxHeight * ratio))
        return CGSize(width: width, height: width / ratio)
    }
}

/// Snaps a scroll to the nearest of `offsets`.
private struct StripSnapping: ScrollTargetBehavior {
    let offsets: [CGFloat]

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        // A scroll to a `scrollPosition` targets the item's own rect, anchored to center it,
        // which already rests it on one of the offsets. Snapping that rect as if it were the
        // visible region would stop the scroll short.
        guard target.anchor == nil else {
            return
        }
        let proposed = target.rect.minX
        if let nearest = offsets.min(by: { abs($0 - proposed) < abs($1 - proposed) }) {
            target.rect.origin.x = nearest
        }
    }
}

extension VerticalAlignment {
    /// The middle of the slides, so the add button beside them lines up with the slides
    /// rather than with the slides and their captions.
    private enum SlideCenter: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    static let slideCenter = VerticalAlignment(SlideCenter.self)
}

private struct AddSlideButton: View {
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Add Slide", systemImage: "plus")
                .labelStyle(.iconOnly)
                .font(.title2.weight(.semibold))
                .frame(width: size - 16, height: size - 16)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityHint("Choose a layout for a new slide")
        // Exactly `size` across, which the strip's snapping counts on to center it.
        .frame(width: size, height: size)
        .alignmentGuide(.slideCenter) { $0[VerticalAlignment.center] }
    }
}

/// Where the first slide will go, in the project's shape.
private struct GhostSlide: View {
    let size: CGSize
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .frame(width: size.width, height: size.height)
                .overlay {
                    Button(action: onAdd) {
                        Label("Add Slide", systemImage: "plus")
                            .labelStyle(.iconOnly)
                            .font(.title.weight(.semibold))
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .accessibilityHint("Choose a layout for the first slide")
                }
            Text("Add a slide to start your carousel.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .padding(.bottom, 40)
    }
}

#Preview("Slides") {
    @Previewable @State var position: StripItem?
    SlideStrip(
        project: SampleProjects.all[0],
        position: $position,
        importingCells: [],
        cellActions: .preview,
        session: CropSession(),
        layerSession: LayerSession(),
        layerActions: .preview,
        layersSlideID: nil,
        onBackgroundTap: {},
        onAddSlide: {},
        onChangeLayout: { _ in },
        onMove: { _, _ in },
        onDelete: { _ in },
        onSetSpan: { _, _ in }
    )
    .background { GlowBackdrop() }
}

#Preview("Panorama") {
    @Previewable @State var position: StripItem? = .slide(SampleProjects.sampleID(14))
    SlideStrip(
        project: SampleProjects.all[0],
        position: $position,
        importingCells: [],
        cellActions: .preview,
        session: CropSession(),
        layerSession: LayerSession(),
        layerActions: .preview,
        layersSlideID: nil,
        onBackgroundTap: {},
        onAddSlide: {},
        onChangeLayout: { _ in },
        onMove: { _, _ in },
        onDelete: { _ in },
        onSetSpan: { _, _ in }
    )
    .background { GlowBackdrop() }
}

#Preview("Empty") {
    @Previewable @State var position: StripItem?
    SlideStrip(
        project: SampleProjects.all[2],
        position: $position,
        importingCells: [],
        cellActions: .preview,
        session: CropSession(),
        layerSession: LayerSession(),
        layerActions: .preview,
        layersSlideID: nil,
        onBackgroundTap: {},
        onAddSlide: {},
        onChangeLayout: { _ in },
        onMove: { _, _ in },
        onDelete: { _ in },
        onSetSpan: { _, _ in }
    )
    .background { GlowBackdrop() }
}
