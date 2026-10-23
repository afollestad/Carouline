//
//  SlideStrip.swift
//  Carouline
//

import SwiftUI

/// Something the strip can scroll to: a slide, or the button after the last one.
nonisolated enum StripItem: Hashable {
    case slide(UUID)
    case add
}

extension Project {
    /// The slide in the middle of the strip at `position`, which lights the backdrop.
    func frontSlide(at position: StripItem?) -> Slide? {
        switch position {
        case .slide(let slideID): slides.first { $0.id == slideID } ?? slides.first
        case .add: slides.last
        case nil: slides.first
        }
    }

    /// Whether slide `slideID` is in the middle of the strip at `position`, which with none set
    /// yet rests on the first slide.
    func isFront(_ slideID: UUID, at position: StripItem?) -> Bool {
        (position ?? slides.first.map { .slide($0.id) }) == .slide(slideID)
    }
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
    /// edited stays put, except along a panorama under a sheet, whose slides past the screen's
    /// sides hold layers too.
    let layersSlideID: UUID?
    /// Whether a slide's layers show in a sheet over the strip, as on a phone or wherever their
    /// popover doesn't fit, rather than in a popover beside the slide.
    var layersInSheet = false
    /// Taps between the slides, or in the margins beside them while they're scaled down, which
    /// close a slide's layers, or else finish framing a photo or moving a layer.
    let onBackgroundTap: () -> Void
    let onAddSlide: () -> Void
    let onChangeLayout: (UUID) -> Void
    let onMove: (UUID, Int) -> Void
    let onDelete: (UUID) -> Void
    let onSetSpan: (UUID, Int) -> Void
    @State private var size: CGSize = .zero
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
    /// The slide a drop hovers over, which comes to the front once the drop rests there.
    @State private var dropHoverSlideID: UUID?
    /// Where the strip is scrolled to, which `StripScrolling` keeps in step with `position`.
    @State private var scroll = ScrollPosition()
    @State private var tracked = TrackedScroll()
    @Environment(TrayPress.self) private var trayPress: TrayPress?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// The caption's height and the gap above it, which the slide makes room for.
    private static let captionSpace: CGFloat = 56
    private static let spacing: CGFloat = 20
    private static let addButtonSize: CGFloat = 56
    /// Long enough for a drag on its way past a slide not to bring it forward.
    private static let dropHoverDelay = Duration.milliseconds(600)

