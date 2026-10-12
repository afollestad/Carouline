//
//  Project+Summary.swift
//  Swipeset
//

extension Project {
    /// The shape and size of the carousel, as in "4:5 Portrait · 3 slides".
    var summary: String {
        "\(aspectRatio.rawValue) \(aspectRatio.name) · \(slideCount)"
    }

    /// `summary` as VoiceOver should read it, without the ratio reading as a time.
    var spokenSummary: String {
        "\(aspectRatio.spokenRatio) \(aspectRatio.name), \(slideCount)"
    }

    private var slideCount: String {
        switch slides.count {
        case 0: "no slides"
        case 1: "1 slide"
        default: "\(slides.count) slides"
        }
    }
}
