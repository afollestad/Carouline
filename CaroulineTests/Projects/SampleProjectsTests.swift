//
//  SampleProjectsTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

/// The first-launch sample ships, so it's checked as a user's project would be.
struct SampleProjectsTests {
    /// Read once, since each read takes the clock.
    private let project = SampleProjects.firstLaunch

    @Test func savesAndLoadsUnchanged() throws {
        #expect(try ProjectFile.decode(ProjectFile.encode(project)) == project)
    }

    /// Two images with one ID would write over each other's copy.
    @Test func givesEveryImageAndLayerItsOwnID() {
        let imageIDs = project.images.map(\.id)
        let layerIDs = project.slides.flatMap(\.layers).map(\.id)

        #expect(Set(imageIDs).count == imageIDs.count)
        #expect(Set(layerIDs).count == layerIDs.count)
    }

    /// Its photos were drawn, not picked, so there's no original to restore one from.
    @Test func namesNoLibraryOriginals() {
        #expect(project.images.allSatisfy { $0.assetIdentifier == nil })
    }

    @Test func fillsEveryCell() {
        #expect(project.slides.allSatisfy { $0.cells.allSatisfy { $0.image != nil } })
        #expect(project.carouselSlideCount == 8)
    }

    @Test func fitsTheTitleOnOneLineInsideTheSlide() throws {
        let title = try #require(project.slides.first?.layers.first)
        guard case .text(let text) = title.content else {
            Issue.record("The first slide's first layer isn't its title")
            return
        }
        let canvas = CGSize(width: 1080, height: 1350)
        let frame = LayerGeometry.frame(of: title, canvas: canvas, span: 1)

        #expect(TextLayerLayout.make(for: text).lines.count == 1)
        #expect(CGRect(origin: .zero, size: canvas).insetBy(dx: 0.05 * canvas.width, dy: 0.05 * canvas.width).contains(frame))
    }
}
