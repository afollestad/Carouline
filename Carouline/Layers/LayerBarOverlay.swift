//
//  LayerBarOverlay.swift
//  Carouline
//

import SwiftUI
import TipKit

/// The layer bar along the bottom of the project screen while a layer is selected, and what
/// keeps the selection to a layer that's still there.
struct LayerBarOverlay: ViewModifier {
    let project: Project
    let session: LayerSession
    let actions: LayerActions
    /// Saves the size slider's placement once it's let go.
    let onCommitSize: () -> Void
    let onDone: () -> Void
    @Environment(ProjectTour.self) private var tour: ProjectTour?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                bar
            }
            .animation(.smooth(duration: 0.25), value: session.selection)
            .sensoryFeedback(.selection, trigger: session.selection) { _, selection in
                selection != nil
            }
            // A selected layer deleted, here or with its slide, leaves nothing to move, and
            // nothing to bring the strip's scrolling back; nor does one selected that isn't there.
            .onChange(of: selectedLayer == nil, initial: true) { _, isGone in
                if isGone, session.selection != nil {
                    session.livePlacement = nil
                    session.selection = nil
                }
            }
            // A move, resize or turn of the layer the hint showed over, saved as it ends, finishes
            // the hint. Another layer selected, or none, isn't a move.
            .onChange(of: selectedPlacement) { old, new in
                if let old, let new, old.layerID == new.layerID, old != new, tour?.visit.hasShownMoveTip == true {
                    tour?.finish(.moveLayer)
                }
            }
    }

    /// The selected layer's placement as saved, with its ID.
    private struct SelectedPlacement: Equatable {
        let layerID: UUID
        let placement: LayerPlacement
    }

    private var selectedPlacement: SelectedPlacement? {
        selectedLayer.map { SelectedPlacement(layerID: $0.layer.id, placement: $0.layer.placement) }
    }

    @ViewBuilder
    private var bar: some View {
        if let selection = session.selection, let selected = selectedLayer {
            layerBar(selection: selection, selected: selected, layer: selected.layer)
                .overlayPreferenceValue(TourTargetBounds.self) { targets in
                    moveTip(at: targets)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// The move hint, above the bar, pointing down at Done, which it ends on, rather than the bar's
    /// middle, its size slider.
    @ViewBuilder
    private func moveTip(at targets: [TourAnchor.Target: Anchor<CGRect>]) -> some View {
        if let tour, let tip = tour.moveTip(isCompactHeight: verticalSizeClass == .compact), let bounds = targets[.layerDone] {
            GeometryReader { proxy in
                let anchor = tour.anchor(.layerDone)
                ZStack(alignment: .bottom) {
                    anchor.standIn(at: proxy[bounds])
                    TipView(tip, arrowEdge: .bottom, anchorID: anchor)
                        .tourTipStyle()
                        .barTipCorners(pointingAt: proxy[bounds], inBarOf: proxy.size.width, inset: 16)
                        .padding(.horizontal, 16)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, proxy.size.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .onAppear {
                            tour.visit.hasShownMoveTip = true
                        }
                }
                // Growing up from the bar, with its stand-in still over Done.
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            }
            // Sized with the bar, so it leaves the slide above as much room.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
    }

    private func layerBar(selection: LayerAddress, selected: SelectedLayer, layer: Layer) -> some View {
        LayerBar(
            layer: layer,
            session: session,
            isTop: selected.index == selected.count - 1,
            isBottom: selected.index == 0,
            onBringForward: { actions.move(selection, 1) },
            onSendBackward: { actions.move(selection, -1) },
            onStraighten: {
                var placement = session.livePlacement ?? layer.placement
                placement.rotation = 0
                session.livePlacement = nil
                actions.setPlacement(placement, selection)
            },
            onDelete: { actions.delete(selection) },
            onCommitSize: onCommitSize,
            onEdit: { actions.edit(selection) },
            onDone: onDone
        )
    }

    /// The selected layer, its place in its slide's stack, and the stack's height. A new
    /// layer's draft, which the library doesn't have yet, sits on top.
    private struct SelectedLayer {
        let layer: Layer
        let index: Int
        let count: Int
    }

    private var selectedLayer: SelectedLayer? {
        guard let selection = session.selection,
              let slide = project.slides.first(where: { $0.id == selection.slideID }) else {
            return nil
        }
        if let index = slide.layers.firstIndex(where: { $0.id == selection.layerID }) {
            return SelectedLayer(layer: slide.layers[index], index: index, count: slide.layers.count)
        }
        guard session.isDraftNew, let draft = session.draftLayer(selection.layerID) else {
            return nil
        }
        return SelectedLayer(layer: draft, index: slide.layers.count, count: slide.layers.count + 1)
    }
}