    var body: some View {
        let fit = roomFit
        return Group {
            if project.slides.isEmpty {
                GhostSlide(size: cardSize(span: 1), hasTrayPhotos: !project.tray.isEmpty, onAdd: onAddSlide)
                    .padding(.bottom, SelectionBar.reservedHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // A tray photo carried over the slides brings them forward as a drop does.
                let hoverSlideID = dropHoverSlideID ?? trayPress?.hoverSlideID
                strip(screenPoint: 1 / fit.scale)
                    .task(id: hoverSlideID) {
                        await bringForward(hovered: hoverSlideID)
                    }
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            self.size = size
        }
        .scaleEffect(fit.scale, anchor: .top)
        .offset(y: fit.offset)
        // Past the scale and the offset, which would otherwise shrink and move the strip the sheet
        // makes room in, and the sheet's resting height with it, over and over.
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
        // Past the scale and the offset, so taps in the margins they leave beside the slides
        // still finish, and pinches there still reach the selection.
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
            isStripScrolling: isScrolling,
            stripWidth: size.width,
            scrollAlong: scroll(along:by:)
        ))
        .animation(.smooth(duration: 0.25), value: fit)
        // Under a sheet, the keyboard a text layer is typed with would lay the slides out smaller,
        // which `roomFit` does instead. Beside a popover, they keep making room for it.
        .ignoresSafeArea(sitsUnderSheet ? .keyboard : [])
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            safeFrame = frame
        }
        .onChange(of: barColumnWidth > 0 ? safeFrame.maxX : nil, initial: true) { _, edge in
            trayPress?.setStripTrailingEdge(edge)
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

    /// Whether the slides sit under a layers sheet, which they make room above by scaling, rather
    /// than beside a popover, which they lay themselves out around.
    private var sitsUnderSheet: Bool {
        horizontalSizeClass == .compact || layersInSheet
    }

    /// Whether an iPad's layers popover fits beside a slide `span` slides wide on a strip `size`
    /// big: the room either side is at least its width, which UIKit doesn't narrow to fit, so
    /// little more than its arrow reaches the slide. Where it doesn't, as on an iPad in portrait or
    /// iPhone Duo in landscape, a slide's layers show in a sheet. Not below the slide, where even
    /// with the slides shrunk UIKit finds too little room and puts it over the slide's side.
    static func layersPopoverFits(span: Int, aspectRatio: AspectRatio, in size: CGSize) -> Bool {
        let card = cardSize(span: span, aspectRatio: aspectRatio, isRegular: true, in: size)
        return (size.width - card.width) / 2 >= LayersSheet.popoverSize.width
    }

    /// How far the slides shrink and move up while a layers sheet is open over them, so the one
    /// being edited stays in view and in reach above the sheet, or above the keyboard and the short
    /// sheet over it while a text layer is typed: the tallest slide and its caption, fitted into
    /// the room they leave. Scaled rather than laid out smaller, since slides laid out at a new size
    /// decode their photos again for it, on every frame the sheet moves. Not at a compact height, as
    /// a phone's in landscape, where the sheet is always full height and covers the slides however
    /// small they are.
    private var roomFit: RoomFit {
        guard sitsUnderSheet else {
            return .identity
        }
        return RoomFit(
            slideHeight: cardSize(span: 1).height + Self.captionSpace,
            stripHeight: size.height,
            bottomReserve: SelectionBar.reservedHeight,
            room: verticalSizeClass == .compact ? 0 : layerSession.sheetRoom
        )
    }

    private func strip(screenPoint: CGFloat) -> some View {
        let numbers = project.slideNumbers
        let built = builtSlides
        return ScrollView(.horizontal) {
            // Whole rather than lazy, so every slide sits where the strip's stops put it, which a lazy
            // stack guessing the widths of slides it hasn't built doesn't. Only those near the middle
            // build their photos and layers.
            HStack(spacing: Self.spacing) {
                ForEach(Array(project.slides.enumerated()), id: \.element.id) { index, slide in
                    if built.contains(index) {
                        card(for: slide, at: index, numbers: numbers[index], screenPoint: screenPoint)
                    } else {
                        SlidePlaceholder(
                            size: cardSize(span: slide.span),
                            background: slide.style.background,
                            label: "\(numbers[index].spokenSlidesName) of \(project.carouselSlideCount), \(slide.layout.name)"
                        )
                        // Over room as tall as a caption's, so it sits as its card does.
                        .padding(.bottom, Self.captionSpace)
                    }
                }
                AddSlideButton(size: Self.addButtonSize, action: onAddSlide)
                    // Over room as tall as a caption's, so it centers on the slides beside it rather
                    // than on them and their captions.
                    .padding(.bottom, Self.captionSpace)
            }
            // Room for the first slide and the add button each to reach the middle. Padding
            // rather than `contentMargins`, which stop view-aligned scrolling from snapping and
            // shift a centered `scrollPosition` off the middle of the screen.
            .padding(.leading, max(0, (size.width - slideWidth) / 2))
            .padding(.trailing, max(0, (size.width - Self.addButtonSize) / 2))
            .padding(.bottom, SelectionBar.reservedHeight)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
        }
        .modifier(StripScrolling(
            position: $position,
            scroll: $scroll,
            stops: stops,
            snapping: snapping,
            tracked: tracked,
            slides: project.slides,
            slideSize: project.aspectRatio.exportSize,
            slideWidth: slideWidth
        ))
        // Held while a gesture moves the selection, so a drag on it moves it rather than the strip,
        // while one off it scrolls the strip as usual.
        .scrollDisabled(holdsStill || (layersSlideID != nil && !scrollsAlongLayersSlide))
        .onScrollPhaseChange { _, phase in
            isScrolling = phase == .interacting || phase == .decelerating
        }
        .sensoryFeedback(.alignment, trigger: layerSession.snapsTaken)
        .scrollIndicators(.hidden)
        // Unclipped, so the slides either side of the middle one still peek in from the screen's
        // edges while the strip is scaled down for a layers sheet, rather than ending in a straight
        // cut at the scroll view's scaled edges.
        .scrollClipDisabled()
        .scrollEdgeEffectStyle(.soft, for: .top)
        // Cut off where the column starts, as the scroll view reaches on under it whatever its
        // safe area, and kept from taking taps there, which a clip alone still lets through.
        .clipShape(TrailingClip(isClipping: barColumnWidth > 0))
        .contentShape(TrailingClip(isClipping: barColumnWidth > 0))
    }

    /// The slide at `index` in the strip, numbered `numbers` in the carousel.
    private func card(for slide: Slide, at index: Int, numbers: ClosedRange<Int>, screenPoint: CGFloat) -> some View {
        SlideCard(
            slide: slide,
            projectID: project.id,
            numbers: numbers,
            count: project.carouselSlideCount,
            canMoveLeft: index > 0,
            canMoveRight: index < project.slides.count - 1,
            size: cardSize(span: slide.span),
            screenPoint: screenPoint,
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
            onSetSpan: { onSetSpan(slide.id, $0) },
            acceptsDrops: layersSlideID == nil && !isAnythingSelected && cellActions.held == nil,
            onDropHover: { slideID, isOver in
                // Left alone when a drop leaves a slide after entering the next.
                if isOver {
                    dropHoverSlideID = slideID
                } else if dropHoverSlideID == slideID {
                    dropHoverSlideID = nil
                }
            }
        )
        // Over its neighbors, which come later or earlier in the stack, so a tour tip grown past a
        // narrow slide still shows and takes its taps.
        .zIndex(project.frontSlide(at: position)?.id == slide.id ? 1 : 0)
        // The others hold still too while a slide's layers sheet is open, to fingers and
        // VoiceOver alike, so nothing on them is selected or edited out from under it.
        .allowsHitTesting(layersSlideID == nil || layersSlideID == slide.id)
        .accessibilityHidden(layersSlideID != nil && layersSlideID != slide.id)
    }

    private var isAnythingSelected: Bool {
        session.selection != nil || layerSession.selection != nil
    }

    /// Brings the slide a drop rests over to the front, since the strip doesn't scroll for a drag
    /// along its edge. After a moment, so a drag passing over a neighbor on its way leaves it.
    private func bringForward(hovered slideID: UUID?) async {
        guard let slideID, project.frontSlide(at: position)?.id != slideID else {
            return
        }
        try? await Task.sleep(for: Self.dropHoverDelay)
        guard !Task.isCancelled else {
            return
        }
        withAnimation {
            position = .slide(slideID)
        }
    }

    /// Whether the strip scrolls along the slide whose layers are open: a panorama under a sheet,
    /// rather than beside a popover, which moving the slide would close.
    private var scrollsAlongLayersSlide: Bool {
        sitsUnderSheet && (project.slides.first { $0.id == layersSlideID }?.span ?? 1) > 1
    }

    /// Rests the strip with a slide, or the add button, in the middle of the screen, or anywhere
    /// along a panorama. View-aligned scrolling would rest a slide's leading edge on the screen's
    /// instead, whatever its anchor. While a slide's layers are open, it rests on that slide alone.
    private var snapping: StripSnapping {
        if layersSlideID != nil, let index = project.slides.firstIndex(where: { $0.id == layersSlideID }) {
            return StripSnapping(stops: [stops.stops[index]])
        }
        return StripSnapping(stops: stops.stops)
    }

    /// The slides, then the add button, with where the strip rests for each.
    private var stops: StripStops {
        StripStops(
            items: project.slides.map { .slide($0.id) } + [.add],
            stops: StripSnapping.stops(
                spans: project.slides.map(\.span),
                slideWidth: slideWidth,
                spacing: Self.spacing,
                addButtonSize: Self.addButtonSize
            )
        )
    }

    /// Scrolls the strip by up to `distance` along slide `slideID`, no further than it rests along
    /// it, returning how far it went.
    private func scroll(along slideID: UUID, by distance: CGFloat) -> CGFloat {
        let offset = stops.offset(movedBy: distance, along: .slide(slideID), from: tracked.offset)
        let scrolled = offset - tracked.offset
        if scrolled != 0 {
            // Ahead of the scroll's report, so the next frame's builds on it.
            tracked.offset = offset
            tracked.destination = nil
            scroll.scrollTo(x: offset)
        }
        return scrolled
    }

    /// The slides that build their photos and layers: the one in the middle and those either side
    /// as far as the screen shows, scaled down for a layers sheet, and one more, so a slide coming
    /// into view is built before it gets there.
    private var builtSlides: ClosedRange<Int> {
        // Or where the strip rests, once `position`'s slide is deleted without the strip moving.
        let front = index(of: position) ?? index(of: stops.item(at: tracked.offset)) ?? 0
        let shown = size.width / 2 / max(roomFit.scale, 0.1)
        let reach = Int((shown / max(1, slideWidth + Self.spacing)).rounded(.up)) + 1
        return (front - reach)...(front + reach)
    }

    /// Where `item` is among the slides, the add button counting as the last.
    private func index(of item: StripItem?) -> Int? {
        switch item {
        case .slide(let slideID): project.slides.firstIndex { $0.id == slideID }
        case .add: project.slides.indices.last
        case nil: nil
        }
    }

    /// One slide's width, which a panorama is a whole number of.
    private var slideWidth: CGFloat {
        cardSize(span: 1).width
    }

    private func cardSize(span: Int) -> CGSize {
        Self.cardSize(span: span, aspectRatio: project.aspectRatio, isRegular: horizontalSizeClass == .regular, in: size)
    }

    /// The project's shape fitted to the screen, leaving the slides either side peeking in at the
    /// edges so the strip reads as one to scroll, and `span` of them wide. A panorama is as tall as
    /// a slide, running past the screen's sides, which the strip scrolls along.
    private static func cardSize(span: Int, aspectRatio: AspectRatio, isRegular: Bool, in size: CGSize) -> CGSize {
        let ratio = aspectRatio.widthOverHeight
        let maxWidth = size.width * (isRegular ? 0.7 : 0.82)
        let maxHeight = max(0, size.height - captionSpace - SelectionBar.reservedHeight - 32)
        let width = max(0, min(maxWidth, maxHeight * ratio))
        return CGSize(width: width * CGFloat(max(1, span)), height: width / ratio)
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
