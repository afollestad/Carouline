//
//  GhostSlide.swift
//  Carouline
//

import SwiftUI

/// Where the first slide will go, in the project's shape.
struct GhostSlide: View {
    let size: CGSize
    /// Whether the tray below has photos to start a slide with.
    let hasTrayPhotos: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .frame(width: size.width, height: size.height)
                .overlay {
                    Button(action: onAdd) {
                        Label("Add Slide", systemImage: "plus")
                            .labelStyle(.iconOnly)
                            .font(.title.weight(.semibold))
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .accessibilityHint("Choose a layout for the first slide")
                }
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: size.width)
        }
        .padding(.bottom, 40)
    }

    private var caption: String {
        if hasTrayPhotos {
            "Add a slide, or tap a photo below to start one with it."
        } else {
            "Add a slide to start your carousel, or gather photos below first."
        }
    }
}

#Preview {
    GhostSlide(size: CGSize(width: 300, height: 375), hasTrayPhotos: true, onAdd: {})
        .background { GlowBackdrop() }
}
