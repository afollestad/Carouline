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

    /// Every image the project's cells hold, which are the only files its folder should keep.
    var images: [PlacedImage] {
        slides.flatMap { $0.cells.compactMap(\.image) }
    }
}
