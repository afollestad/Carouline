//
//  SlidePlaceholder.swift
//  Carouline
//

import SwiftUI

/// What a card shows in place of its photos and layers while away from the strip's middle,
/// holding the slide's shape until it comes near and builds them, so a project's photos never all
/// decode at once.
struct SlidePlaceholder: View {
    let size: CGSize
    let background: RGBColor

    var body: some View {
        Rectangle()
            .fill(background.color)
            .frame(width: size.width, height: size.height)
    }
}

#Preview {
    SlidePlaceholder(size: CGSize(width: 240, height: 300), background: .white)
        .padding()
        .background(.gray)
}
