//
//  BorderStyle.swift
//  Carouline
//

import Foundation

/// The edge a picture's border or a text's highlight takes, by name. A name this build doesn't
/// offer, as a newer build's might be, draws plain but is kept as it is, so saving never loses it.
/// Offering another style needs no new format version for the same reason.
nonisolated struct BorderStyle: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    static let plain = BorderStyle(rawValue: "plain")
    static let jagged = BorderStyle(rawValue: "jagged")
    static let wavy = BorderStyle(rawValue: "wavy")
    static let scalloped = BorderStyle(rawValue: "scalloped")
    static let torn = BorderStyle(rawValue: "torn")
    static let burnt = BorderStyle(rawValue: "burnt")
    static let postageStamp = BorderStyle(rawValue: "postageStamp")
    static let rubberStamp = BorderStyle(rawValue: "rubberStamp")
    static let instant = BorderStyle(rawValue: "instant")

    /// The styles on offer, in the order the style picker shows them.
    static let allCases: [BorderStyle] = [
        .plain, .jagged, .wavy, .scalloped, .torn, .burnt, .postageStamp, .rubberStamp, .instant
    ]

    /// What a style shapes: an opaque picture's frame, a transparent one's outline, or a text's
    /// highlight.
    enum Surface {
        case photo
        case sticker
        case highlight
    }
}

nonisolated extension BorderStyle {
    /// The offered name, as the style picker shows it.
    var name: String {
        switch self {
        case .jagged: "Jagged"
        case .wavy: "Wavy"
        case .scalloped: "Scalloped"
        case .torn: "Torn"
        case .burnt: "Burnt"
        case .postageStamp: "Postage Stamp"
        case .rubberStamp: "Rubber Stamp"
        case .instant: "Instant"
        default: "Plain"
        }
    }

    /// The styles `surface` takes, in the picker's order. A highlight has no picture for an
    /// instant photo's frame to hold, and a sticker's outline takes only plain or a card for now.
    static func offered(on surface: Surface) -> [BorderStyle] {
        switch surface {
        case .photo: allCases
        case .sticker: [.plain, .instant]
        case .highlight: allCases.filter { $0 != .instant }
        }
    }

    /// The style `surface` draws in: this one where it's offered there, and plain otherwise, as
    /// for a name this build doesn't know.
    func drawn(on surface: Surface) -> BorderStyle {
        Self.offered(on: surface).contains(self) ? self : .plain
    }
}
