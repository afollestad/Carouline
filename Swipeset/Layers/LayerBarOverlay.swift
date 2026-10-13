//
//  LayerBarOverlay.swift
//  Swipeset
//

import SwiftUI

/// The layer bar along the bottom of the project screen while a layer is selected, and what
/// keeps the selection to a layer that's still there.
struct LayerBarOverlay: ViewModifier {
    /// The project as the strip draws it.
    let project: Project
    let session: LayerSession
    let actions: LayerActions
    /// Saves the size slider's placement once it's let go.
    let onCommitSize: () -> Void
    let onDone: () -> Void

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
    }

    @ViewBuilder
    private var bar: some View {
        if let selection = session.selection, let selected = selectedLayer {
            let layer = selected.layer
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
                onEdit: LayerActions.canEdit(layer) ? { actions.edit(selection) } : nil,
                onDone: onDone
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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
