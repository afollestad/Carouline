//
//  LayerPage.swift
//  Carouline
//

import SwiftUI

/// What every page of the layers sheet shares: an inline title with a soft edge under it, the
/// close button, content a margin below the title bar's buttons, as far as it's in from the sides,
/// and no list background, so the sheet's glass shows through, except at full height, where the
/// sheet is opaque and its rows would be lost on it.
struct LayerPage: ViewModifier {
    let title: String
    /// Closes the whole sheet. A pushed page's own `dismiss` would only go back a page.
    let close: () -> Void
    @Environment(\.isLayersSheetFull) private var isFull
    @Environment(\.layersSheetMargin) private var margin

    func body(content: Content) -> some View {
        content
            // In place of a list's own top margin, which leaves the first section well over twice
            // as far below the buttons.
            .contentMargins(.top, SheetHeight.topGap(margin: margin) - SheetHeight.titleBarBelowButtons, for: .scrollContent)
            .scrollContentBackground(isFull ? .visible : .hidden)
            // Fades what scrolls under the title, such as the text field as its typefaces are
            // scrolled to. The default cuts it off at a solid band with a hairline.
            .scrollEdgeEffectStyle(.soft, for: .top)
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
    /// The layers sheet's layout margin, which its lists inset their sections by, and its pages'
    /// other content follows.
    @Entry var layersSheetMargin: CGFloat = 16
}

extension View {
    func layerPage(_ title: String, close: @escaping () -> Void) -> some View {
        modifier(LayerPage(title: title, close: close))
    }
}
