//
//  LayerFont.swift
//  Swipeset
//

/// A text layer's typeface, by name. A name this build doesn't offer, as a newer build's might
/// be, draws in the default typeface but is kept as it is, so saving never loses it. Offering
/// another typeface needs no new format version for the same reason.
nonisolated struct LayerFont: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    static let sans = LayerFont(rawValue: "sans")
    static let rounded = LayerFont(rawValue: "rounded")
    static let serif = LayerFont(rawValue: "serif")
    static let mono = LayerFont(rawValue: "mono")
    static let avenirNext = LayerFont(rawValue: "avenirNext")
    static let futura = LayerFont(rawValue: "futura")
    static let didot = LayerFont(rawValue: "didot")
    static let typewriter = LayerFont(rawValue: "typewriter")
    static let marker = LayerFont(rawValue: "marker")
    static let script = LayerFont(rawValue: "script")
    static let handwriting = LayerFont(rawValue: "handwriting")
    static let copperplate = LayerFont(rawValue: "copperplate")

    /// The typefaces on offer, in the order the font picker shows them.
    static let allCases: [LayerFont] = [
        .sans, .rounded, .serif, .mono, .avenirNext, .futura,
        .didot, .typewriter, .marker, .script, .handwriting, .copperplate
    ]
}
