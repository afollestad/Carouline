//
//  ProjectTourHost.swift
//  Carouline
//

import SwiftUI
import TipKit

/// Runs the sample project's tour on its screen: makes the tour on a visit to the sample, tells it
/// when the screen has settled, finishes the steps the user's own actions cover, hands it to the
/// slides and the layer bar through the environment, and shows the Share tip by the Share button.
struct ProjectTourHost: ViewModifier {
    let project: Project
    let stripPosition: StripItem?
    let presenter: PresentationQueue<ProjectPresentation>
    let photoSelection: CellAddress?
    let layerSelection: LayerAddress?
    /// Whether an alert is up, which the tips wait out.
    let isFailing: Bool
    @State private var tour: ProjectTour?
    /// Where the Share button sits in the screen's space, which the Share tip points at, read
    /// afresh each time the tip is offered.
    @State private var shareFrame: CGRect?
    @Environment(\.offersTours) private var offersTours

    /// How long the screen rests before a tip that waits for it shows, so one doesn't flash on
    /// each slide a scroll passes, nor in the moment `PresentationQueue` clears what's open before
    /// opening what it held back.
    private static let settleDelay = Duration.milliseconds(600)

    func body(content: Content) -> some View {
        content
            .overlay {
                if let shareTip = tour?.shareTip, let shareFrame {
                    GeometryReader { proxy in
                        shareTipView(shareTip, pointingAt: shareFrame, in: proxy.size)
                    }
                }
            }
            .background {
                // Only while the tip is offered, once the screen has settled, since the button grows
                // in as the screen appears.
                if tour?.shareTip != nil {
                    ShareButtonReader { shareFrame = $0 }
                        .onDisappear { shareFrame = nil }
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

    /// The Share tip, pointing at the Share button at `button`, in the screen's space, wherever its
    /// bar puts it. TipKit shows no popover from a toolbar item, and can't point at one, which
    /// measures outside the screen's space, so the tip points at a stand-in over the button.
    private func shareTipView(_ tip: any Tip, pointingAt button: CGRect, in size: CGSize) -> some View {
        let placement = ShareTipPlacement(button: button, in: size)
        return ZStack {
            Color.clear
                .frame(width: button.width, height: button.height)
                .tipAnchor(TourAnchor.share)
                .position(x: button.midX, y: button.midY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            TipView(tip, arrowEdge: placement.arrowEdge, anchorID: TourAnchor.share)
                .tourTipStyle()
                .padding(placement.padding)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: placement.alignment)
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

/// Reads where the Share button sits, in its own space, which is the screen's. SwiftUI makes a
/// toolbar item a UIKit bar item, measures it in a space of its own and hosts no representable in
/// it, so the frame comes from the bar item: Share, the bar's only trailing item, on the navigation
/// item of the screen's controller.
private struct ShareButtonReader: UIViewRepresentable {
    let onChange: (CGRect?) -> Void

    func makeUIView(context: Context) -> ReaderView {
        ReaderView(onChange: onChange)
    }

    func updateUIView(_ view: ReaderView, context: Context) {
        view.onChange = onChange
    }

    final class ReaderView: UIView {
        var onChange: (CGRect?) -> Void
        private var reported: CGRect?

        init(onChange: @escaping (CGRect?) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        // A turn or a resize, which moves the bar's items too.
        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        /// Reports the button's frame after this layout pass, by when the bar has laid out too.
        private func report() {
            DispatchQueue.main.async { [weak self] in
                guard let self, window != nil else {
                    return
                }
                let frame = shareItem?.frame(in: self)
                guard frame != reported else {
                    return
                }
                reported = frame
                onChange(frame)
            }
        }

        private var shareItem: UIBarButtonItem? {
            var responder = next
            while let current = responder {
                if let item = (current as? UIViewController)?.navigationItem.trailingItemGroups.first?.barButtonItems.first {
                    return item
                }
                responder = current.next
            }
            return nil
        }
    }
}
