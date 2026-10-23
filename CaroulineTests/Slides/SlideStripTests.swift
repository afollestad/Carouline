//
//  SlideStripTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

/// Whether a slide's layers show in a popover or a sheet, on strips about the size of each
/// screen's.
@MainActor
struct SlideStripTests {
    /// iPhone Duo's inner screen in landscape leaves too little room beside a slide.
    @Test func showsTheLayersInASheetOnIPhoneDuoInLandscape() {
        #expect(!SlideStrip.layersPopoverFits(span: 1, aspectRatio: .portrait, in: CGSize(width: 867, height: 553)))
    }

    /// iPad mini in portrait, whose slide fills most of its width.
    @Test func showsTheLayersInASheetOnAnIPadInPortrait() {
        #expect(!SlideStrip.layersPopoverFits(span: 1, aspectRatio: .portrait, in: CGSize(width: 744, height: 1035)))
    }

    /// iPad Pro 13-inch in landscape, with room beside a slide.
    @Test func fitsTheLayersPopoverBesideASlideOnAWideScreen() {
        #expect(SlideStrip.layersPopoverFits(span: 1, aspectRatio: .portrait, in: CGSize(width: 1376, height: 914)))
    }

    /// A panorama on iPad Pro 13-inch in landscape leaves it no room beside.
    @Test func showsAPanoramasLayersInASheetOnAWideScreen() {
        #expect(!SlideStrip.layersPopoverFits(span: 3, aspectRatio: .portrait, in: CGSize(width: 1376, height: 914)))
    }
}

/// Which slide is in the middle of the strip, which a selection there leaves the strip alone for,
/// so a panorama keeps the part in view rather than moving to its own middle.
@MainActor
struct StripFrontTests {
    private let project = Project(
        name: "Ridgeline",
        aspectRatio: .portrait,
        slides: [Slide(layout: .panorama), Slide(layout: .single)]
    )

    /// Before the strip has moved, it rests on the first slide.
    @Test func restsOnTheFirstSlideBeforeMoving() {
        #expect(project.isFront(project.slides[0].id, at: nil))
        #expect(!project.isFront(project.slides[1].id, at: nil))
    }

    @Test func findsTheSlideItRestsOn() {
        #expect(project.isFront(project.slides[1].id, at: .slide(project.slides[1].id)))
        #expect(!project.isFront(project.slides[0].id, at: .slide(project.slides[1].id)))
    }

    /// Resting on the add button, no slide is in front.
    @Test func findsNoSlideOnTheAddButton() {
        #expect(!project.isFront(project.slides[1].id, at: .add))
    }
}
