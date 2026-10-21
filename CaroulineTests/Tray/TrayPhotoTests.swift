//
//  TrayPhotoTests.swift
//  CaroulineTests
//

import Foundation
import Testing
@testable import Carouline

struct TrayPhotoTests {
    private func photo(_ id: UUID = UUID()) -> TrayPhoto {
        TrayPhoto(id: id, image: PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10))
    }

    /// However a pick's copies finish, they end up in the order they were picked, after what the
    /// tray held before.
    @Test func keepsAPickInTheOrderItWasPicked() {
        let before = photo()
        let pick = [UUID(), UUID(), UUID()]
        var tray = [before]

        tray.insert(photo(pick[2]), inPickOrder: pick)
        tray.insert(photo(pick[0]), inPickOrder: pick)
        tray.insert(photo(pick[1]), inPickOrder: pick)

        #expect(tray.map(\.id) == [before.id] + pick)
    }

    /// A photo added while a pick's copies are still coming stays where it was put.
    @Test func leavesPhotosAddedMeanwhileInPlace() {
        let pick = [UUID(), UUID()]
        let meanwhile = photo()
        var tray: [TrayPhoto] = []

        tray.insert(photo(pick[1]), inPickOrder: pick)
        tray.append(meanwhile)
        tray.insert(photo(pick[0]), inPickOrder: pick)

        #expect(tray.map(\.id) == [pick[0], pick[1], meanwhile.id])
    }

    @Test func readsAPhotosShape() {
        #expect(Orientation(of: CGSize(width: 1536, height: 2048)) == .portrait)
        #expect(Orientation(of: CGSize(width: 2048, height: 1365)) == .landscape)
        #expect(Orientation(of: CGSize(width: 2048, height: 2000)) == .square)
        #expect(Orientation(of: CGSize(width: 4096, height: 1024)) == .wide)
    }

    @Test func appendsAPhotoFromNoPick() {
        let first = photo()
        var tray = [first]
        let other = photo()

        tray.insert(other, inPickOrder: [UUID()])

        #expect(tray.map(\.id) == [first.id, other.id])
    }
}
