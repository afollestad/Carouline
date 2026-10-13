//
//  LoadingPulse.swift
//  Swipeset
//

import SwiftUI

extension View {
    /// Fades the view in and out while what it stands in for loads, as a skeleton's shapes do.
    func loadingPulse() -> some View {
        modifier(LoadingPulse())
    }
}

/// A slow fade between full and part opacity, held still at full under Reduce Motion. Started
/// with an explicit animation, which a `transaction` that drops animations holds still too, as
/// snapshots need.
private struct LoadingPulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    @State private var isDimmed = false

    /// Slow enough to read as waiting rather than as something wanting attention.
    private static let halfCycle: TimeInterval = 0.9
    /// Faint enough that the shapes stay in place to read, without blinking out.
    private static let dimmedOpacity = 0.4

    func body(content: Content) -> some View {
        content
            .opacity(isDimmed ? Self.dimmedOpacity : 1)
            .onAppear(perform: pulse)
            .onChange(of: reducesMotion, pulse)
    }

    private func pulse() {
        if reducesMotion {
            // Set without an animation, which stops the repeating one.
            isDimmed = false
        } else {
            withAnimation(.easeInOut(duration: Self.halfCycle).repeatForever()) {
                isDimmed = true
            }
        }
    }
}

#Preview {
    RoundedRectangle(cornerRadius: 8)
        .fill(.fill.tertiary)
        .frame(width: 200, height: 250)
        .loadingPulse()
}
