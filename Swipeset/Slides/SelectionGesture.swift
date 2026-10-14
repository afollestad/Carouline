//
//  SelectionGesture.swift
//  Swipeset
//

import SwiftUI

/// Where a slide sits under `SelectionGesture`, scaled and scrolled as it is on screen, and the
/// size it's laid out at, which the gesture's locations convert between.
struct SlideFrame {
    let frame: CGRect
    let size: CGSize
}

/// The frames of the slides holding a selection, as their cards report them. Not observed, so a
/// report redraws nothing.
final class SlideFrames {
    var frames: [UUID: SlideFrame] = [:]
}

/// What a gesture began on, which it moves alone: a photo, by its cell and its copy, so another
/// photo landing in the cell isn't moved by it, or a layer.
enum SelectionTarget: Equatable {
    case photo(CellAddress, imageID: UUID)
    case layer(LayerAddress)

    var slideID: UUID {
        switch self {
        case .photo(let address, _): address.slideID
        case .layer(let address): address.slideID
        }
    }
}

/// The gesture under way: the fingers on the strip, what it began on and its slide's frame then,
/// which it keeps however the strip moves meanwhile, as it does when it centers a new selection.
final class SelectionGestureTracker {
    var touches = SelectionTouches()
    var target: SelectionTarget?
    var frame: SlideFrame?
    /// Whether the next update starts a gesture, rather than carrying one on.
    var needsBegin = true
    /// The fingers' segment the photo was last framed in, so it frames afresh from the crop it's
    /// at once they change.
    var photoSegment: Int?
    /// Whether the gesture's `claim` is under way, which outlasts the last finger for a moment,
    /// and alone carries a trackpad's pinch.
    var isClaiming = false
    /// Whether a finger scrolled the strip during the gesture, which then leaves the selection
    /// alone, so a second finger landing doesn't pinch it as the strip slides by.
    var scrolledStrip = false
}

/// Where a point on a slide falls in one of its cells.
nonisolated enum SelectionHit {
    /// `point`, in `canvas`'s coordinates, as a point in cell `cell`'s own, when it's within the
    /// cell grown to a fingertip's target on screen, so a thin panorama's cell can still be
    /// grabbed; or nil when it's off the cell.
    static func cellPoint(_ point: CGPoint, cell: Int, of slide: Slide, style: SlideStyle, on canvas: LayerCanvas) -> CGPoint? {
        let frames = SlideGeometry.cellFrames(for: slide.layout, in: canvas.size, style: style, span: slide.span)
        guard frames.indices.contains(cell) else {
            return nil
        }
        let frame = frames[cell]
        let side = LayerGeometry.minimumTarget * canvas.screenPoint
        let reach = frame.insetBy(dx: -max(0, (side - frame.width) / 2), dy: -max(0, (side - frame.height) / 2))
        guard reach.contains(point) else {
            return nil
        }
        return CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
    }
}

/// Drags, pinches and twists that move the selected photo or layer. The strip's one gesture,
/// over everything on it, since one on a cell or a layer would claim the first finger, and a
/// pinch with the other off it would do nothing. A drag moves the selection only if it starts
/// within it, even where another layer covers it, and holds the strip still meanwhile; one off it
/// scrolls the strip. Two fingers move, size and turn it from anywhere, unless the strip is
/// scrolling, and whichever fingers stay down carry it on as others lift or land.
struct SelectionGesture: ViewModifier {
    let project: Project
    let session: CropSession
    let layerSession: LayerSession
    let cellActions: CellActions
    let layerActions: LayerActions
    let frames: SlideFrames
    /// While anything is selected. Turning off ends a gesture under way, which SwiftUI may not.
    let isEnabled: Bool
    /// Whether the strip holds still for the gesture, which a finger landing on the selection, or
    /// a second finger anywhere, asks it to.
    @Binding var holdsStrip: Bool
    /// Whether a finger is scrolling the strip, or it's still coasting from one.
    let isStripScrolling: Bool
    @State private var tracker = SelectionGestureTracker()
    /// Whether `claim` is under way, which SwiftUI resets however it ends, as when the system
    /// cancels it without `onEnded`. A finger lifting ends it early, while others carry on.
    @GestureState private var isClaiming = false

