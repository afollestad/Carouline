//
//  LayerFontTests.swift
//  SwipesetTests
//

import Testing
import UIKit
@testable import Swipeset

struct LayerFontTests {
    /// Each named face is a PostScript name the system ships; a typo would quietly fall back to
    /// the default face.
    @Test(arguments: [
        (LayerFont.avenirNext, "AvenirNext-DemiBold"),
        (LayerFont.futura, "Futura-Medium"),
        (LayerFont.didot, "Didot"),
        (LayerFont.typewriter, "AmericanTypewriter"),
        (LayerFont.marker, "MarkerFelt-Wide"),
        (LayerFont.script, "SnellRoundhand"),
        (LayerFont.handwriting, "BradleyHandITCTT-Bold"),
        (LayerFont.copperplate, "Copperplate")
    ])
    func resolvesANamedFace(_ font: LayerFont, postScriptName: String) {
        #expect(font.uiFont(size: 20).fontName == postScriptName)
    }

    /// The system's designs differ from one another and from the default face.
    @Test func resolvesTheSystemsDesigns() {
        let names = [LayerFont.sans, .rounded, .serif, .mono].map { $0.uiFont(size: 20).fontName }

        #expect(Set(names).count == names.count)
    }

    @Test func drawsATypefaceItDoesntOfferInTheDefaultOne() {
        #expect(LayerFont(rawValue: "comicNeue").uiFont(size: 20).fontName == LayerFont.sans.uiFont(size: 20).fontName)
    }

    @Test func namesEveryTypefaceOnOffer() {
        let names = LayerFont.allCases.map(\.name)

        #expect(Set(names).count == LayerFont.allCases.count)
    }
}
