//
//  TestSample.swift
//  CaroulineTests
//

import Foundation
@testable import Carouline

/// A first-launch sample small enough to draw in every test that adds one, with a photo and a
/// sticker, as `SampleProjects.firstLaunch` has.
enum TestSample {
    /// Whole seconds, which is all a saved date keeps.
    private static let created = Date(timeIntervalSince1970: 1_800_000_000)

    static let project = Project(
        name: "Sample",
        aspectRatio: .portrait,
        slides: [
            Slide(
                layout: .single,
                cells: [Cell(image: PlacedImage(assetIdentifier: nil, pixelWidth: 40, pixelHeight: 50))],
                layers: [Layer(content: .image(ImageLayer(image: sticker)))]
            )
        ],
        createdAt: created
    )

    private static let sticker = PlacedImage(assetIdentifier: nil, pixelWidth: 20, pixelHeight: 20, fileFormat: .png)
}
