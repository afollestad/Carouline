//
//  Project.swift
//  Carouline
//

import Foundation

/// A carousel: slides of one shape, saved and exported together.
nonisolated struct Project: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var aspectRatio: AspectRatio
    /// In carousel order. A panorama is one item that posts as `span` slides, so count and
    /// number the carousel with `carouselSlideCount` and `slideNumbers`.
    var slides: [Slide]
    /// Photos gathered to see before they go on a slide, in the order they were added.
    var tray: [TrayPhoto]
    let createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        aspectRatio: AspectRatio,
        slides: [Slide] = [],
        tray: [TrayPhoto] = [],
        createdAt: Date = .now,
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.aspectRatio = aspectRatio
        self.slides = slides
        self.tray = tray
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
    }

    /// Reads a missing tray as empty, as every project before trays was.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        aspectRatio = try container.decode(AspectRatio.self, forKey: .aspectRatio)
        slides = try container.decode([Slide].self, forKey: .slides)
        tray = try container.decodeIfPresent([TrayPhoto].self, forKey: .tray) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
    }

    /// Leaves out an empty tray, so a project without one saves as it did before trays.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(aspectRatio, forKey: .aspectRatio)
        try container.encode(slides, forKey: .slides)
        if !tray.isEmpty {
            try container.encode(tray, forKey: .tray)
        }
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case aspectRatio
        case slides
        case tray
        case createdAt
        case modifiedAt
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

    /// Whether every slide but `slideID` has `style` already, so giving them all that slide's
    /// style would change nothing.
    func slides(besides slideID: UUID, allHave style: SlideStyle) -> Bool {
        slides.allSatisfy { $0.id == slideID || $0.style == style }
    }

    /// Every image the project's cells, layers and tray hold, which are the only files its folder
    /// should keep.
    var images: [PlacedImage] {
        slides.flatMap(\.images) + tray.map(\.image)
    }

    /// The cells, in carousel order, holding each tray photo that's on a slide: those whose photo
    /// `TrayPhoto.matches`. Pictures in layers don't count, since they're decoration rather than
    /// the carousel's photos.
    var trayPhotoPlaces: [UUID: [TrayPhotoPlace]] {
        var places: [UUID: [TrayPhotoPlace]] = [:]
        let numbers = slideNumbers
        for (slideIndex, slide) in slides.enumerated() {
            for photo in tray {
                let indexes = slide.cells.indices.filter { slide.cells[$0].image.map(photo.matches) == true }
                for index in indexes {
                    places[photo.id, default: []].append(TrayPhotoPlace(
                        address: CellAddress(projectID: id, slideID: slide.id, index: index),
                        slideIndex: slideIndex,
                        numbers: numbers[slideIndex],
                        photoNumber: indexes.count > 1 ? index + 1 : nil
                    ))
                }
            }
        }
        return places
    }
}
