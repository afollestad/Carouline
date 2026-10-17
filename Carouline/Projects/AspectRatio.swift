//
//  AspectRatio.swift
//  Carouline
//

import CoreGraphics

/// The shape every slide in a project shares.
nonisolated enum AspectRatio: String, Codable, CaseIterable, Identifiable, Sendable {
    case story = "9:16"
    case classicPortrait = "2:3"
    case tallPortrait = "3:4"
    case portrait = "4:5"
    case square = "1:1"
    case widescreen = "16:9"
    case landscape = "1.91:1"

    var id: Self { self }

    /// 1080 pixels wide, Instagram's carousel width, which other apps take as they are. Slides on
    /// screen use these proportions too, so a preview lays out exactly as its export; 1.91:1
    /// rounds to 566 pixels tall, as Instagram's own landscape size does, and 16:9 to 608.
    var exportSize: CGSize {
        switch self {
        case .story: CGSize(width: 1080, height: 1920)
        case .classicPortrait: CGSize(width: 1080, height: 1620)
        case .tallPortrait: CGSize(width: 1080, height: 1440)
        case .portrait: CGSize(width: 1080, height: 1350)
        case .square: CGSize(width: 1080, height: 1080)
        case .widescreen: CGSize(width: 1080, height: 608)
        case .landscape: CGSize(width: 1080, height: 566)
        }
    }

    var widthOverHeight: CGFloat {
        exportSize.width / exportSize.height
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

    /// Where the shape fits best, rather than every app that takes it, since three portrait
    /// shapes look alike and the apps are what someone picks between.
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

    /// The ratio as VoiceOver should read it, since "4:5" reads as a time.
    var spokenRatio: String {
        switch self {
        case .story: "9 by 16"
        case .classicPortrait: "2 by 3"
        case .tallPortrait: "3 by 4"
        case .portrait: "4 by 5"
        case .square: "1 by 1"
        case .widescreen: "16 by 9"
        case .landscape: "1.91 by 1"
        }
    }
}
