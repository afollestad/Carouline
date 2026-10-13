//
//  AddLayerPage.swift
//  Swipeset
//

import SwiftUI

/// The layers sheet's page for picking a kind of layer to add.
struct AddLayerPage: View {
    let library: ProjectLibrary
    let slideID: UUID
    let onAdd: (LayerKind) -> Void
    let close: () -> Void

    var body: some View {
        ScrollView {
            // Read here, so the page follows a picture on its way onto the slide.
            LayerKindTiles(isAddingImage: library.importingLayers[slideID] != nil, onAdd: onAdd)
                .padding()
        }
        .layerPage("Add Layer", close: close)
    }
}

/// A tile for each kind of layer to add, side by side, as the add page and an empty layer list
/// both offer them.
struct LayerKindTiles: View {
    var isAddingImage = false
    let onAdd: (LayerKind) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(LayerKind.allCases, id: \.self) { kind in
                LayerKindTile(kind: kind, isAdding: kind == .image && isAddingImage) {
                    onAdd(kind)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddLayerPage(library: ProjectLibrary(store: MockProjectStore(), projects: []), slideID: UUID(), onAdd: { _ in }, close: {})
    }
    .tint(.accentColor)
}
