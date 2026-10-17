//
//  AspectRatio.swift
//  Carouline
//

import CoreGraphics
import Foundation

/// The shape every slide in a project shares, and the size each exports at: one of `presets`,
/// or a ratio and size of the user's own.
nonisolated struct AspectRatio: Codable, Hashable, Sendable {
    /// The ratio's terms, as in 4 and 5 for 4:5, which name it. Kept as typed, so 16:10 stays
    /// 16:10 rather than 8:5.
    let width: Double
    let height: Double
    /// Each slide's size in an export. Slides on screen take their proportions from it too, so a
    /// preview lays out exactly as its export.
    let pixelWidth: Int
    let pixelHeight: Int

    static let story = AspectRatio(preset: .story)
    static let classicPortrait = AspectRatio(preset: .classicPortrait)
    static let tallPortrait = AspectRatio(preset: .tallPortrait)
    static let portrait = AspectRatio(preset: .portrait)
    static let square = AspectRatio(preset: .square)
    static let widescreen = AspectRatio(preset: .widescreen)
    static let landscape = AspectRatio(preset: .landscape)

    /// The shapes the New Project sheet offers, tallest first.
    static let presets = Preset.allCases.map(AspectRatio.init(preset:))

    /// Instagram's carousel width, which every preset exports at and other apps take as they are.
    static let presetWidth = 1080
    /// Width over height, from 1:2 to 2:1: every preset and the common shapes between, while a
    /// slide still leaves room for the caption and buttons over it, and for three columns of cells.
    static let ratios: ClosedRange<Double> = 0.5...2
    /// From Instagram's narrowest upload to X's largest, as far as any app takes a carousel.
    static let pixelSides = 320...4096

    /// A shape of the user's own, its terms kept to two decimals, or nil past `ratios` or
    /// `pixelSides`, or when its size doesn't keep its ratio.
    init?(width: Double, height: Double, pixelWidth: Int, pixelHeight: Int) {
        self.init(
            uncheckedWidth: (width * 100).rounded() / 100,
            height: (height * 100).rounded() / 100,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        )
        guard isValid else {
            return nil
        }
    }

    private init(preset: Preset) {
        let terms = preset.terms
        self.init(
            uncheckedWidth: terms.width,
            height: terms.height,
            pixelWidth: Self.presetWidth,
            pixelHeight: Self.side(Self.presetWidth, times: terms.height / terms.width)
        )
    }

    private init(uncheckedWidth width: Double, height: Double, pixelWidth: Int, pixelHeight: Int) {
        self.width = width
        self.height = height
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    /// Versions 1 to 4 of a project's file saved only presets, by name, as "4:5".
    init(from decoder: any Decoder) throws {
        if let name = try? decoder.singleValueContainer().decode(String.self) {
            guard let preset = Preset(rawValue: name) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "No preset is named \(name)."
                ))
            }
            self.init(preset: preset)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            uncheckedWidth: try container.decode(Double.self, forKey: .width),
            height: try container.decode(Double.self, forKey: .height),
            pixelWidth: try container.decode(Int.self, forKey: .pixelWidth),
            pixelHeight: try container.decode(Int.self, forKey: .pixelHeight)
        )
        guard isValid else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "\(label) at \(pixelWidth) by \(pixelHeight) is past the shapes a build makes."
            ))
        }
    }

    /// `given` pixels times `ratio`, rounded up, as Instagram rounds 1.91:1's 565.4 pixels to
    /// 566, so every preset's size follows from its ratio, and a shape of the user's own at a
    /// preset's ratio and width matches it. Less a hair first, so floating-point error in an exact
    /// product, as 1080 × 16 / 9, can't round it up a pixel.
    static func side(_ given: Int, times ratio: Double) -> Int {
        let product = Double(given) * ratio - 1e-9
        // Also refuses a NaN, which a ratio of zero to zero gives.
        guard product > 0 else {
            return 0
        }
        // Far past any side a build makes, so a far-off ratio can't overflow.
        return Int(min(product, 1_000_000_000).rounded(.up))
    }

    var exportSize: CGSize {
        CGSize(width: pixelWidth, height: pixelHeight)
    }

    var widthOverHeight: CGFloat {
        exportSize.width / exportSize.height
    }

    /// Whether the terms and size are within `ratios` and `pixelSides`, and the size keeps the
    /// terms' ratio, to the pixel `side(_:times:)` rounds by.
    var isValid: Bool {
        guard width.isFinite, height.isFinite, width > 0, height > 0, Self.ratios.contains(width / height),
              Self.pixelSides.contains(pixelWidth), Self.pixelSides.contains(pixelHeight) else {
            return false
        }
        let widthPixels = Double(pixelWidth)
        let heightPixels = Double(pixelHeight)
        return Self.ratios.contains(widthPixels / heightPixels)
            && (abs(heightPixels - widthPixels * height / width) <= 1 || abs(widthPixels - heightPixels * width / height) <= 1)
    }

    /// The ratio as written, as in "4:5" or "1.91:1".
    var label: String {
        "\(Self.format(width)):\(Self.format(height))"
    }

    /// The ratio as VoiceOver should read it, since "4:5" reads as a time.
    var spokenRatio: String {
        "\(Self.format(width)) by \(Self.format(height))"
    }

    /// A preset's name, even at a size of the user's own, or else the shape's orientation.
    var name: String {
        if let preset {
            return preset.name
        }
        if width < height {
            return "Portrait"
        }
        return width > height ? "Landscape" : "Square"
    }

    /// Where a preset fits best, rather than every app that takes it, since three portrait
    /// shapes look alike and the apps are what someone picks between.
    var uses: String? {
        preset?.uses
    }

    /// The preset with these terms, whatever its size.
    private var preset: Preset? {
        Preset.allCases.first { $0.terms == (width, height) }
    }

    private static func format(_ term: Double) -> String {
        term.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }

    private enum CodingKeys: String, CodingKey {
        case width, height, pixelWidth, pixelHeight
    }

    /// A shape the New Project sheet offers, by the name a project's file saved it as before
    /// version 5.
    private enum Preset: String, CaseIterable {
        case story = "9:16"
        case classicPortrait = "2:3"
        case tallPortrait = "3:4"
        case portrait = "4:5"
        case square = "1:1"
        case widescreen = "16:9"
        case landscape = "1.91:1"

        var terms: (width: Double, height: Double) {
            switch self {
            case .story: (9, 16)
            case .classicPortrait: (2, 3)
            case .tallPortrait: (3, 4)
            case .portrait: (4, 5)
            case .square: (1, 1)
            case .widescreen: (16, 9)
            case .landscape: (1.91, 1)
            }
        }

        var name: String {
            switch self {
            case .classicPortrait, .tallPortrait, .portrait: "Portrait"
            case .story: "Story"
            case .square: "Square"
            case .widescreen: "Widescreen"
            case .landscape: "Landscape"
            }
        }

        var uses: String {
            switch self {
            case .story: "TikTok, Stories"
            case .classicPortrait: "Pinterest"
            case .tallPortrait, .landscape: "Instagram"
            case .portrait: "Threads"
            case .square: "LinkedIn"
            case .widescreen: "X, YouTube"
            }
        }
    }
}
