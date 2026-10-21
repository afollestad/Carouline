//
//  Project+Summary.swift
//  Carouline
//

import Foundation

extension Project {
    /// The shape and size of the carousel, as in "4:5 Portrait · 3 slides".
    var summary: String {
        "\(aspectRatio.label) \(aspectRatio.name) · \(slideCountText)"
    }

    /// `summary` as VoiceOver should read it, without the ratio reading as a time.
    var spokenSummary: String {
        "\(aspectRatio.spokenRatio) \(aspectRatio.name), \(slideCountText)"
    }

    /// The slides at `indexes` as a tray photo's preview names them, as "Slide 2" or "Slides 2
    /// and 5", by the carousel number each starts at.
    func slidesName(at indexes: [Int]) -> String {
        let numbers = slideNumbers
        let starts = indexes.filter(numbers.indices.contains).map { String(numbers[$0].lowerBound) }
        return starts.count == 1 ? "Slide \(starts[0])" : "Slides \(starts.formatted(.list(type: .and)))"
    }

    private var slideCountText: String {
        switch carouselSlideCount {
        case 0: "no slides"
        case 1: "1 slide"
        case let count: "\(count) slides"
        }
    }
}

extension ClosedRange<Int> {
    /// Carousel numbers as a slide's caption names them: "Slide 3", or a panorama's "Slides 2–4".
    var slidesName: String {
        count == 1 ? "Slide \(lowerBound)" : "Slides \(lowerBound)–\(upperBound)"
    }

    /// `slidesName` as VoiceOver should read it, rather than trusting it to read the dash.
    var spokenSlidesName: String {
        count == 1 ? "Slide \(lowerBound)" : "Slides \(lowerBound) to \(upperBound)"
    }
}
