//
//  AddLayerPage.swift
//  Swipeset
//

import SwiftUI

/// The layers sheet's page for picking a kind of layer to add.
struct AddLayerPage: View {
    let kinds: [LayerKind]
    let onAdd: (LayerKind) -> Void
    let close: () -> Void

    var body: some View {
        ScrollView {
            LayerKindTiles(kinds: kinds, onAdd: onAdd)
                .padding()
        }
        .layerPage("Add Layer", close: close)
    }
}

/// A tile for each kind of layer to add, side by side, as the add page and an empty layer list
/// both offer them.
struct LayerKindTiles: View {
    let kinds: [LayerKind]
    let onAdd: (LayerKind) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(kinds, id: \.self) { kind in
                LayerKindTile(kind: kind) {
                    onAdd(kind)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddLayerPage(kinds: LayerKind.allCases, onAdd: { _ in }, close: {})
    }
    .tint(.accentColor)
}
