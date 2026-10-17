//
//  CustomRatioDraft.swift
//  Carouline
//

import Foundation

/// A ratio and size of the user's own as they're typed: the four fields' text, with the side typed
/// last kept and the other following the ratio, and the shape they make once it's valid.
nonisolated struct CustomRatioDraft: Hashable, Sendable {
    /// Why the fields make no shape, when it's something to tell the user rather than a field
    /// still empty.
    enum Problem: Hashable, Sendable {
        case ratio
        case size

        var message: String {
            switch self {
            case .ratio:
                "Ratios go from 1:2 to 2:1."
            case .size:
                "Sides go from \(AspectRatio.pixelSides.lowerBound.formatted()) to \(AspectRatio.pixelSides.upperBound.formatted()) pixels."
            }
        }
    }

    private enum Side: Hashable, Sendable {
        case width
        case height
    }

    private(set) var ratioWidth: String
    private(set) var ratioHeight: String
    private(set) var pixelWidth: String
    private(set) var pixelHeight: String
    /// The side typed last, which keeps its pixels as the ratio changes, while the other follows.
    private var lockedSide = Side.width
    private let locale: Locale

    /// Starts at 4:5, the shape most carousels take, at a preset's width, so the page opens on a
    /// shape it can make, ready to change.
    init(locale: Locale = .current) {
        self.locale = locale
        ratioWidth = Self.format(term: 4, in: locale)
        ratioHeight = Self.format(term: 5, in: locale)
        pixelWidth = Self.format(pixels: AspectRatio.presetWidth, in: locale)
        pixelHeight = Self.format(pixels: AspectRatio.portrait.pixelHeight, in: locale)
    }

    mutating func setRatioWidth(_ text: String) {
        ratioWidth = text
        followRatio()
    }

    mutating func setRatioHeight(_ text: String) {
        ratioHeight = text
        followRatio()
    }

    mutating func setPixelWidth(_ text: String) {
        pixelWidth = text
        lockedSide = .width
        followRatio()
    }

    mutating func setPixelHeight(_ text: String) {
        pixelHeight = text
        lockedSide = .height
        followRatio()
    }

    /// The shape the fields make, or nil while one is empty or past its limits.
    var aspectRatio: AspectRatio? {
        guard let width = term(ratioWidth), let height = term(ratioHeight),
              let pixelWidth = pixels(pixelWidth), let pixelHeight = pixels(pixelHeight) else {
            return nil
        }
        return AspectRatio(width: width, height: height, pixelWidth: pixelWidth, pixelHeight: pixelHeight)
    }

    /// What's wrong with the ratio and with the size, each told under its own fields, leaving out
    /// a field that's empty.
    var problems: Set<Problem> {
        var problems = Set<Problem>()
        if !ratioWidth.isEmpty, !ratioHeight.isEmpty, !(termsRatio.map { AspectRatio.ratios.contains($0) } ?? false) {
            problems.insert(.ratio)
        }
        let sides = [pixelWidth, pixelHeight].filter { !$0.isEmpty }
        if sides.contains(where: { pixels($0).map { !AspectRatio.pixelSides.contains($0) } ?? true }) {
            problems.insert(.size)
        }
        return problems
    }

    /// The terms' width over height, kept within `AspectRatio.ratios`, for a preview of the shape
    /// as it's typed.
    var previewRatio: Double? {
        termsRatio.map { min(max($0, AspectRatio.ratios.lowerBound), AspectRatio.ratios.upperBound) }
    }

    /// Width over height, once both terms read as numbers above zero.
    private var termsRatio: Double? {
        guard let width = term(ratioWidth), let height = term(ratioHeight), width > 0, height > 0 else {
            return nil
        }
        return width / height
    }

    /// Sizes the side not typed last to the ratio, as long as the ratio and the side typed last read
    /// as numbers, even past their limits, so the size shows what a ratio would make.
    private mutating func followRatio() {
        guard let ratio = termsRatio else {
            return
        }
        switch lockedSide {
        case .width:
            if let width = pixels(pixelWidth), width > 0 {
                pixelHeight = Self.format(pixels: AspectRatio.side(width, times: 1 / ratio), in: locale)
            }
        case .height:
            if let height = pixels(pixelHeight), height > 0 {
                pixelWidth = Self.format(pixels: AspectRatio.side(height, times: ratio), in: locale)
            }
        }
    }

    /// A term to two decimals, as `AspectRatio` keeps it, so the size follows the ratio it makes.
    private func term(_ text: String) -> Double? {
        number(text, allowsFraction: true).map { ($0 * 100).rounded() / 100 }
    }

    private func pixels(_ text: String) -> Int? {
        number(text, allowsFraction: false).map { Int($0) }
    }

    /// The number `text` spells in digits of any script, with at most one of the locale's decimal
    /// separator when `allowsFraction`, or nil for anything else, which neither keypad types.
    /// Foundation's parsers read only as much as makes a number, taking "2000.5" as 2000 and
    /// "1,080" as 1.
    private func number(_ text: String, allowsFraction: Bool) -> Double? {
        let parts = text.components(separatedBy: locale.decimalSeparator ?? ".")
        // Nine digits at most, far past any term or side a shape takes, so none can overflow.
        guard parts.count == 1 || (allowsFraction && parts.count == 2), (1...9).contains(parts.joined().count) else {
            return nil
        }
        var digits = [String]()
        for part in parts {
            var ascii = ""
            for character in part {
                guard let digit = character.wholeNumberValue, (0...9).contains(digit) else {
                    return nil
                }
                ascii += String(digit)
            }
            digits.append(ascii)
        }
        let whole = digits[0].isEmpty ? "0" : digits[0]
        let fraction = digits.count > 1 && !digits[1].isEmpty ? ".\(digits[1])" : ""
        return Double(whole + fraction)
    }

    private static func format(term: Double, in locale: Locale) -> String {
        term.formatted(.number.locale(locale).precision(.fractionLength(0...2)).grouping(.never))
    }

    private static func format(pixels: Int, in locale: Locale) -> String {
        pixels.formatted(.number.locale(locale).grouping(.never))
    }
}
