//
//  LayerPage.swift
//  Swipeset
//

import SwiftUI

/// What every page of the layers sheet shares: an inline title, the close button, and no list
/// background, so the sheet's glass shows through, except at full height, where the sheet is
/// opaque and its rows would be lost on it.
struct LayerPage: ViewModifier {
    let title: String
    /// Closes the whole sheet. A pushed page's own `dismiss` would only go back a page.
    let close: () -> Void
    @Environment(\.isLayersSheetFull) private var isFull

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(isFull ? .visible : .hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetCloseItem(action: close)
            }
    }
}

extension EnvironmentValues {
    /// Whether the layers sheet is at full height, where it's opaque rather than glass.
    @Entry var isLayersSheetFull = false
}

extension View {
    func layerPage(_ title: String, close: @escaping () -> Void) -> some View {
        modifier(LayerPage(title: title, close: close))
    }
}
