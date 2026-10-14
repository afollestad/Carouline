//
//  ProjectPresentationTests.swift
//  SwipesetTests
//

import Foundation
import Testing
@testable import Swipeset

@MainActor
struct ProjectPresentationTests {
    @Test func opensTheLayoutSheetAsASheetAtEveryWidth() {
        #expect(ProjectPresentation.layout(.newSlide).opensAsSheet(isCompact: true))
        #expect(ProjectPresentation.layout(.newSlide).opensAsSheet(isCompact: false))
    }

    /// A wider screen's popovers point at what opened them, and a compact width's are sheets, since
    /// a popover shown as a sheet never keeps the height it's dragged to.
    @Test func opensTheExportAndLayersSheetsAsSheetsOnlyOnACompactWidth() {
        let layers = ProjectPresentation.layers(UUID())
        #expect(ProjectPresentation.export.opensAsSheet(isCompact: true))
        #expect(layers.opensAsSheet(isCompact: true))
        #expect(!ProjectPresentation.export.opensAsSheet(isCompact: false))
        #expect(!layers.opensAsSheet(isCompact: false))
    }

    @Test func neverOpensThePhotoPickerOrCameraAsTheSheet() {
        let camera = ProjectPresentation.camera(CellAddress(projectID: UUID(), slideID: UUID(), index: 0))
        for isCompact in [true, false] {
            #expect(!ProjectPresentation.photoPicker.opensAsSheet(isCompact: isCompact))
            #expect(!camera.opensAsSheet(isCompact: isCompact))
        }
    }
}
