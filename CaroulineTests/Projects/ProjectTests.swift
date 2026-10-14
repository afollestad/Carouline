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
}
