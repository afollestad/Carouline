//
//  LayerSession.swift
//  Swipeset
//

import Foundation
import Observation

/// The layer selected to move, size and turn, and its placement mid-gesture. Only the selected
/// layer and its slide's guides read `livePlacement` and `snap`, so a gesture redraws them
/// alone rather than every slide, and the project saves once when it ends.
@Observable
final class LayerSession {
    var selection: LayerAddress? {
        // A gesture cut short by a new selection never ends, so the next one would otherwise
        // begin from its placement.
        didSet {
            if selection != oldValue {
                gestureStart = nil
            }
        }
    }
    /// The placement being dragged, pinched, twisted or slid to, before it's saved.
    var livePlacement: LayerPlacement?
    /// What the layer being moved has snapped to.
    private(set) var snap: LayerSnap
    /// How many snaps have taken hold mid-gesture, for a haptic each. One the layer sat in when
    /// the gesture began, as a layer already centered does, doesn't count.
    private(set) var snapsTaken = 0
    /// The placement when the current gesture began, which its values build on.
    @ObservationIgnored private var gestureStart: LayerPlacement?
    /// The layer the current gesture began on. Its updates go to that layer alone, so a gesture
    /// still running when another layer is selected, as when an import selects its picture,
    /// never moves that one.
    @ObservationIgnored private var gestureLayerID: UUID?

    /// `snap` shows a guide from the start, as snapshots need.
    init(selection: LayerAddress? = nil, snap: LayerSnap = LayerSnap()) {
        self.selection = selection
        self.snap = snap
    }

    /// Moves, sizes and turns `layer` by a gesture's values on `canvas`, each building on the
    /// placement the gesture began from, so the layer tracks the fingers exactly, then snaps it.
    func move(_ layer: Layer, by gesture: LayerGesture, on canvas: LayerCanvas) {
        // Until the slide has measured itself there's nothing to move the layer across.
        guard canvas.size.width > 0, canvas.size.height > 0, selection?.layerID == layer.id else {
            return
        }
        if gestureLayerID == nil {
            gestureLayerID = layer.id
        }
        guard gestureLayerID == layer.id else {
            return
        }
        let isStarting = gestureStart == nil
        let start = gestureStart ?? livePlacement ?? layer.placement
        gestureStart = start
        var placement = start
        if let translation = gesture.translation {
            placement.centerX += translation.width / canvas.slideWidth
            placement.centerY += translation.height / canvas.size.height
        }
        if let magnification = gesture.magnification {
            placement.scale *= magnification
        }
        if let rotation = gesture.rotation {
            placement.rotation += rotation
        }
        let moves = gesture.translation != nil
        let turns = gesture.rotation != nil
        let held = isStarting ? LayerSnapping.snapped(start, on: canvas, previous: LayerSnap(), moves: moves, turns: turns).snap : snap
        let snapped = LayerSnapping.snapped(placement.clamped(span: canvas.span), on: canvas, previous: held, moves: moves, turns: turns)
        if snapped.snap.takesHold(after: held) {
            snapsTaken += 1
        }
        snap = snapped.snap
        livePlacement = snapped.placement
    }

    /// Ends the gesture, returning the placement it left for saving, unless another layer was
    /// selected while it ran.
    func endMoving() -> LayerPlacement? {
        defer {
            livePlacement = nil
            gestureStart = nil
            gestureLayerID = nil
            snap = LayerSnap()
        }
        guard gestureLayerID == nil || gestureLayerID == selection?.layerID else {
            return nil
        }
        return livePlacement
    }
}

/// A drag's, a pinch's and a twist's values so far, any of which a gesture may lack.
struct LayerGesture {
    var translation: CGSize?
    var magnification: CGFloat?
    /// Radians clockwise.
    var rotation: Double?
}