    /// The space the gesture's locations are in, which the cards report their frames in. A name
    /// rather than the space itself, which the cards' `Sendable` measurements can't capture.
    nonisolated static let space = "SelectionGesture"

    func body(content: Content) -> some View {
        // The space on the very view the gesture is on, since pinches and twists report where
        // they began only in that view's own.
        content
            .coordinateSpace(.named(Self.space))
            .highPriorityGesture(claim, isEnabled: isEnabled)
            .gesture(TouchTracking(space: Self.space, isEnabled: isEnabled, onTouches: track, claims: claimsTouches))
            .onChange(of: isClaiming) { _, isClaiming in
                tracker.isClaiming = isClaiming
                if !isClaiming, tracker.touches.isEmpty {
                    end()
                }
            }
            .onChange(of: isEnabled) { _, isEnabled in
                if !isEnabled {
                    end()
                }
            }
            .onChange(of: isStripScrolling) { _, isScrolling in
                if isScrolling, !tracker.touches.isEmpty {
                    tracker.scrolledStrip = true
                }
            }
    }

    /// Claims a pinch or a twist ahead of the slides' taps. The fingers' moves come from
    /// `TouchTracking`, since these end or reset as a finger lifts or lands; its values only start
    /// the move, and carry a trackpad's pinch, which reports no fingers. No drag, which, given
    /// priority, would hold the strip's scrolling back even for a drag off the selection.
    private var claim: some Gesture {
        SimultaneousGesture(MagnifyGesture(), RotateGesture())
            .updating($isClaiming) { _, isClaiming, _ in
                isClaiming = true
            }
            .onChanged { value in
                tracker.isClaiming = true
                let magnify = value.first
                let rotate = value.second
                if let anchor = magnify?.startLocation ?? rotate?.startLocation, tracker.touches.takesIndirect {
                    tracker.touches.updateIndirect(magnification: magnify?.magnification, rotation: rotate?.rotation.radians, at: anchor)
                    update()
                } else if !tracker.touches.isMoving {
                    tracker.touches.claim()
                    update()
                }
            }
    }

    /// Takes the fingers that landed, moved or lifted on the strip, and ends the gesture with the
    /// last one up, unless `claim` hasn't ended yet, which then ends it.
    private func track(_ touches: [SelectionTouches.Touch]) {
        // A click during a trackpad's pinch leaves the pinch to carry on.
        guard !tracker.touches.isIndirect else {
            return
        }
        let isNew = tracker.touches.isEmpty
        tracker.touches.update(touches)
        if isNew {
            // A gesture that never ended may have left one.
            finish()
            if isStripScrolling {
                // A finger landing on the coasting strip only stops it, as on any scroll view;
                // holding the strip there would leave it between two slides.
                tracker.scrolledStrip = true
            } else if let landing = touches.first(where: \.isDown)?.location, isOnSelection(landing) {
                holdsStrip = true
            }
        }
        // A second finger from anywhere holds the strip too, as it lands, so the fingers pinch
        // rather than scroll, unless the strip has started scrolling.
        if tracker.touches.fingerCount > 1, !holdsStrip, !tracker.scrolledStrip {
            holdsStrip = true
        }
        update()
        if tracker.touches.isEmpty, !tracker.isClaiming {
            end()
        }
    }

    /// Whether the fingers are moving the selection, which `TouchTracking` then claims from the
    /// slides' taps, so a short drag doesn't end as a tap on whatever it crossed.
    private func claimsTouches() -> Bool {
        holdsStrip && tracker.touches.isMoving && !tracker.scrolledStrip
    }

