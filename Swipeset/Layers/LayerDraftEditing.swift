//
//  LayerDraftEditing.swift
//  Swipeset
//

import SwiftUI

/// What every layer editor shares: it edits the session's draft of its layer, which the slide
/// draws as it changes, begun as its page appears and saved once as the page goes, and its page
/// leaves the sheet once the layer is deleted.
struct LayerDraftEditing: ViewModifier {
    /// The editor's page in the layers sheet.
    let page: LayersPage
    let address: LayerAddress
    let library: ProjectLibrary
    let session: LayerSession
    /// Ends anything else of the editor's own as its page goes, before the draft is saved.
    var onLeave: () -> Void = {}

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Another layer's editor may not have gone yet, and SwiftUI doesn't order the two.
                if session.draftLayerID != address.layerID {
                    session.saveDraft(to: library, projectID: address.projectID)
                }
                if let layer = library.layer(at: address) {
                    session.beginDraft(of: layer, on: address.slideID)
                }
            }
            .onDisappear {
                // Not while its page is back in the path, as after switching away and straight
                // back, where the new page for the layer has begun editing it already. Closing the
                // sheet leaves the path be, and the sheet saves then.
                guard !session.sheetPath.contains(page) else {
                    return
                }
                onLeave()
                // Only its own draft: the next layer's editor may have begun its own already.
                if session.draftLayerID == address.layerID {
                    session.saveDraft(to: library, projectID: address.projectID)
                }
            }
            // A layer deleted while its editor is open, from the slide or with it, leaves nothing
            // to edit. Only its own page goes, since the path may already be on to another's.
            .onChange(of: isGone, initial: true) { _, isGone in
                if isGone {
                    session.sheetPath.removeAll { $0 == page }
                }
            }
    }

    /// Whether the layer is in neither the library nor, while it's new, the draft.
    private var isGone: Bool {
        library.layer(at: address) == nil && !(session.isDraftNew && session.draftLayerID == address.layerID)
    }
}
