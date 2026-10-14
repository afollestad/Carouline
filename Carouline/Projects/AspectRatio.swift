//
//  AspectRatio.swift
//  Carouline
//

import CoreGraphics

/// The shape every slide in a project shares.
nonisolated enum AspectRatio: String, Codable, CaseIterable, Identifiable, Sendable {
    case portrait = "4:5"
    case tallPortrait = "3:4"
    case story = "9:16"
    case square = "1:1"
    case landscape = "1.91:1"

    var id: Self { self }

    /// Instagram's carousel sizes, 1080 pixels wide, which other apps take as they are. Slides on
    /// screen use these proportions too, so a preview lays out exactly as its export; 1.91:1
    /// rounds to 566 pixels tall, as Instagram's own landscape size does.
    var exportSize: CGSize {
        switch self {
        case .portrait: CGSize(width: 1080, height: 1350)
        case .tallPortrait: CGSize(width: 1080, height: 1440)
        case .story: CGSize(width: 1080, height: 1920)
        case .square: CGSize(width: 1080, height: 1080)
        case .landscape: CGSize(width: 1080, height: 566)
        }
    }

    var widthOverHeight: CGFloat {
        exportSize.width / exportSize.height
    }

    var name: String {
        switch self {
        case .portrait, .tallPortrait: "Portrait"
        case .story: "Story"
        case .square: "Square"
        case .landscape: "Landscape"
        }
    }

    /// The ratio as VoiceOver should read it, since "4:5" reads as a time.
    var spokenRatio: String {
        switch self {
        case .portrait: "4 by 5"
        case .tallPortrait: "3 by 4"
        case .story: "9 by 16"
        case .square: "1 by 1"
        case .landscape: "1.91 by 1"
        }
    }
}
