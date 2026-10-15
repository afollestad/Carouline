//
//  ProjectTour.swift
//  Carouline
//

import SwiftUI
import TipKit

/// Views an inline tip of the tour points at from elsewhere on the screen.
nonisolated enum TourAnchor: Hashable {
    case layer
    case share
}

/// A step of the sample project's tour, in the order it goes.
enum TourStep: Int, CaseIterable {
    case slideMenu
    case selectLayer
    case moveLayer
    case share
}

/// The slide menu's choices: a slide's layout, and its layers.
nonisolated struct SlideMenuTip: Tip {
    var title: Text { Text("Slide Options") }
    var message: Text? {
        Text("Change a slide's layout, or add and edit its layers, from the menu under it.").foregroundStyle(Color.primary)
    }
    var image: Image? { Image(systemName: "ellipsis.circle") }
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

/// The sample project's tour: a tip for each step, shown one at a time and remembered by TipKit
/// once finished, where the screen can take one.
@Observable
final class ProjectTour {
    var visit = TourVisit()
    /// Whether anything is open over the screen, which covers the move hint.
    var isPresenting = false
    @ObservationIgnored private let tips = TipGroup(.ordered) {
        SlideMenuTip()
        SelectLayerTip()
        MoveLayerTip()
        ShareTip()
    }

    /// The step TipKit has on offer, or none once the tour is done.
    var step: TourStep? {
        switch tips.currentTip {
        case is SlideMenuTip: .slideMenu
        case is SelectLayerTip: .selectLayer
        case is MoveLayerTip: .moveLayer
        case is ShareTip: .share
        default: nil
        }
    }

    /// The slide menu's tip, for the slide in front.
    func menuTip(on slideID: UUID) -> (any Tip)? {
        slideID == visit.frontSlideID && visit.offersSettledTip(.slideMenu, current: step) ? tips.currentTip : nil
    }

    /// The tip pointing at a slide's top layer, for the slide in front.
    func layerTip(on slideID: UUID) -> (any Tip)? {
        slideID == visit.frontSlideID && visit.offersSettledTip(.selectLayer, current: step) ? tips.currentTip : nil
    }

    /// The move hint, over the bar of a selected layer.
    func moveTip(isCompactHeight: Bool) -> (any Tip)? {
        TourVisit.offersMoveTip(current: step, isPresenting: isPresenting, isCompactHeight: isCompactHeight) ? tips.currentTip : nil
    }

    var shareTip: (any Tip)? {
        visit.offersSettledTip(.share, current: step) ? tips.currentTip : nil
    }

    /// Finishes `step` for good, and the steps before it, which whatever finished it has moved
    /// past.
    func finish(through step: TourStep) {
        for finished in TourVisit.steps(through: step) {
            let tip: any Tip = switch finished {
            case .slideMenu: SlideMenuTip()
            case .selectLayer: SelectLayerTip()
            case .moveLayer: MoveLayerTip()
            case .share: ShareTip()
            }
            tip.invalidate(reason: .actionPerformed)
        }
    }
}

/// What a visit to the sample has done with its tour, apart from TipKit, so its rules test alone.
struct TourVisit {
    /// Whether the screen has rested, with nothing open, waiting, failing or selected, long enough
    /// for a tip that points at the slides or the toolbar to show.
    var isSettled = false
    var frontSlideID: UUID?
    /// Whether the slide in front has a layer for the layer tip to point at, on a slide of its own
    /// rather than a panorama, whose card runs past the screen.
    var canPointAtLayer = false
    /// Whether the move hint has shown, which a move then finishes.
    var hasShownMoveTip = false

    /// Whether `step`'s tip, which waits for the screen to settle, shows while the tour is at
    /// `current`.
    func offersSettledTip(_ step: TourStep, current: TourStep?) -> Bool {
        guard step == current, isSettled else {
            return false
        }
        return switch step {
        case .slideMenu, .share: true
        case .selectLayer: canPointAtLayer
        case .moveLayer: false
        }
    }

    /// Whether the move hint shows over a selected layer's bar: not under anything open, nor on a
    /// phone in landscape, where it would cover the slide.
    static func offersMoveTip(current: TourStep?, isPresenting: Bool, isCompactHeight: Bool) -> Bool {
        current == .moveLayer && !isPresenting && !isCompactHeight
    }

    /// `step` and the steps before it.
    static func steps(through step: TourStep) -> [TourStep] {
        TourStep.allCases.filter { $0.rawValue <= step.rawValue }
    }

    /// The step the tour skips on reaching it: the move hint, when nothing's selected, as when
    /// the layer tip was closed or a visit starts there. It shows only over a selected layer, and
    /// would otherwise hold back the Share tip until the user selects one again.
    static func stepSkipped(at current: TourStep?, isLayerSelected: Bool) -> TourStep? {
        current == .moveLayer && !isLayerSelected ? .moveLayer : nil
    }
}

extension EnvironmentValues {
    /// Whether the app configured TipKit, which tours need. Snapshots and previews leave it off.
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
}
