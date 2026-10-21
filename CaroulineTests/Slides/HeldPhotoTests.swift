//
//  HeldPhotoTests.swift
//  CaroulineTests
//

import CoreTransferable
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Carouline

struct HeldPhotoTests {
    /// A photo dragged off to another app hands it nothing, so no type needs declaring and nothing
    /// could misread the app's own JSON.
    @Test func carriesItsJSONOnlyWithinTheApp() {
        #expect(HeldPhoto.exportedContentTypes(visibility: .ownProcess) == [.json])
        #expect(HeldPhoto.exportedContentTypes(visibility: .all).isEmpty)
    }

    @Test func roundTripsThroughJSON() throws {
        let cell = HeldPhoto.cell(CellAddress(projectID: UUID(), slideID: UUID(), index: 2), imageID: UUID())
        let tray = HeldPhoto.tray(projectID: UUID(), photoID: UUID())

        for held in [cell, tray] {
            #expect(try JSONDecoder().decode(HeldPhoto.self, from: JSONEncoder().encode(held)) == held)
        }
    }
}
