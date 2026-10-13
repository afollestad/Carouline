//
//  LayerPage.swift
//  Swipeset
//

import SwiftUI

/// What every page of the layers sheet shares: an inline title, the close button, and no list
/// background, so the sheet's glass shows through.
struct LayerPage: ViewModifier {
    let title: String
    /// Closes the whole sheet. A pushed page's own `dismiss` would only go back a page.
    let close: () -> Void

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetCloseItem(action: close)
            }
    }
}

extension View {
    func layerPage(_ title: String, close: @escaping () -> Void) -> some View {
        modifier(LayerPage(title: title, close: close))
    }
}
