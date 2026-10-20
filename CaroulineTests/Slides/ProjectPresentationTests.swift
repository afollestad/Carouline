//
//  ProjectPresentationTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

@MainActor
struct ProjectPresentationTests {
    @Test func opensTheLayoutSheetAsASheetEverywhere() {
        #expect(ProjectPresentation.layout(.newSlide).opensAsSheet(prefersSheets: true))
        #expect(ProjectPresentation.layout(.newSlide).opensAsSheet(prefersSheets: false))
    }

    /// A wider screen's popovers point at what opened them, and a compact width's are sheets, since
    /// a popover shown as a sheet never keeps the height it's dragged to.
    @Test func opensTheExportAndLayersSheetsAsSheetsOnlyWhereSheetsArePreferred() {
        let layers = ProjectPresentation.layers(UUID())
        #expect(ProjectPresentation.export.opensAsSheet(prefersSheets: true))
        #expect(layers.opensAsSheet(prefersSheets: true))
        #expect(!ProjectPresentation.export.opensAsSheet(prefersSheets: false))
        #expect(!layers.opensAsSheet(prefersSheets: false))
    }

    /// A slide's layers prefer a sheet where their popover doesn't fit beside the slide, as on
    /// iPhone Duo in landscape, and a popover until the strip has measured itself.
    @Test func prefersASheetForLayersOnlyWhereTheirPopoverDoesntFit() {
        let slide = Slide(layout: .single)
        let project = Project(name: "Duo", aspectRatio: .portrait, slides: [slide])
        let layers = ProjectPresentation.layers(slide.id)
        let style = OpenedStyle()
        #expect(!style.prefersSheets(for: layers, isCompact: false, in: project))
        style.stripSize = CGSize(width: 867, height: 553)
        #expect(style.prefersSheets(for: layers, isCompact: false, in: project))
        #expect(!style.prefersSheets(for: .export, isCompact: false, in: project))
        style.stripSize = CGSize(width: 1376, height: 914)
        #expect(!style.prefersSheets(for: layers, isCompact: false, in: project))
        #expect(style.prefersSheets(for: .export, isCompact: true, in: project))
    }

    /// A slide's layers sheet leaves the slides taking taps, so a tap off the slide closes it, and
    /// does nothing else. The others close themselves on a tap outside.
    @Test func closesOnlyALayersSheetOnABackgroundTap() {
        let camera = ProjectPresentation.camera(CellAddress(projectID: UUID(), slideID: UUID(), index: 0))
        #expect(ProjectPresentation.layers(UUID()).closesOnBackgroundTap)
        for presentation in [ProjectPresentation.layout(.newSlide), .export, .photoPicker, camera] {
            #expect(!presentation.closesOnBackgroundTap)
        }
    }

    @Test func neverOpensThePhotoPickerOrCameraAsTheSheet() {
        let camera = ProjectPresentation.camera(CellAddress(projectID: UUID(), slideID: UUID(), index: 0))
        for prefersSheets in [true, false] {
            #expect(!ProjectPresentation.photoPicker.opensAsSheet(prefersSheets: prefersSheets))
            #expect(!camera.opensAsSheet(prefersSheets: prefersSheets))
        }
    }
}
