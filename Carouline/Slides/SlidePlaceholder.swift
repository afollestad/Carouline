//
//  SlidePlaceholder.swift
//  Carouline
//

import SwiftUI

/// A slide away from the middle of the strip, holding its place and shape until it comes near and
/// its card builds its photos and layers, so a project's photos never all decode at once.
struct SlidePlaceholder: View {
    let size: CGSize
    let background: RGBColor
    /// What VoiceOver calls the slide, as its card does, so it can still be found and scrolled to.
    let label: String

    var body: some View {
        Rectangle()
            .fill(background.color)
            .frame(width: size.width, height: size.height)
            .accessibilityElement()
            .accessibilityLabel(label)
    }
}

#Preview {
    SlidePlaceholder(size: CGSize(width: 240, height: 300), background: .white, label: "Slide 3 of 8, Grid of Four")
        .padding()
        .background(.gray)
}
