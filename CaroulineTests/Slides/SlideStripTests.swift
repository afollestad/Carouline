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
