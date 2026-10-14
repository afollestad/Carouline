//
//  LayerSession.swift
//  Carouline
//

import CoreGraphics
import Foundation
import Observation

/// The layer selected to move, size and turn, and its placement mid-gesture. Only the selected
/// layer and its slide's guides read `livePlacement` and `snap`, so a gesture redraws them
/// alone rather than every slide, and the project saves once when it ends.
@Observable
final class LayerSession {
    var selection: LayerAddress? {
        // A gesture still running when another layer is selected moves nothing more, and the
        // next one begins from that layer's own placement, judging its drag afresh.
        didSet {
            if selection != oldValue {
                gestureStart = nil
                dragStartsOnLayer = nil
                isTurning = false
            }
        }
    }
    /// The placement being dragged, pinched, twisted or slid to, before it's saved.
    var livePlacement: LayerPlacement?
    /// The layers sheet's pages past its list, which its navigation stack shows.
    var sheetPath: [LayersPage] = []
    /// The height the keyboard and the sheet over it cover while a text layer is typed, which the
    /// strip makes room above on a phone, so the slide stays in view.
    var keyboardRoom: CGFloat = 0
    /// The height a phone's layers sheet covers once it settles at the height it rests or is
    /// dragged to, which the strip makes room above as for the keyboard, so the slide stays in view
    /// and in reach.
    var sheetRoom: CGFloat = 0
    /// The strip's unscaled height, which the layers sheet rests at half of. Read from the strip's
    /// size rather than its frame on screen, which whatever moves the screen around it changes,
    /// so the sheet's heights change only with the strip.
    var stripHeight: CGFloat = 0
    /// Where the strip's unscaled frame ends on screen, which the layers sheet measures its room
    /// up from. Read only as the sheet settles, so it redraws nothing.
    @ObservationIgnored var stripBottom: CGFloat = 0
    /// The layer whose text is being typed, which drops the sheet to just its field. An editor
    /// clears only its own, since SwiftUI doesn't order one editor's going and the next's coming.
    var typingLayerID: UUID?
    /// The slide whose blur and style the layers sheet's controls are editing. It changes only as
    /// the edit starts and ends, so every slide can read it while only that one reads `slideBlur`
    /// and `slideStyle`.
    private(set) var stylingSlideID: UUID?
    /// The blur that slide is being dragged to, before it's saved.
    var slideBlur: Double = 0
    /// The style that slide is being given, before it's saved.
    var slideStyle = SlideStyle.standard
    /// The edits of the layer editor on screen: a layer's content, or a new text layer entire,
    /// which its slide draws as they're made, and `saveDraft(to:projectID:)` saves once.
    var draft: Layer?
    /// `draft`'s layer and slide. They change only as editing starts and stops, so every slide
    /// can read them while only the edited layer's view reads `draft`, which changes with each
    /// keystroke.
    private(set) var draftLayerID: UUID?
    private(set) var draftSlideID: UUID?
    /// Whether `draft` is a layer the library doesn't have yet.
    private(set) var isDraftNew = false
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
    /// Whether the current gesture's drag began on its layer, decided at its first update with a
    /// drag, so a drag moves the layer only from on it, or once a second finger joins, and keeps
    /// moving it once the layer has left the finger's start.
    @ObservationIgnored private var dragStartsOnLayer: Bool?
    /// Whether the current gesture has turned the layer yet, which a twist may begin only partway
    /// through.
    @ObservationIgnored private var isTurning = false

    /// `snap` shows a guide from the start, as snapshots need.
    init(selection: LayerAddress? = nil, snap: LayerSnap = LayerSnap()) {
        self.selection = selection
        self.snap = snap
    }

    /// Moves, sizes and turns `layer` by a gesture's values on `canvas`, each building on the
    /// placement the gesture began from, so the layer tracks the fingers exactly, then snaps it.
    /// A drag that began off the layer moves it only as far as the fingers have moved since a
    /// second joined, and an update with nothing else to apply, or a pinch or twist that isn't
    /// finite, changes nothing, not even where the gesture begins from.
    func move(_ layer: Layer, by gesture: LayerGesture, on canvas: LayerCanvas) {
        // Until the slide has measured itself there's nothing to move the layer across.
        guard canvas.size.width > 0, canvas.size.height > 0, selection?.layerID == layer.id else {
            return
        }
        // A pinch or twist can report a value that isn't finite, which would draw the layer
        // nowhere; it holds where the last update left it.
        guard gesture.magnification?.isFinite != false, gesture.rotation?.isFinite != false else {
            return
        }
        if gestureLayerID == nil {
            gestureLayerID = layer.id
        }
        guard gestureLayerID == layer.id else {
            return
        }
        let start = gestureStart ?? livePlacement ?? layer.placement
        let translation = acceptedTranslation(of: gesture.drag, on: layer, at: start, canvas: canvas)
        guard translation != nil || gesture.magnification != nil || gesture.rotation != nil else {
            return
        }
        let isStarting = gestureStart == nil
        gestureStart = start
        var placement = start
        if let translation {
            placement.centerX += translation.width / canvas.slideWidth
            placement.centerY += translation.height / canvas.size.height
        }
        if let magnification = gesture.magnification {
            placement.scale *= magnification
        }
        if let rotation = gesture.rotation {
            placement.rotation += rotation
        }
        let moves = translation != nil
        let turns = gesture.rotation != nil
        var held = isStarting ? LayerSnapping.snapped(start, on: canvas, previous: LayerSnap(), moves: moves, turns: turns).snap : snap
        // A twist joining the gesture holds the quarter turn the layer began at, as one there from
        // the start does, so a layer that was upright already counts no snap taking hold.
        if turns, !isTurning {
            held.quarterTurn = LayerSnapping.snapped(start, on: canvas, previous: LayerSnap(), moves: false, turns: true).snap.quarterTurn
            isTurning = true
        }
        var placed = layer
        placed.placement = placement
        let snapped = LayerSnapping.snapped(placed.clamped(span: canvas.span).placement, on: canvas, previous: held, moves: moves, turns: turns)
        if snapped.snap.takesHold(after: held) {
            snapsTaken += 1
        }
        snap = snapped.snap
        livePlacement = snapped.placement
    }