    /// The photo or layer selected now: a cell's address and its copy, or a layer's address.
    private var currentTarget: SelectionTarget? {
        if let address = session.selection, let image = photo(at: address) {
            return .photo(address, imageID: image.id)
        }
        return layerSession.selection.map { .layer($0) }
    }

    /// Whether `point`, in the gesture's space, is on the selection as it's drawn now: within a
    /// layer's hit box, or a photo's cell grown to a fingertip's reach.
    private func isOnSelection(_ point: CGPoint) -> Bool {
        guard let target = currentTarget,
              let frame = frames.frames[target.slideID],
              frame.frame.width > 0, frame.size.width > 0,
              let slide = project.slides.first(where: { $0.id == target.slideID }) else {
            return false
        }
        let canvas = canvas(of: slide, in: frame)
        let point = canvasPoint(point, in: frame)
        switch target {
        case .layer(let address):
            guard var layer = layer(at: address, on: slide) else {
                return false
            }
            layer.placement = layerSession.livePlacement ?? layer.placement
            return LayerGeometry.contains(point, layer: layer, on: canvas)
        case .photo(let address, _):
            return SelectionHit.cellPoint(point, cell: address.index, of: slide, style: style(of: slide), on: canvas) != nil
        }
    }

    private func begin() {
        // A gesture SwiftUI dropped without ending may have left one.
        finish()
        tracker.needsBegin = false
        // Not on a slide that hasn't measured itself, whose frame would make the move infinite.
        guard let target = currentTarget,
              let frame = frames.frames[target.slideID],
              frame.frame.width > 0, frame.size.width > 0 else {
            return
        }
        tracker.target = target
        tracker.frame = frame
    }

    /// Moves the selection by what the fingers have done: a layer by their totals since the
    /// gesture began, which it sizes and turns about its own center, and a photo by what they've
    /// done since they last changed, framed afresh from the crop it's at, so it zooms about the
    /// fingers down now.
    private func update() {
        let touches = tracker.touches
        guard touches.isMoving, let start = touches.start, !tracker.scrolledStrip else {
            return
        }
        if tracker.needsBegin {
            begin()
        }
        // Not once something else is selected, which mustn't take on this gesture's totals.
        guard let target = tracker.target, let frame = tracker.frame, target == currentTarget,
              let slide = project.slides.first(where: { $0.id == target.slideID }) else {
            return
        }
        let canvas = canvas(of: slide, in: frame)
        let screenPoint = canvas.screenPoint
        let scaled = { (size: CGSize) in CGSize(width: size.width * screenPoint, height: size.height * screenPoint) }
        let pinch = touches.pinch
        switch target {
        case .layer(let address):
            guard let layer = layer(at: address, on: slide) else {
                return
            }
            // A trackpad's pinch drags nothing, so it never snaps a center it doesn't move.
            let drag = touches.isIndirect ? nil : LayerDrag(
                start: canvasPoint(start, in: frame),
                translation: scaled(touches.translation),
                pinchTranslation: pinch.map { scaled($0.translation) }
            )
            let gesture = LayerGesture(drag: drag, magnification: pinch?.magnification, rotation: pinch?.rotation)
            layerSession.move(layer, by: gesture, on: canvas)
        case .photo(let address, _):
            let segment = touches.segment
            if tracker.photoSegment != segment.count {
                session.rebase()
                tracker.photoSegment = segment.count
            }
            let drag = touches.isIndirect ? nil : LayerDrag(
                start: canvasPoint(start, in: frame),
                translation: scaled(segment.translation),
                pinchTranslation: pinch == nil ? nil : scaled(segment.translation)
            )
            let zoom = pinch == nil ? nil : segment.magnification.map { (magnification: $0, start: canvasPoint(segment.anchor, in: frame)) }
            framePhoto(at: address, on: slide, canvas: canvas, drag: drag, pinch: zoom)
        }
    }

