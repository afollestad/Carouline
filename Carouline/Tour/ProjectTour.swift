//
//  ProjectTour.swift
//  Carouline
//

import SwiftUI
import TipKit

/// What an inline tip of the tour points at, by the clear stand-in beside the tip that `standIn(at:)`
/// draws. TipKit keeps anchors by ID in one store, where the last view to write an ID takes the
/// arrow, so each carries its tour's visit, which keeps another window on the same project, showing
/// the same tip, apart.
nonisolated struct TourAnchor: Hashable {
    let visit: UUID
    let target: Target

    enum Target: Hashable {
        case addPhotos
        case trayPhotos
        case photo
        case layoutButton
        case optionsButton
        case layersButton
        case layer
        case layerDone
        case share
    }
}

extension TourAnchor {
    /// A clear stand-in at `frame`, in the space it fills, for the tip beside it in one `ZStack` to
    /// point at. TipKit lines an arrow up only with an anchor beside its tip that way: on the view
    /// itself, elsewhere on the screen, as a caption's glass button is, the arrow lands out of place.
    @MainActor
    func standIn(at frame: CGRect) -> some View {
        Color.clear
            .frame(width: frame.width, height: frame.height)
            .tipAnchor(self)
            .position(x: frame.midX, y: frame.midY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Where the views the tour's tips point at sit, gathered up to the view that shows each tip, which
/// reads them in its own space for the tip's stand-in.
nonisolated struct TourTargetBounds: PreferenceKey {
    static var defaultValue: [TourAnchor.Target: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [TourAnchor.Target: Anchor<CGRect>], nextValue: () -> [TourAnchor.Target: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Marks this view as what the tour's tip at `target` points at, for the view showing the tip,
    /// around this one, to find through `TourTargetBounds`.
    func tourTarget(_ target: TourAnchor.Target) -> some View {
        anchorPreference(key: TourTargetBounds.self, value: .bounds) { [target: $0] }
    }
}

/// A step of the tour, in the order it goes.
enum TourStep: CaseIterable {
    case addPhotos
    case placePhoto
    case framePhoto
    case changeLayout
    case slideMenu
    case layers
    case selectLayer
    case moveLayer
    case share
}

/// Gathering photos into the tray, where a carousel starts.
nonisolated struct GatherPhotosTip: Tip {
    var title: Text { Text("Gather Photos") }
    var message: Text? {
        Text("Add photos to the tray to look them over before they go on your slides.").foregroundStyle(Color.primary)
    }
    var image: Image? { Image(systemName: "photo.badge.plus") }
    var actions: [Action] { [nextAction()] }
}

/// Putting a tray photo on a slide, with a tap or a drag, and taking one off with a tap.
nonisolated struct PlacePhotoTip: Tip {
    var title: Text { Text("Place a Photo") }
    var message: Text? {
        Text("Tap a photo to put it on a slide, or hold it to see it larger and drag it onto a cell. Tap one already on a slide to take it off.")
            .foregroundStyle(Color.primary)
    }
    var image: Image? { Image(systemName: "plus.square.on.square") }
    var actions: [Action] { [nextAction()] }
}

/// Framing a photo in its cell, which starts with selecting it.
nonisolated struct FramePhotoTip: Tip {
    var title: Text { Text("Frame a Photo") }
    var message: Text? {
        Text("Tap a photo on a slide, then drag or pinch it to frame it in its cell.").foregroundStyle(Color.primary)
    }
    var image: Image? { Image(systemName: "crop") }
    var actions: [Action] { [nextAction()] }
}

/// The layout button under a slide.
nonisolated struct LayoutTip: Tip {
    var title: Text { Text("Change the Layout") }
    var message: Text? {
        Text("Pick how many photos the slide holds and how they sit, or make it a panorama.").foregroundStyle(Color.primary)
    }
    var image: Image? { Image(systemName: "rectangle.split.2x2") }
    var actions: [Action] { [nextAction()] }
}

/// The menu under a slide, with the rest of its choices. Named for the slide's menu, which once
/// held its layout and layers too, since TipKit remembers a tip by its type's name.
nonisolated struct SlideMenuTip: Tip {
    var title: Text { Text("Slide Options") }
    var message: Text? {
        Text("Move the slide, delete it, or set a panorama's width.").foregroundStyle(Color.primary)
    }
    var image: Image? { Image(systemName: "ellipsis.circle") }
    var actions: [Action] { [nextAction()] }
}

/// The layers button under a slide.
nonisolated struct LayersTip: Tip {
    var title: Text { Text("Add Layers") }
    var message: Text? {
        Text("Put text or a picture over the slide, or edit the layers on it.").foregroundStyle(Color.primary)
    }
    var image: Image? { Image(systemName: "square.3.layers.3d") }
    var actions: [Action] { [nextAction()] }
}

/// Selecting a layer, the first thing moving one takes.
nonisolated struct SelectLayerTip: Tip {
    var title: Text { Text("Move a Layer") }
    var message: Text? {
        Text("Tap a layer, like text or a picture, to select it.").foregroundStyle(Color.primary)
    }
    var image: Image? { Image(systemName: "hand.tap") }
    var actions: [Action] { [nextAction()] }
}

/// The gestures a selected layer takes, shown while one is selected to try them on.
nonisolated struct MoveLayerTip: Tip {
    var title: Text { Text("Move, Resize and Turn") }
    var message: Text? {
        Text("Drag, pinch or twist the layer, then tap Done.").foregroundStyle(Color.primary)
    }
    var image: Image? { Image(systemName: "hand.draw") }
    var actions: [Action] { [nextAction()] }
}

/// Exporting, the end of a carousel.
nonisolated struct ShareTip: Tip {
    var title: Text { Text("Share Your Carousel") }
    var message: Text? {
        Text("Save the slides to Photos, or share them to any app that takes several images.").foregroundStyle(Color.primary)
    }
    var image: Image? { Image(systemName: "square.and.arrow.up") }
    var actions: [Action] { [nextAction(title: "Got It")] }
}

extension Tip {
    /// The button that moves the tour on without trying the step, by closing this tip, which
    /// brings on the next.
    nonisolated func nextAction(title: String = "Next") -> Action {
        Action(id: "next", title: title) {
            invalidate(reason: .tipClosed)
        }
    }
}

/// The project screen's tour: a tip for each step, shown one at a time where the screen can take
/// one, on whichever project is open, and remembered by TipKit once finished, so an install takes
/// it once.
@Observable
final class ProjectTour {
    /// Tells this visit's anchors from another window's, which shows the same tip.
    let id = UUID()
    var visit = TourVisit()
    /// Whether anything is open over the screen, which covers the move hint.
    var isPresenting = false
    @ObservationIgnored private let tips = TipGroup(.ordered) {
        GatherPhotosTip()
        PlacePhotoTip()
        FramePhotoTip()
        LayoutTip()
        SlideMenuTip()
        LayersTip()
        SelectLayerTip()
        MoveLayerTip()
        ShareTip()
    }

    /// The step TipKit has on offer, or none once the tour is done.
    var step: TourStep? {
        switch tips.currentTip {
        case is GatherPhotosTip: .addPhotos
        case is PlacePhotoTip: .placePhoto
        case is FramePhotoTip: .framePhoto
        case is LayoutTip: .changeLayout
        case is SlideMenuTip: .slideMenu
        case is LayersTip: .layers
        case is SelectLayerTip: .selectLayer
        case is MoveLayerTip: .moveLayer
        case is ShareTip: .share
        default: nil
        }
    }

    func anchor(_ target: TourAnchor.Target) -> TourAnchor {
        TourAnchor(visit: id, target: target)
    }

    /// The tray's tip, over it: gathering photos into it, or placing one from it.
    var trayTip: (any Tip)? {
        settledTip(.addPhotos) ?? settledTip(.placePhoto)
    }

    /// The tip pointing at a photo to frame, for the slide in front.
    func photoTip(on slideID: UUID) -> (any Tip)? {
        slideID == visit.targets.frontSlideID ? settledTip(.framePhoto) : nil
    }

    /// The tip pointing at one of the buttons under the slide in front, with that button.
    func captionTip(on slideID: UUID) -> (tip: any Tip, target: TourAnchor.Target)? {
        guard slideID == visit.targets.frontSlideID else {
            return nil
        }
        if let tip = settledTip(.changeLayout) {
            return (tip, .layoutButton)
        } else if let tip = settledTip(.slideMenu) {
            return (tip, .optionsButton)
        } else if let tip = settledTip(.layers) {
            return (tip, .layersButton)
        }
        return nil
    }

    /// The tip pointing at a slide's top layer, for the slide in front.
    func layerTip(on slideID: UUID) -> (any Tip)? {
        slideID == visit.targets.frontSlideID ? settledTip(.selectLayer) : nil
    }

    /// The move hint, over the bar of a selected layer.
    func moveTip(isCompactHeight: Bool) -> (any Tip)? {
        TourVisit.offersMoveTip(current: step, isPresenting: isPresenting, isCompactHeight: isCompactHeight) ? tips.currentTip : nil
    }

    var shareTip: (any Tip)? {
        settledTip(.share)
    }

    /// Finishes `step` for good once the user has done what it shows, even ahead of the tour,
    /// which skips it on reaching it.
    func finish(_ step: TourStep) {
        guard TourVisit.finishes(step, at: self.step) else {
            return
        }
        let tip: any Tip = switch step {
        case .addPhotos: GatherPhotosTip()
        case .placePhoto: PlacePhotoTip()
        case .framePhoto: FramePhotoTip()
        case .changeLayout: LayoutTip()
        case .slideMenu: SlideMenuTip()
        case .layers: LayersTip()
        case .selectLayer: SelectLayerTip()
        case .moveLayer: MoveLayerTip()
        case .share: ShareTip()
        }
        tip.invalidate(reason: .actionPerformed)
    }

    /// The current tip, when it's `step`'s, and the screen has settled with something for it.
    private func settledTip(_ step: TourStep) -> (any Tip)? {
        visit.offersSettledTip(step, current: self.step) ? tips.currentTip : nil
    }
}

/// What a visit to a project has done with its tour, apart from TipKit, so its rules test alone.
struct TourVisit {
    /// Whether the screen has rested, with nothing open, waiting, failing or selected, long enough
    /// for a tip that points at the slides, the tray or the toolbar to show.
    var isSettled = false
    /// What the screen had to point at when it settled.
    var targets = TourTargets()
    /// Whether the move hint has shown, which a move then finishes.
    var hasShownMoveTip = false

    /// Whether `step`'s tip, which waits for the screen to settle, shows while the tour is at
    /// `current`.
    func offersSettledTip(_ step: TourStep, current: TourStep?) -> Bool {
        guard step == current, isSettled else {
            return false
        }
        return switch step {
        case .addPhotos: true
        case .placePhoto: targets.hasTrayPhotos
        case .framePhoto: targets.canPointAtPhoto
        case .changeLayout, .slideMenu, .layers: targets.frontSlideID != nil
        case .selectLayer: targets.canPointAtLayer
        case .moveLayer: false
        // The Share button is off without a slide to share.
        case .share: targets.hasSlides
        }
    }

    /// Whether the move hint shows over a selected layer's bar: not under anything open, nor on a
    /// phone in landscape, where it would cover the slide.
    static func offersMoveTip(current: TourStep?, isPresenting: Bool, isCompactHeight: Bool) -> Bool {
        current == .moveLayer && !isPresenting && !isCompactHeight
    }

    /// Whether doing what `step` shows finishes it, with the tour at `current`: always, though the
    /// tour hasn't reached it, so an early tap doesn't skip the tips before it. Selecting a layer
    /// finishes its step only while the tour is there, since the move hint after it shows only
    /// over a layer selected then; ahead of it, the layer tip and the hint follow in their turn.
    static func finishes(_ step: TourStep, at current: TourStep?) -> Bool {
        step != .selectLayer || current == .selectLayer
    }

    /// The step the tour skips on reaching it with nothing to show it on, which would otherwise
    /// hold back the steps after it: the move hint with nothing selected, as when the layer tip
    /// was closed or a visit starts there, placing a photo with an empty tray, as when Gather
    /// Photos was closed, and framing one with none on a slide.
    static func stepSkipped(at current: TourStep?, isLayerSelected: Bool, targets: TourTargets) -> TourStep? {
        switch current {
        case .moveLayer where !isLayerSelected: .moveLayer
        case .placePhoto where !targets.hasTrayPhotos: .placePhoto
        case .framePhoto where !targets.hasPhotoToFrame: .framePhoto
        default: nil
        }
    }
}

/// What the project screen has for the tour's tips to point at, which change as photos and
/// layers come and go, and the strip moves.
nonisolated struct TourTargets: Equatable {
    var frontSlideID: UUID?
    var hasSlides = false
    var hasTrayPhotos = false
    /// Whether the slide in front has a photo for the photo tip to point at, on a slide of its own
    /// rather than a panorama, which runs past the screen's sides, where a tip over it can fall
    /// off screen.
    var canPointAtPhoto = false
    /// Whether any slide has a photo the photo tip could point at, once it's in front.
    var hasPhotoToFrame = false
    /// Whether the slide in front has a layer for the layer tip to point at, on a slide of its own,
    /// as for a photo.
    var canPointAtLayer = false

    init() {}

    /// `frontSlide` is the one in the middle of the strip, or none while it rests on the button
    /// after them.
    init(project: Project, frontSlide: Slide?) {
        frontSlideID = frontSlide?.id
        hasSlides = !project.slides.isEmpty
        hasTrayPhotos = !project.tray.isEmpty
        canPointAtPhoto = frontSlide.map(Self.holdsPhotoToFrame) ?? false
        hasPhotoToFrame = project.slides.contains(where: Self.holdsPhotoToFrame)
        canPointAtLayer = frontSlide.map { !$0.layers.isEmpty && $0.span == 1 } ?? false
    }

    private static func holdsPhotoToFrame(_ slide: Slide) -> Bool {
        slide.span == 1 && slide.cells.contains { $0.image != nil }
    }

    /// A fingertip's square in the middle of the photo the photo tip points at, in `canvas`'s
    /// space: the first whose middle no layer takes, since a tap there would select the layer, or
    /// the first if they all are.
    static func photoTarget(on slide: Slide, canvas: LayerCanvas) -> CGRect? {
        let frames = SlideGeometry.cellFrames(for: slide.layout, in: canvas.size, style: slide.style, span: slide.span)
        let middles = zip(slide.cells, frames)
            .filter { cell, _ in cell.image != nil }
            .map { _, frame in CGPoint(x: frame.midX, y: frame.midY) }
        let untaken = middles.first { middle in
            !slide.layers.contains { LayerGeometry.contains(middle, layer: $0, on: canvas) }
        }
        guard let middle = untaken ?? middles.first else {
            return nil
        }
        let side = LayerGeometry.minimumTarget * canvas.screenPoint
        return CGRect(x: middle.x - side / 2, y: middle.y - side / 2, width: side, height: side)
    }
}

extension EnvironmentValues {
    /// Whether the app configured TipKit, which the tour needs. Snapshots, previews, and the debug
    /// sample and demo stores leave it off.
    @Entry var offersTours = false
}

extension View {
    /// An inline tip of the tour, frosted over the slides. A material rather than glass, which,
    /// drawn around the tip, would leave its arrow out. Its glyph is primary, since an accent one
    /// washes out over a photo.
    func tourTipStyle() -> some View {
        tipBackground(.thinMaterial)
            .tipImageStyle(Color.primary)
    }

    /// A tip along a bar at the screen's foot, inset `inset` from the bar's sides, pointing down at
    /// `target` in the bar's space, with its corners tightened for a button near an edge, as Done
    /// and the tray's add button are.
    func barTipCorners(pointingAt target: CGRect, inBarOf width: CGFloat, inset: CGFloat) -> some View {
        modifier(TipCorners(radius: ShareTipPlacement.cornerRadius(reaching: min(target.midX, width - target.midX) - inset)))
    }
}

/// A tip's corners at `radius`, or TipKit's own.
private struct TipCorners: ViewModifier {
    let radius: CGFloat?

    func body(content: Content) -> some View {
        if let radius {
            content.tipCornerRadius(radius)
        } else {
            content
        }
    }
}
