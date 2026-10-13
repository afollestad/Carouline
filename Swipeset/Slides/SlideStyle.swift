//
//  SlideStyle.swift
//  Swipeset
//

import UIKit

/// The space between and around a project's cells, and the color showing through it.
nonisolated struct SlideStyle: Codable, Hashable, Sendable {
    /// The gap between cells, as a fraction of one slide's width even in a panorama, so it looks
    /// the same on screen and in a 1080-pixel export, and the same across and down a tall slide.
    var spacing: Double
    /// The margin around the cells, as a fraction of one slide's width. A panorama's frames the
    /// whole panorama, leaving its cuts without one.
    var border: Double
    var background: RGBColor

    /// A hairline gap that separates photos without framing them.
    static let standard = SlideStyle(spacing: 0.01, border: 0, background: .white)

    /// Wider than this, a three-column slide's cells turn into slivers.
    static let maximumSpacing = 0.06
    static let maximumBorder = 0.06
}

/// An opaque color in gamma-encoded sRGB, as color pickers and image renderers use it.
nonisolated struct RGBColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    static let white = RGBColor(red: 1, green: 1, blue: 1)
    static let black = RGBColor(red: 0, green: 0, blue: 0)
}

nonisolated extension RGBColor {
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    /// `color` in sRGB, clamped, since a wide-gamut pick reads past 0...1 there. Read through
    /// `UIColor` rather than `Color.Resolved`, whose components are linear.
    init(_ color: UIColor) {
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let components = color.cgColor.converted(to: sRGB, intent: .defaultIntent, options: nil)?.components ?? [1, 1, 1, 1]
        func channel(_ index: Int) -> Double {
            min(max(Double(components.count >= 3 ? components[index] : components[0]), 0), 1)
        }
        self.init(red: channel(0), green: channel(1), blue: channel(2))
    }
}
