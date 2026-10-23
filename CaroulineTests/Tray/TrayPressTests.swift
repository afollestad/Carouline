//
//  TrayPressTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

@MainActor
struct TrayPressTests {
    private let projectID = UUID()
    /// 33, 66 and 44 points wide in the tray: a portrait, a landscape and a square.
    private let portrait = TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 1536, pixelHeight: 2048))
    private let landscape = TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 3000, pixelHeight: 2000))
    private let square = TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 2048))
    /// Narrower than its 187 points of photos, so it scrolls 67.
    private let capsule = CGRect(x: 100, y: 700, width: 120, height: 56)
    private let slide = Slide(layout: .single, cells: [Cell()])

    @Test func laysPhotosOutAsTheTrayDoes() {
        let layout = TrayLayout(photos: [portrait, landscape, square], importingCount: 1)

        #expect(layout.slots == [
            TrayLayout.Slot(photoID: portrait.id, minX: 14, maxX: 47),
            TrayLayout.Slot(photoID: landscape.id, minX: 55, maxX: 121),
            TrayLayout.Slot(photoID: square.id, minX: 129, maxX: 173)
        ])
        // The place held for the photo on its way in, 44 wide, then the inset.
        #expect(layout.contentWidth == 239)
        #expect(TrayLayout(photos: [], importingCount: 0).contentWidth == 28)
    }

    /// Between two photos, past either end, or over a place held for a photo on its way in, the
    /// nearest photo.
    @Test func findsTheNearestPhoto() {
        let layout = TrayLayout(photos: [portrait, landscape, square], importingCount: 1)

        #expect(layout.photo(atX: 20)?.photoID == portrait.id)
        #expect(layout.photo(atX: 50)?.photoID == portrait.id)
        #expect(layout.photo(atX: 52)?.photoID == landscape.id)
        #expect(layout.photo(atX: -40)?.photoID == portrait.id)
        #expect(layout.photo(atX: 200)?.photoID == square.id)
        #expect(TrayLayout(photos: [], importingCount: 2).photo(atX: 20) == nil)
    }

    @Test func magnifiesThePhotoUnderTheFingerAsItSlides() {
        let press = trayPress()

        press.begin(at: CGPoint(x: 120, y: 728))
        #expect(press.photoID == portrait.id)
        #expect(press.anchor == CGRect(x: 114, y: 700, width: 33, height: 56))
        press.move(to: CGPoint(x: 190, y: 728))
        #expect(press.photoID == landscape.id)
        #expect(press.phase == .scrubbing)
    }

    @Test func carriesThePhotoOnceTheFingerRisesOffTheTray() {
        let press = trayPress()

        press.begin(at: CGPoint(x: 190, y: 728))
        // A thumb straying above the tray still looks along it.
        press.move(to: CGPoint(x: 120, y: 680))
        #expect(press.phase == .scrubbing)
        #expect(press.photoID == portrait.id)
        press.move(to: CGPoint(x: 190, y: 675))
        #expect(press.phase == .carrying)
        #expect(press.photoID == portrait.id)
        press.move(to: CGPoint(x: 190, y: 710))
        #expect(press.phase == .scrubbing)
        #expect(press.photoID == landscape.id)
    }

    @Test func leavesAMissingPhotoInTheTray() {
        let press = trayPress()
        press.setMissing(true, for: landscape.id)

        press.begin(at: CGPoint(x: 190, y: 728))
        press.move(to: CGPoint(x: 190, y: 300))

        #expect(press.phase == .scrubbing)
    }

    @Test func opensThePhotosActionsWhenLiftedInTheTray() {
        let press = trayPress()

        press.begin(at: CGPoint(x: 190, y: 728))
        // Back down after rising off the tray, it's looking along the tray again.
        press.move(to: CGPoint(x: 190, y: 300))
        press.move(to: CGPoint(x: 190, y: 720))

        #expect(press.end() == .menu(landscape.id))
        #expect(press.photoID == nil)
        #expect(press.anchor == nil)
    }

    @Test func landsACarriedPhotoInTheCellUnderTheFinger() {
        let press = trayPress()

        press.begin(at: CGPoint(x: 190, y: 728))
        press.move(to: CGPoint(x: 200, y: 300))
        // Measured once the photo is carried, as the cards measure themselves only then.
        press.setCard(card(), for: slide.id)

        let address = CellAddress(projectID: projectID, slideID: slide.id, index: 0)
        #expect(press.target == address)
        #expect(press.hoverSlideID == slide.id)
        #expect(press.end() == .drop(landscape.id, address))
    }

    @Test func landsNothingWhereThereIsNoCell() {
        let press = trayPress()

        press.begin(at: CGPoint(x: 190, y: 728))
        press.move(to: CGPoint(x: 200, y: 300))

        #expect(press.target == nil)
        #expect(press.end() == nil)
    }

    /// The strip bringing a slide forward moves its card under a still finger.
    @Test func retargetsAsCardsMoveUnderTheFinger() {
        let press = trayPress()
        press.begin(at: CGPoint(x: 190, y: 728))
        press.move(to: CGPoint(x: 200, y: 300))

        press.setCard(card(), for: slide.id)
        #expect(press.target?.slideID == slide.id)
        press.setCard(nil, for: slide.id)
        #expect(press.target == nil)
        #expect(press.hoverSlideID == nil)
    }

    @Test func leavesOutCellsWithAPhotoOnItsWay() {
        let press = trayPress()

        press.begin(at: CGPoint(x: 190, y: 728))
        press.move(to: CGPoint(x: 200, y: 300))
        press.setCard(card(importing: [0]), for: slide.id)

        #expect(press.target == nil)
        #expect(press.hoverSlideID == slide.id)
    }

    /// As iPhone Duo's column of bar buttons covers the strip's trailing side.
    @Test func leavesOutSlidesPastTheStripsEdge() {
        let press = trayPress()
        press.setStripTrailingEdge(150)

        press.begin(at: CGPoint(x: 190, y: 728))
        press.move(to: CGPoint(x: 200, y: 300))
        press.setCard(card(), for: slide.id)

        #expect(press.target == nil)
        press.move(to: CGPoint(x: 120, y: 300))
        #expect(press.target != nil)
    }

    /// A press that ends forgets the cards, so the next one doesn't target from where they were.
    @Test func forgetsCardsOnceThePressEnds() {
        let press = trayPress()
        press.begin(at: CGPoint(x: 190, y: 728))
        press.move(to: CGPoint(x: 200, y: 300))
        press.setCard(card(), for: slide.id)
        _ = press.end()

        press.begin(at: CGPoint(x: 190, y: 728))
        press.move(to: CGPoint(x: 200, y: 300))

        #expect(press.target == nil)
    }

    @Test func scrollsAtTheEndsTheTrayCanScrollToward() {
        let press = trayPress()

        press.begin(at: CGPoint(x: 210, y: 728))
        #expect(press.edgeVelocity > 0)
        #expect(press.isAtEdge)
        press.move(to: CGPoint(x: 110, y: 728))
        // Toward the leading end, where it already is.
        #expect(press.edgeVelocity < 0)
        #expect(!press.isAtEdge)
        press.move(to: CGPoint(x: 160, y: 728))
        #expect(press.edgeVelocity == 0)
    }

    @Test func scrollsNotWhileCarrying() {
        let press = trayPress()

        press.begin(at: CGPoint(x: 210, y: 728))
        press.move(to: CGPoint(x: 210, y: 300))

        #expect(press.edgeVelocity == 0)
        #expect(press.scrolled(by: 1) == nil)
    }

    /// Past the trailing end, at full speed, as far as the tray goes, finding the photo under the
    /// still finger.
    @Test func scrollsToTheEndUnderAStillFinger() {
        let press = trayPress()

        press.begin(at: CGPoint(x: 221, y: 728))
        #expect(press.photoID == landscape.id)
        #expect(press.scrolled(by: 1.0 / 64) == 10.9375)
        #expect(press.scrolled(by: 1) == 67)
        #expect(press.photoID == square.id)
        #expect(press.anchor?.minX == CGFloat(100 + 129 - 67))
        #expect(press.scrolled(by: 1) == nil)
        #expect(!press.isAtEdge)
    }

    /// A scroll view reporting less than the photos' width, as a lazy stack can, stops short there.
    @Test func scrollsNoFurtherThanTheScrollViewReports() {
        let press = trayPress(maxOffset: 30)

        press.begin(at: CGPoint(x: 230, y: 728))

        #expect(press.scrolled(by: 1) == 30)
    }

    @Test func findsThePhotoUnderAPointer() {
        let press = trayPress()
        press.trayScrolled(to: 67, maxOffset: 67)

        #expect(press.photo(at: CGPoint(x: 110, y: 728)) == landscape.id)
    }

    /// A photo held with no finger, as a debug launch shows, sits where the tray lays it out.
    @Test func magnifiesAPhotoWithNoFinger() {
        let press = TrayPress(scrubbing: square.id)
        #expect(press.anchor == nil)

        press.setLayout(TrayLayout(photos: [portrait, landscape, square], importingCount: 0))
        press.setCapsule(capsule)

        #expect(press.anchor == CGRect(x: 229, y: 700, width: 44, height: 56))
    }

    private func trayPress(maxOffset: CGFloat = 67) -> TrayPress {
        let press = TrayPress()
        press.setLayout(TrayLayout(photos: [portrait, landscape, square], importingCount: 0))
        press.setCapsule(capsule)
        press.trayScrolled(to: 0, maxOffset: maxOffset)
        return press
    }

    /// The slide's card, 300 by 400 at full size, from 50, 100.
    private func card(importing: Set<Int> = []) -> TrayPress.Card {
        TrayPress.Card(
            frame: SlideFrame(frame: CGRect(x: 50, y: 100, width: 300, height: 400), size: CGSize(width: 300, height: 400)),
            slide: slide,
            projectID: projectID,
            importing: importing
        )
    }
}
