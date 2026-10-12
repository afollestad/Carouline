//
//  SlideStyle.swift
//  Swipeset
//

/// The space between and around a project's cells, and the color showing through it.
nonisolated struct SlideStyle: Codable, Hashable, Sendable {
    /// The gap between cells, as a fraction of the slide's width, so it looks the same on screen
    /// and in a 1080-pixel export, and the same across and down a tall slide.
    var spacing: Double
    /// The margin around the cells, as a fraction of the slide's width.
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
