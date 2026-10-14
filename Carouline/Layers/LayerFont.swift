//
//  LayerFont.swift
//  Carouline
//

import UIKit

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

nonisolated extension LayerFont {
    /// The offered name, as the font picker shows it.
    var name: String {
        switch self {
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .mono: "Mono"
        case .avenirNext: "Avenir Next"
        case .futura: "Futura"
        case .didot: "Didot"
        case .typewriter: "Typewriter"
        case .marker: "Marker"
        case .script: "Script"
        case .handwriting: "Handwriting"
        case .copperplate: "Copperplate"
        default: "Sans"
        }
    }

    /// The face at `size`, or the default face for a name this build doesn't offer or a face
    /// that's missing.
    func uiFont(size: CGFloat) -> UIFont {
        if let postScriptName = Self.postScriptNames[self], let font = UIFont(name: postScriptName, size: size) {
            return font
        }
        let (weight, design) = Self.systemFaces[self] ?? (.semibold, .default)
        let system = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = system.fontDescriptor.withDesign(design) else {
            return system
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Each named face as a PostScript name the system ships, at the weight that reads best over
    /// a photo. Futura has no regular weight, and Bradley Hand comes only in bold.
    private static let postScriptNames: [LayerFont: String] = [
        .avenirNext: "AvenirNext-DemiBold",
        .futura: "Futura-Medium",
        .didot: "Didot",
        .typewriter: "AmericanTypewriter",
        .marker: "MarkerFelt-Wide",
        .script: "SnellRoundhand",
        .handwriting: "BradleyHandITCTT-Bold",
        .copperplate: "Copperplate"
    ]

    /// The system's own designs, each at a weight that holds up over a photo.
    private static let systemFaces: [LayerFont: (UIFont.Weight, UIFontDescriptor.SystemDesign)] = [
        .sans: (.semibold, .default),
        .rounded: (.bold, .rounded),
        .serif: (.semibold, .serif),
        .mono: (.medium, .monospaced)
    ]
}
