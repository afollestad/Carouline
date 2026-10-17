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

    @Test func summarizesAShapeOfTheUsersOwnByItsOrientation() throws {
        let shape = try #require(AspectRatio(width: 5, height: 7, pixelWidth: 2000, pixelHeight: 2800))
        let project = Project(name: "Shop", aspectRatio: shape)
        #expect(project.summary == "5:7 Portrait · no slides")
        #expect(project.spokenSummary == "5 by 7 Portrait, no slides")
    }
}
