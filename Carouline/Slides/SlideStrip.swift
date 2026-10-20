//
//  SlideStrip.swift
//  Carouline
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
    /// The slide whose layers sheet is open, which the strip holds still for, so the slide being
    /// edited stays put.
    let layersSlideID: UUID?
    /// Taps between the slides, or in the margins beside them while they're scaled down, which
    /// finish framing a photo or moving a layer.
    let onBackgroundTap: () -> Void
    let onAddSlide: () -> Void
    let onChangeLayout: (UUID) -> Void
    let onMove: (UUID, Int) -> Void
    let onDelete: (UUID) -> Void
    let onSetSpan: (UUID, Int) -> Void
    @State private var size: CGSize = .zero
    /// The strip's size before `bottomRoom` is taken from it.
    @State private var fullSize: CGSize = .zero
    /// Where the slides holding a selection are, which the selection's gesture moves it on.
    @State private var slideFrames = SlideFrames()
    /// Whether the strip holds still for a gesture moving the selection, which starts on it or
    /// pinches it.
    @State private var holdsStill = false
    /// Whether a finger is scrolling the strip, or it's still coasting from one, which the fingers
    /// down meanwhile leave the selection alone for.
    @State private var isScrolling = false
    /// Where the strip is on screen, inside the safe area, and where the screen behind it is, which
    /// find a column of bar buttons beside it.
    @State private var safeFrame: CGRect = .zero
    @State private var screenFrame: CGRect = .zero
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// The caption's height and the gap above it, which the slide makes room for.
    private static let captionSpace: CGFloat = 56
    private static let spacing: CGFloat = 20
    private static let addButtonSize: CGFloat = 56
    /// The narrowest an iPad's layers popover can be squeezed beside its slide, and the room its
    /// arrow and the screen's edge take.
    private static let popoverMinWidth: CGFloat = 320
    private static let popoverMargin: CGFloat = 24
    /// The least `roomScale` shrinks the slides to. In landscape the keyboard and the sheet's
    /// typing height can outgrow the strip, which would scale them to nothing or flip them, though
    /// the sheet there is always full height and covers them.
    private static let minimumRoomScale: CGFloat = 0.2

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
        .scaleEffect(roomScale, anchor: .top)
        // Past the scale, which would otherwise shrink the strip the sheet makes room in, and the
        // sheet's resting height with it, over and over.
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            layerSession.stripHeight = height
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .global).maxY
        } action: { bottom in
            layerSession.stripBottom = bottom
        }
        // Past the scale, so taps in the margins it leaves beside the slides still finish, and
        // pinches there still reach the selection.
        .contentShape(.rect)
        .onTapGesture(perform: onBackgroundTap)
        .modifier(SelectionGesture(
            project: project,
            session: session,
            layerSession: layerSession,
            cellActions: cellActions,
            layerActions: layerActions,
            frames: slideFrames,
            isEnabled: isAnythingSelected,
            holdsStrip: $holdsStill,
            isStripScrolling: isScrolling
        ))
        .animation(.smooth(duration: 0.25), value: bottomRoom)
        .animation(.smooth(duration: 0.25), value: roomScale)
        // On a phone, the keyboard a text layer is typed with would lay the slides out smaller,
        // which `roomScale` does instead. An iPad's slides keep making room for it.
        .ignoresSafeArea(horizontalSizeClass == .compact ? .keyboard : [])
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            safeFrame = frame
        }
        .background {
            Color.clear
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    screenFrame = frame
                }
                .ignoresSafeArea()
        }
    }

    /// How far a column of bar buttons reaches in from the trailing edge, as iPhone Duo stacks them
    /// there, which the strip stops short of rather than scrolling slides under: the safe area's
    /// trailing inset past its leading one, since a notch's are the same on both sides.
    private var barColumnWidth: CGFloat {
        max(0, (screenFrame.maxX - safeFrame.maxX) - (safeFrame.minX - screenFrame.minX))
    }

    /// Room under the slides, so the one being edited shrinks to stay in view above an iPad's
    /// layers popover when the slide leaves it no room beside.
    private var bottomRoom: CGFloat {
        guard horizontalSizeClass != .compact,
              let slide = project.slides.first(where: { $0.id == layersSlideID }) else {
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

    /// How far a phone shrinks the slides while its layers sheet is open, so the one being edited
    /// stays in view and in reach above the sheet, or above the keyboard and the short sheet over
    /// it while a text layer is typed: the room above the selection bar's, fitted into the room
    /// they leave. Scaled rather than laid out smaller, since the lazy stack drops the slide while
    /// laying out its new size, and rebuilds it. Not in landscape, where the sheet is always full
    /// height and covers the slides however small they are.
    private var roomScale: CGFloat {
        let sheetRoom = verticalSizeClass == .compact ? 0 : layerSession.sheetRoom
        let room = max(layerSession.keyboardRoom, sheetRoom)
        let content = fullSize.height - SelectionBar.reservedHeight
        guard horizontalSizeClass == .compact, room > 0, content > 0 else {
            return 1
        }
        return min(1, max(Self.minimumRoomScale, (fullSize.height - room) / content))
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
                        size: cardSize(span: slide.span),
                        screenPoint: 1 / roomScale,
                        frames: slideFrames,
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
        }
        .scrollTargetBehavior(snapping)
        // Held while a gesture moves the selection, so a drag on it moves it rather than the strip,
        // while one off it scrolls the strip as usual.
        .scrollDisabled(holdsStill || layersSlideID != nil)
        .onScrollPhaseChange { _, phase in
            isScrolling = phase == .interacting || phase == .decelerating
        }
        .sensoryFeedback(.alignment, trigger: layerSession.snapsTaken)
        .scrollPosition(id: $position, anchor: .center)
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        // Cut off where the column starts, as the scroll view reaches on under it whatever its
        // safe area.
        .clipShape(TrailingClip(isClipping: barColumnWidth > 0))
    }

    private var isAnythingSelected: Bool {
        session.selection != nil || layerSession.selection != nil
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

/// Clips off what's past the trailing edge, when `isClipping`, leaving the other edges open, so
/// slides still reach under the leading safe area and the bars above and below.
private struct TrailingClip: Shape {
    /// Far enough past the open edges to hold anything drawn beyond them.
    private static let reach: CGFloat = 10_000

    let isClipping: Bool

    func path(in rect: CGRect) -> Path {
        let open = rect.insetBy(dx: -Self.reach, dy: -Self.reach)
        return Path(isClipping ? open.divided(atDistance: rect.maxX - open.minX, from: .minXEdge).slice : open)
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
