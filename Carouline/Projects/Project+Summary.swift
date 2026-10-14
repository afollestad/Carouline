//
//  Project+Summary.swift
//  Carouline
//

extension Project {
    /// The shape and size of the carousel, as in "4:5 Portrait · 3 slides".
    var summary: String {
        "\(aspectRatio.rawValue) \(aspectRatio.name) · \(slideCountText)"
    }

    /// `summary` as VoiceOver should read it, without the ratio reading as a time.
    var spokenSummary: String {
        "\(aspectRatio.spokenRatio) \(aspectRatio.name), \(slideCountText)"
    }

    private var slideCountText: String {
        switch carouselSlideCount {
        case 0: "no slides"
        case 1: "1 slide"
        case let count: "\(count) slides"
        }
    }
}