    /// Pans the photo by a drag that began within its cell's reach, or by the fingers since a
    /// second joined from anywhere, and zooms it by a pinch, about where the fingers were when it
    /// began framing afresh when that's within reach of the cell, or else about its middle. A
    /// photo ignores twists, and an update with nothing to apply frames nothing, so a drag off
    /// it redraws nothing.
    private func framePhoto(
        at address: CellAddress,
        on slide: Slide,
        canvas: LayerCanvas,
        drag: LayerDrag?,
        pinch: (magnification: CGFloat, start: CGPoint)?
    ) {
        guard slide.cells.indices.contains(address.index), let image = slide.cells[address.index].image else {
            return
        }
        let style = style(of: slide)
        let reaches = { (point: CGPoint) in
            SelectionHit.cellPoint(point, cell: address.index, of: slide, style: style, on: canvas)
        }
        let translation = drag.flatMap { reaches($0.start) == nil ? $0.pinchTranslation : $0.translation }
        guard translation != nil || pinch != nil else {
            return
        }
        let cell = session.cellSize
        let anchor = pinch.flatMap { reaches($0.start) }.map {
            CGPoint(x: min(max(0, $0.x), cell.width), y: min(max(0, $0.y), cell.height))
        } ?? CGPoint(x: cell.width / 2, y: cell.height / 2)
        session.frame(image, translation: translation, magnification: pinch?.magnification, anchor: anchor)
    }

    /// Ends the gesture and forgets its fingers, however it ended, letting the strip scroll again.
    private func end() {
        finish()
        tracker.touches = SelectionTouches()
        tracker.scrolledStrip = false
        if holdsStrip {
            holdsStrip = false
        }
    }

    /// Ends the move once and saves what it moved, while that's still selected; a new selection
    /// has saved it already.
    private func finish() {
        defer {
            tracker.target = nil
            tracker.frame = nil
            tracker.needsBegin = true
            tracker.photoSegment = nil
        }
        switch tracker.target {
        case .photo(let address, let imageID):
            guard session.selection == address, photo(at: address)?.id == imageID else {
                return
            }
            if let crop = session.endFraming() {
                cellActions.setCrop(crop, address)
            }
        case .layer(let address):
            if let placement = layerSession.endMoving() {
                layerActions.setPlacement(placement, address)
            }
        case nil:
            break
        }
    }

    private func photo(at address: CellAddress) -> PlacedImage? {
        guard let slide = project.slides.first(where: { $0.id == address.slideID }),
              slide.cells.indices.contains(address.index) else {
            return nil
        }
        return slide.cells[address.index].image
    }

    /// The selected layer as its slide draws it: a new one's draft, or the library's with the
    /// edits its editor has drafted, so the drag starts on the box that's on screen.
    private func layer(at address: LayerAddress, on slide: Slide) -> Layer? {
        let draft = layerSession.draftLayer(address.layerID)
        guard var layer = slide.layers.first(where: { $0.id == address.layerID }) else {
            return draft
        }
        if let draft {
            layer.content = layer.content.editing(draft.content) ?? layer.content
        }
        return layer
    }

    /// The slide at `frame` as layers measure it, with how many of its points a point on screen
    /// covers there.
    private func canvas(of slide: Slide, in frame: SlideFrame) -> LayerCanvas {
        LayerCanvas(size: frame.size, span: slide.span, screenPoint: frame.size.width / frame.frame.width)
    }

    /// The style `slide` draws with now: the one its editor is trying out, or its own.
    private func style(of slide: Slide) -> SlideStyle {
        layerSession.stylingSlideID == slide.id ? layerSession.slideStyle : slide.style
    }

    /// `point`, in the gesture's space, in the coordinates of the slide at `frame`.
    private func canvasPoint(_ point: CGPoint, in frame: SlideFrame) -> CGPoint {
        let screenPoint = frame.size.width / frame.frame.width
        return CGPoint(x: (point.x - frame.frame.minX) * screenPoint, y: (point.y - frame.frame.minY) * screenPoint)
    }
}
