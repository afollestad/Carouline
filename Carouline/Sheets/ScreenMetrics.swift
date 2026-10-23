//
//  ScreenMetrics.swift
//  Carouline
//

import SwiftUI

/// The window's size and width class, read at its root, which a confirmation popover sizes itself
/// by as the system's dialog does. A popover's own width class is compact, even on an iPad.
nonisolated struct ScreenMetrics: Equatable, Sendable {
    /// The window's size, past its safe area, or zero until measured.
    var size: CGSize = .zero
    var isRegularWidth = false

    /// The system dialog's width on a phone, measured, which its title and note wrap within.
    static let compactWidth: CGFloat = 240
    /// The system dialog's width on a wide screen, as an iPad's, measured, at every text size.
    static let regularWidth: CGFloat = 288
    /// How far in from a phone's sides the system dialog keeps as it widens at accessibility sizes,
    /// measured: 366 of an iPhone 18 Pro's 402 points.
    static let widenedInset: CGFloat = 18

    /// The width a confirmation popover takes at `dynamicTypeSize`, as the system's dialog does: a
    /// phone's, widened nearly to the screen's shorter side at accessibility sizes, so a phone held
    /// sideways keeps its upright width, or a wide screen's at any size.
    func confirmationWidth(at dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        if isRegularWidth {
            return Self.regularWidth
        }
        guard dynamicTypeSize.isAccessibilitySize else {
            return Self.compactWidth
        }
        return max(Self.compactWidth, min(size.width, size.height) - 2 * Self.widenedInset)
    }
}

extension EnvironmentValues {
    /// The window's metrics, set at its root.
    @Entry var screenMetrics = ScreenMetrics()
    /// The screen's text size, set at the window's root and again for the strip, which caps its own,
    /// so popovers take it uncapped, as sheets do.
    @Entry var screenDynamicTypeSize: DynamicTypeSize = .large
}
