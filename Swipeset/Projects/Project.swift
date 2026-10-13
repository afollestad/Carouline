//
//  Project.swift
//  Swipeset
//

import Foundation

/// A carousel: slides of one shape and style, saved and exported together.
nonisolated struct Project: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var aspectRatio: AspectRatio
    var style: SlideStyle
    /// In carousel order. A panorama is one item that posts as `span` slides, so count and
    /// number the carousel with `carouselSlideCount` and `slideNumbers`.
    var slides: [Slide]
    let createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        aspectRatio: AspectRatio,
        style: SlideStyle = .standard,
        slides: [Slide] = [],
        createdAt: Date = .now,
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.aspectRatio = aspectRatio
        self.style = style
        self.slides = slides
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
    }

    /// How many images the carousel posts as, counting every slide a panorama spans.
    var carouselSlideCount: Int {
        slides.reduce(0) { $0 + $1.span }
    }

    /// Each slide's numbers in the carousel, from 1, in the order of `slides`: one for most, and
    /// a run for a panorama.
    var slideNumbers: [ClosedRange<Int>] {
        var next = 1
        return slides.map { slide in
            defer { next += slide.span }
            return next...(next + slide.span - 1)
        }
    }

    /// Every image the project's cells and layers hold, which are the only files its folder
    /// should keep.
    var images: [PlacedImage] {
        slides.flatMap(\.images)
    }
}
