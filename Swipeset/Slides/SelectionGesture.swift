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

/// The gesture under way: what it began on and its slide's frame then, which it keeps however
/// the strip moves meanwhile, as it does when it centers a new selection.
final class SelectionGestureTracker {
    var target: SelectionTarget?
    var frame: SlideFrame?
    /// Whether the next update starts a gesture, rather than carrying one on.
    var needsBegin = true
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
/// within it, even where another layer covers it; pinches and twists move it from anywhere.
struct SelectionGesture: ViewModifier {
    let project: Project
    let session: CropSession
    let layerSession: LayerSession
    let cellActions: CellActions
    let layerActions: LayerActions
    let frames: SlideFrames
    /// While anything is selected. Turning off ends a gesture under way, which SwiftUI may not.
    let isEnabled: Bool
    @State private var tracker = SelectionGestureTracker()
    /// Whether a gesture is under way, which SwiftUI resets however it ends, as when the system
    /// cancels it without `onEnded`.
    @GestureState private var isActive = false

    /// The space the gesture's locations are in, which the cards report their frames in. A name
    /// rather than the space itself, which the cards' `Sendable` measurements can't capture.
    nonisolated static let space = "SelectionGesture"

    func body(content: Content) -> some View {
        // The space on the very view the gesture is on, since pinches and twists report where
        // they began only in that view's own. Ahead of the slides' own gestures, so a short drag
        // over a photo or a layer doesn't end as a tap that selects it.
        content
            .coordinateSpace(.named(Self.space))
            .highPriorityGesture(gesture, isEnabled: isEnabled)
            .onChange(of: isActive) { _, isActive in
                if !isActive {
                    finish()
                }
            }
            .onChange(of: isEnabled) { _, isEnabled in
                if !isEnabled {
                    finish()
                }
            }
    }

    /// Its drag keeps its least distance, so taps still reach the layers, the cells and the
    /// space between the slides.
    private var gesture: some Gesture {
        SimultaneousGesture(SimultaneousGesture(DragGesture(), MagnifyGesture()), RotateGesture())
            .updating($isActive) { _, isActive, _ in
                isActive = true
            }
            .onChanged { value in
                update(drag: value.first?.first, magnify: value.first?.second, rotation: value.second?.rotation.radians)
            }
            .onEnded { _ in
                finish()
            }
    }

    /// The photo or layer selected now: a cell's address and its copy, or a layer's address.
    private var currentTarget: SelectionTarget? {
        if let address = session.selection, let image = photo(at: address) {
            return .photo(address, imageID: image.id)
        }
        return layerSession.selection.map { .layer($0) }
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

    private func update(drag: DragGesture.Value?, magnify: MagnifyGesture.Value?, rotation: Double?) {
        if tracker.needsBegin {
            begin()
        }
        // Not once something else is selected, which mustn't take on this gesture's totals.
        guard let target = tracker.target, let frame = tracker.frame, target == currentTarget,
              let slide = project.slides.first(where: { $0.id == target.slideID }) else {
            return
        }
        let screenPoint = frame.size.width / frame.frame.width
        let canvas = LayerCanvas(size: frame.size, span: slide.span, screenPoint: screenPoint)
        let canvasDrag = drag.map {
            LayerDrag(
                start: canvasPoint($0.startLocation, in: frame),
                translation: CGSize(width: $0.translation.width * screenPoint, height: $0.translation.height * screenPoint)
            )
        }
        switch target {
        case .layer(let address):
            guard let layer = layer(at: address, on: slide) else {
                return
            }
            let gesture = LayerGesture(drag: canvasDrag, magnification: magnify?.magnification, rotation: rotation)
            layerSession.move(layer, by: gesture, on: canvas)
        case .photo(let address, _):
            let pinch = magnify.map { (magnification: $0.magnification, start: canvasPoint($0.startLocation, in: frame)) }
            framePhoto(at: address, on: slide, canvas: canvas, drag: canvasDrag, pinch: pinch)
        }
    }

    /// Pans the photo by a drag that began within its cell's reach, and zooms it by a pinch, about
    /// where the pinch began when that's within reach of the cell, or else about its middle. A
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
        let style = layerSession.stylingSlideID == slide.id ? layerSession.slideStyle : slide.style
        let reaches = { (point: CGPoint) in
            SelectionHit.cellPoint(point, cell: address.index, of: slide, style: style, on: canvas)
        }
        let translation = drag.flatMap { reaches($0.start) == nil ? nil : $0.translation }
        guard translation != nil || pinch != nil else {
            return
        }
        let cell = session.cellSize
        let anchor = pinch.flatMap { reaches($0.start) }.map {
            CGPoint(x: min(max(0, $0.x), cell.width), y: min(max(0, $0.y), cell.height))
        } ?? CGPoint(x: cell.width / 2, y: cell.height / 2)
        session.frame(image, translation: translation, magnification: pinch?.magnification, anchor: anchor)
    }

    /// Ends the gesture once, however it ended, and saves what it moved, while that's still
    /// selected; a new selection has saved it already.
    private func finish() {
        defer {
            tracker.target = nil
            tracker.frame = nil
            tracker.needsBegin = true
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

    /// `point`, in the gesture's space, in the coordinates of the slide at `frame`.
    private func canvasPoint(_ point: CGPoint, in frame: SlideFrame) -> CGPoint {
        let screenPoint = frame.size.width / frame.frame.width
        return CGPoint(x: (point.x - frame.frame.minX) * screenPoint, y: (point.y - frame.frame.minY) * screenPoint)
    }
}
