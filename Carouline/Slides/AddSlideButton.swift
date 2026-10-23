//
//  AddSlideButton.swift
//  Carouline
//

import SwiftUI

/// The glass button after the strip's last slide, which adds another.
struct AddSlideButton: View {
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Add Slide", systemImage: "plus")
                .labelStyle(.iconOnly)
                .font(.title2.weight(.semibold))
                .frame(width: size - 16, height: size - 16)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityHint("Choose a layout for a new slide")
        // Exactly `size` across, which the strip's snapping counts on to center it.
        .frame(width: size, height: size)
    }
}

#Preview {
    AddSlideButton(size: 56) {}
        .padding()
        .background { GlowBackdrop() }
}
