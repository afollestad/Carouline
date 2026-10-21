//
//  ProjectTourHost.swift
//  Carouline
//

import SwiftUI
import TipKit

/// Runs the tour on a project's screen: makes the tour on a visit, tells it when the screen has
/// settled and what's on it, finishes the steps the user's own actions cover, hands it to the
/// slides, the tray and the layer bar through the environment, and shows the Share tip by the Share
/// button.
struct ProjectTourHost: ViewModifier {
    let project: Project
    let stripPosition: StripItem?
    let presenter: PresentationQueue<ProjectPresentation>
    let photoSelection: CellAddress?
    let layerSelection: LayerAddress?
    /// Whether a photo is held to place, which the tips wait out, as they do a selection.
    let isHoldingPhoto: Bool
    /// Whether photos are on their way into the tray, which the tips wait out, so the tray's tip
    /// doesn't show again between the picker closing and the first photo landing.
    let isImportingToTray: Bool
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
        let hosted = content
            .overlay {
                if let tour, let shareTip = tour.shareTip, let shareFrame {
                    GeometryReader { proxy in
                        shareTipView(shareTip, anchor: tour.anchor(.share), pointingAt: shareFrame, in: proxy.size)
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
                if tour == nil, offersTours {
                    tour = ProjectTour()
                }
            }
            .task(id: gate) {
                await settle(gate)
            }
        return finishingSteps(on: hosted)
    }

    /// Finishes the steps the user's own actions cover, and skips those the tour reaches with
    /// nothing to show them on.
    private func finishingSteps(on view: some View) -> some View {
        view
            .onChange(of: presenter.current) { _, current in
                if current == .export {
                    tour?.finish(.share)
                }
            }
            .onChange(of: project.tray.count) { old, new in
                if new > old {
                    tour?.finish(.addPhotos)
                }
            }
            .onChange(of: trayPlacements) { old, new in
                if new.contains(where: { photoID, count in count > old[photoID, default: 0] }) {
                    tour?.finish(.addPhotos)
                    tour?.finish(.placePhoto)
                }
            }
            .onChange(of: photoSelection) { old, new in
                if old == nil, new != nil, !gate.isPresenting {
                    tour?.finish(.framePhoto)
                }
            }
            .onChange(of: layerSelection) { old, new in
                finishLayerSteps(from: old, to: new)
            }
            .onChange(of: tour?.step) { _, step in
                let targets = TourTargets(project: project, frontSlide: frontSlide)
                if let step = TourVisit.stepSkipped(at: step, isLayerSelected: layerSelection != nil, targets: targets) {
                    tour?.finish(step)
                }
            }
    }

    /// The Share tip, pointing at the Share button at `button`, in the screen's space, wherever its
    /// bar puts it. TipKit shows no popover from a toolbar item, and can't point at one, which
    /// measures outside the screen's space, so the tip points at a stand-in over the button.
    private func shareTipView(_ tip: any Tip, anchor: TourAnchor, pointingAt button: CGRect, in size: CGSize) -> some View {
        let placement = ShareTipPlacement(button: button, in: size)
        let tipView = TipView(tip, arrowEdge: placement.arrowEdge, anchorID: anchor)
            .tourTipStyle()
            // As the tour's other tips are, so one beside a bar down the screen's side, which
            // starts level with the button, still fits below it.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        return ZStack {
            Color.clear
                .frame(width: button.width, height: button.height)
                .tipAnchor(anchor)
                .position(x: button.midX, y: button.midY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            Group {
                if let cornerRadius = placement.cornerRadius {
                    tipView.tipCornerRadius(cornerRadius)
                } else {
                    tipView
                }
            }
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
        /// What the tips point at, which shows them afresh as it changes, as when a tray photo
        /// lands on a slide with nothing opening.
        let targets: TourTargets
    }

    private var gate: Gate {
        let isPresenting = presenter.current != nil || presenter.pending != nil
        return Gate(
            hasTour: tour != nil,
            isPresenting: isPresenting,
            isIdle: !isPresenting && !isFailing && photoSelection == nil && layerSelection == nil && !isHoldingPhoto
                && !isImportingToTray,
            targets: TourTargets(project: project, frontSlide: frontSlide)
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

    /// How many cells hold a photo from each tray photo, which grows as one is placed. Counted
    /// rather than told apart by the cells' image IDs, since a photo restored on sight takes a new
    /// ID in the same cell, and a move or a swap keeps every count.
    private var trayPlacements: [UUID: Int] {
        project.slides.flatMap(\.cells).compactMap(\.image?.trayPhotoID).reduce(into: [:]) { counts, photoID in
            counts[photoID, default: 0] += 1
        }
    }

    /// Hides the tips that wait for the screen at once for any change, and offers them again once
    /// it has rested idle, pointing at what's then on it.
    private func settle(_ gate: Gate) async {
        guard let tour else {
            return
        }
        tour.isPresenting = gate.isPresenting
        tour.visit.isSettled = false
        guard gate.isIdle else {
            return
        }
        try? await Task.sleep(for: Self.settleDelay)
        guard !Task.isCancelled else {
            return
        }
        tour.visit.targets = gate.targets
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
            tour.finish(.selectLayer)
        } else if old != nil, new == nil, tour.step == .moveLayer {
            tour.finish(.moveLayer)
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
