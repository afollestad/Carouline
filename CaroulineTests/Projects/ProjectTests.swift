//
//  ProjectTests.swift
//  CaroulineTests
//

import Testing
@testable import Carouline

struct ProjectTests {
    private let project = Project(
        name: "Trip",
        aspectRatio: .portrait,
        slides: [Slide(layout: .single), Slide(layout: .panorama, span: 3), Slide(layout: .grid)]
    )

    @Test func countsEverySlideAPanoramaSpans() {
        #expect(project.carouselSlideCount == 5)
        #expect(project.slideNumbers == [1...1, 2...4, 5...5])
    }

    @Test func summarizesTheCarouselsSlides() {
        #expect(project.summary == "4:5 Portrait · 5 slides")
        #expect(project.spokenSummary == "4 by 5 Portrait, 5 slides")
        #expect(Project(name: "Empty", aspectRatio: .square).summary == "1:1 Square · no slides")
    }

    /// By the carousel number each slide starts at, which a panorama before it moves on.
    @Test func namesSlidesByTheirCarouselNumbers() {
        #expect(project.slidesName(at: [0]) == "Slide 1")
        #expect(project.slidesName(at: [0, 2]) == "Slides 1 and 5")
        #expect(project.slidesName(at: [0, 1, 2]) == "Slides 1, 2, and 5")
        #expect((2...4).slidesName == "Slides 2–4")
        #expect((3...3).slidesName == "Slide 3")
    }

    @Test func summarizesAShapeOfTheUsersOwnByItsOrientation() throws {
        let shape = try #require(AspectRatio(width: 5, height: 7, pixelWidth: 2000, pixelHeight: 2800))
        let project = Project(name: "Shop", aspectRatio: shape)
        #expect(project.summary == "5:7 Portrait · no slides")
        #expect(project.spokenSummary == "5 by 7 Portrait, no slides")
    }

    /// A tray photo is on a slide once a cell holds a clone of it, or a photo from the same
    /// library original; a layer's picture doesn't count.
    @Test func findsTheTrayPhotosOnSlides() {
        let cloned = TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10))
        let picked = TrayPhoto(image: PlacedImage(assetIdentifier: "A/L0/001", pixelWidth: 10, pixelHeight: 10))
        let decorating = TrayPhoto(image: PlacedImage(assetIdentifier: "B/L0/001", pixelWidth: 10, pixelHeight: 10))
        let unused = TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10))
        let sticker = PlacedImage(assetIdentifier: "B/L0/001", pixelWidth: 10, pixelHeight: 10)
        let trip = Project(
            name: "Trip",
            aspectRatio: .portrait,
            slides: [
                Slide(
                    layout: .twoColumns,
                    cells: [
                        Cell(image: PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10, trayPhotoID: cloned.id)),
                        Cell(image: PlacedImage(assetIdentifier: "A/L0/001", pixelWidth: 10, pixelHeight: 10))
                    ],
                    layers: [Layer(content: .image(ImageLayer(image: sticker)))]
                )
            ],
            tray: [cloned, picked, decorating, unused]
        )

        let slideID = trip.slides[0].id
        #expect(trip.trayPhotoPlaces.mapValues { $0.map(\.address) } == [
            cloned.id: [CellAddress(projectID: trip.id, slideID: slideID, index: 0)],
            picked.id: [CellAddress(projectID: trip.id, slideID: slideID, index: 1)]
        ])
        // The cells' and layer's copies, and the tray's own.
        #expect(trip.images.count == 7)
    }

    /// A tray photo's places by their slides' carousel numbers, and by each cell's number on a
    /// slide holding the photo more than once.
    @Test func namesTheTrayPhotosPlaces() {
        let photo = TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10))
        let clone = { Cell(image: PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10, trayPhotoID: photo.id)) }
        let trip = Project(
            name: "Trip",
            aspectRatio: .portrait,
            slides: [
                Slide(layout: .panorama, span: 2, cells: [clone()]),
                Slide(layout: .twoColumns, cells: [clone(), clone()]),
                Slide(layout: .twoColumns, cells: [Cell(), clone()])
            ],
            tray: [photo]
        )

        let places = trip.trayPhotoPlaces[photo.id] ?? []
        #expect(places.map(\.name) == ["Slides 1–2", "Slide 3, Photo 1", "Slide 3, Photo 2", "Slide 4"])
        #expect(places.map(\.spokenName) == ["Slides 1 to 2", "Slide 3, photo 1", "Slide 3, photo 2", "Slide 4"])
        #expect(places.slideIndexes == [0, 1, 2])
    }
}
