//
//  ProjectTourHost.swift
//  Carouline
//

import SwiftUI
import TipKit

/// Runs the sample project's tour on its screen: makes the tour on a visit to the sample, tells it
/// when the screen has settled, finishes the steps the user's own actions cover, hands it to the
/// slides and the layer bar through the environment, and shows the Share tip under the toolbar.
struct ProjectTourHost: ViewModifier {
    let project: Project
    let stripPosition: StripItem?
    let presenter: PresentationQueue<ProjectPresentation>
    let photoSelection: CellAddress?
    let layerSelection: LayerAddress?
    /// Whether an alert is up, which the tips wait out.
    let isFailing: Bool
    @State private var tour: ProjectTour?
    @Environment(\.offersTours) private var offersTours

    /// How long the screen rests before a tip that waits for it shows, so one doesn't flash on
    /// each slide a scroll passes, nor in the moment `PresentationQueue` clears what's open before
    /// opening what it held back.
    private static let settleDelay = Duration.milliseconds(600)
    /// The width of a toolbar's glass button, and its trailing button's inset from the screen's
    /// edge, which the Share tip's stand-in matches.
    private static let toolbarButtonSize: CGFloat = 44
    private static let toolbarInset: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let shareTip = tour?.shareTip {
                    shareTipView(shareTip)
                }
            }
            .environment(tour)
            .task {
                // Once a visit, though a cover over the screen, as the camera's, appears it again.
                if tour == nil, offersTours, project.id == SampleProjects.firstLaunchID {
                    tour = ProjectTour()
                }
            }
            .task(id: gate) {
                await settle(gate)
            }
            .onChange(of: presenter.current) { _, current in
                if current == .export {
                    tour?.finish(through: .share)
                }
            }
            .onChange(of: layerSelection) { old, new in
                finishLayerSteps(from: old, to: new)
            }
            .onChange(of: tour?.step) { _, step in
                if let step = TourVisit.stepSkipped(at: step, isLayerSelected: layerSelection != nil) {
                    tour?.finish(through: step)
                }
            }
    }

    /// The Share tip, under the toolbar, pointing up at the Share button. TipKit shows no popover
    /// from a toolbar item, and can't point at one, which measures outside the screen's space, so
    /// the tip points at a stand-in where the bar's trailing button sits.
    private func shareTipView(_ tip: any Tip) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(width: Self.toolbarButtonSize, height: 1)
                .tipAnchor(TourAnchor.share)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, Self.toolbarInset)
            // Against the trailing edge, so the arrow reaches the button over a wide screen.
            TipView(tip, arrowEdge: .top, anchorID: TourAnchor.share)
                .tourTipStyle()
                .padding(.horizontal, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// What the screen must hold still with for the tour to settle.
    private struct Gate: Equatable {
        let hasTour: Bool
        let isPresenting: Bool
        let isIdle: Bool
        let frontSlideID: UUID?
    }

    private var gate: Gate {
        let isPresenting = presenter.current != nil || presenter.pending != nil
        return Gate(
            hasTour: tour != nil,
            isPresenting: isPresenting,
            isIdle: !isPresenting && !isFailing && photoSelection == nil && layerSelection == nil,
            frontSlideID: frontSlide?.id
        )
    }

    /// The slide in the middle of the strip, or none while it rests on the button after them.
    private var frontSlide: Slide? {
        switch stripPosition {
        case .slide(let slideID): project.slides.first { $0.id == slideID } ?? project.slides.first
        case .add: nil
        case nil: project.slides.first
        }
    }

    /// Hides the tips that wait for the screen at once for any change, and offers them again once
    /// it has rested idle with a slide in front, pointing at the slide then in front.
    private func settle(_ gate: Gate) async {
        guard let tour else {
            return
        }
        tour.isPresenting = gate.isPresenting
        tour.visit.isSettled = false
        guard gate.isIdle, let frontSlide else {
            return
        }
        try? await Task.sleep(for: Self.settleDelay)
        guard !Task.isCancelled else {
            return
        }
        tour.visit.frontSlideID = frontSlide.id
        tour.visit.canPointAtLayer = !frontSlide.layers.isEmpty && frontSlide.span == 1
        tour.visit.isSettled = true
    }

    /// Finishes selecting a layer once one is selected on the strip, and the move hint once the
    /// selection ends, on Done, a tap beside the slides, or a photo's selection. The hint shows
    /// only over a selected layer, so waiting for another would hold back the Share tip, as on a
    /// phone in landscape, where the hint never shows.
    private func finishLayerSteps(from old: LayerAddress?, to new: LayerAddress?) {
        guard let tour, !gate.isPresenting else {
            return
        }
        if old == nil, new != nil {
            tour.finish(through: .selectLayer)
        } else if old != nil, new == nil, tour.step == .moveLayer {
            tour.finish(through: .moveLayer)
        }
    }
}