    /// `drag`'s translation when the drag began on `layer` at the placement `start` the gesture
    /// began from, which is where the finger first touched it, or else how far it has moved since
    /// a second finger joined it, or nil.
    private func acceptedTranslation(of drag: LayerDrag?, on layer: Layer, at start: LayerPlacement, canvas: LayerCanvas) -> CGSize? {
        guard let drag else {
            return nil
        }
        if dragStartsOnLayer == nil {
            var started = layer
            started.placement = start
            dragStartsOnLayer = LayerGeometry.contains(drag.start, layer: started, on: canvas)
        }
        return dragStartsOnLayer == true ? drag.translation : drag.pinchTranslation
    }

    /// Starts editing `layer` on slide `slideID`, unless it's already the draft. A new layer
    /// isn't in the library until its draft is saved.
    func beginDraft(of layer: Layer, on slideID: UUID, isNew: Bool = false) {
        guard draftLayerID != layer.id else {
            return
        }
        draft = layer
        draftLayerID = layer.id
        draftSlideID = slideID
        isDraftNew = isNew
    }

    /// The draft, when it's the layer `layerID`, as its slide and the layer bar show it.
    func draftLayer(_ layerID: UUID) -> Layer? {
        draftLayerID == layerID ? draft : nil
    }

    /// Saves the draft to `library` and, when `endingEdit`, ends it. A new layer is added if its
    /// slide is still there; an edited one keeps its current placement, picture and place in
    /// the stack, taking just the draft's content, and is left alone if it's been deleted. Text
    /// left blank deletes its layer, or leaves a new one unsaved. Saving without ending, as the
    /// app leaves the screen, keeps editing what's now in the library, and saves no blank text,
    /// which may only have been cleared to type afresh.
    func saveDraft(to library: ProjectLibrary, projectID: UUID, endingEdit: Bool = true) {
        defer {
            if endingEdit {
                draft = nil
                draftLayerID = nil
                draftSlideID = nil
                isDraftNew = false
            }
        }
        guard let draft, let slideID = draftSlideID else {
            return
        }
        let isBlank = if case .text(let text) = draft.content { text.isBlank } else { false }
        if isBlank, !endingEdit || isDraftNew {
            return
        }
        let address = LayerAddress(projectID: projectID, slideID: slideID, layerID: draft.id)
        if isDraftNew {
            if library.saveLayer(draft, in: slideID, of: projectID) {
                isDraftNew = false
            }
        } else if library.layer(at: address) != nil {
            library.setContent(draft.content, at: address)
        }
    }

    /// Starts editing `slide`'s blur and style from what it has.
    func beginStyling(_ slide: Slide) {
        slideBlur = slide.blur
        slideStyle = slide.style
        stylingSlideID = slide.id
    }

    /// Ends editing a slide's blur and style, saving what they were left at once.
    func endStyling(to library: ProjectLibrary, projectID: UUID) {
        guard let slideID = stylingSlideID else {
            return
        }
        library.setStyle(slideStyle, blur: slideBlur, of: slideID, in: projectID)
        stylingSlideID = nil
    }

    /// Saves a gesture's or the size slider's `placement` for the layer at `address`: into a new
    /// layer's draft, since the library doesn't have it yet, or else the library.
    func commitPlacement(_ placement: LayerPlacement, at address: LayerAddress, to library: ProjectLibrary) {
        if isDraftNew, draftLayerID == address.layerID {
            let span = library.project(address.projectID)?.slides.first { $0.id == address.slideID }?.span ?? 1
            draft?.placement = placement
            draft = draft?.clamped(span: span)
        } else {
            library.setPlacement(placement, at: address)
        }
    }

    /// Ends the gesture, returning the placement it left for saving, unless another layer was
    /// selected while it ran.
    func endMoving() -> LayerPlacement? {
        defer {
            livePlacement = nil
            gestureStart = nil
            gestureLayerID = nil
            dragStartsOnLayer = nil
            isTurning = false
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
    var drag: LayerDrag?
    var magnification: CGFloat?
    /// Radians clockwise.
    var rotation: Double?
}

/// Where a drag began on its canvas and how far it has moved since, in the canvas's points. One
/// value, so a drag's translation never arrives without where it began.
struct LayerDrag {
    let start: CGPoint
    let translation: CGSize
    /// How far it has moved since a second finger joined it, which moves the layer wherever the
    /// drag began, or nil before one has.
    let pinchTranslation: CGSize?
}

/// A page of the layers sheet past its list.
enum LayersPage: Hashable {
    /// Picks the kind of layer to add.
    case add
    /// Edits a text layer.
    case text(UUID)
    /// Edits a picture layer.
    case image(UUID)

    /// The page that edits `layer`.
    static func editor(for layer: Layer) -> LayersPage {
        switch layer.content {
        case .text: .text(layer.id)
        case .image: .image(layer.id)
        }
    }
}
