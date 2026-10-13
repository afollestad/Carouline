//
//  GlowBackdrop.swift
//  Swipeset
//

import SwiftUI

/// A soft glow of the icon's violets and mint behind a screen, so the glass over it has color to
/// bend and frost rather than flat black or white.
struct GlowBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.55, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: colorScheme == .dark ? Self.dark : Self.light
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// Violet in two corners and mint in a third, dimmed so white text on glass keeps its contrast.
    private static let dark: [Color] = [
        Color(red: 0.23, green: 0.17, blue: 0.48), Color(red: 0.11, green: 0.08, blue: 0.22), Color(red: 0.16, green: 0.12, blue: 0.37),
        Color(red: 0.08, green: 0.06, blue: 0.17), Color(red: 0.06, green: 0.04, blue: 0.12), Color(red: 0.10, green: 0.18, blue: 0.22),
        Color(red: 0.11, green: 0.23, blue: 0.20), Color(red: 0.09, green: 0.07, blue: 0.19), Color(red: 0.23, green: 0.17, blue: 0.50)
    ]

    /// The same corners washed nearly to white, so black text on glass keeps its contrast.
    private static let light: [Color] = [
        Color(red: 0.90, green: 0.86, blue: 0.99), Color(red: 0.95, green: 0.94, blue: 0.99), Color(red: 0.93, green: 0.90, blue: 0.99),
        Color(red: 0.96, green: 0.95, blue: 1.00), Color(red: 0.98, green: 0.97, blue: 1.00), Color(red: 0.91, green: 0.97, blue: 0.94),
        Color(red: 0.87, green: 0.97, blue: 0.92), Color(red: 0.95, green: 0.93, blue: 0.99), Color(red: 0.89, green: 0.85, blue: 0.98)
    ]
}

#Preview {
    GlowBackdrop()
}
