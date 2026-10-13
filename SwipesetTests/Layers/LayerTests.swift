//
//  LayerTests.swift
//  SwipesetTests
//

import Foundation
import Testing
@testable import Swipeset

struct LayerTests {
    private func json(_ layer: Layer) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try #require(String(data: encoder.encode(layer), encoding: .utf8))
    }

    /// Keyed by kind, rather than the synthesized enum form's unlabeled `_0`.
    @Test func codesItsContentByKind() throws {
        let text = Layer(content: .text(TextLayer(text: "Hi")))
        let image = Layer(content: .image(ImageLayer(image: PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10))))

        for layer in [text, image] {
            let encoded = try json(layer)
            #expect(!encoded.contains("_0"))
            #expect(try JSONDecoder().decode(Layer.self, from: Data(encoded.utf8)) == layer)
        }
        #expect(try json(text).contains(#""content":{"text":{"#))
        #expect(try json(image).contains(#""content":{"image":{"#))
    }

    /// A newer build's typeface draws in the default one here, but saves back as it was.
    @Test func keepsATypefaceItDoesntOffer() throws {
        let layer = Layer(content: .text(TextLayer(text: "Hi", font: LayerFont(rawValue: "comicNeue"))))

        let decoded = try JSONDecoder().decode(Layer.self, from: Data(try json(layer).utf8))

        guard case .text(let text) = decoded.content else {
            Issue.record("Expected text")
            return
        }
        #expect(text.font.rawValue == "comicNeue")
        #expect(!LayerFont.allCases.contains(text.font))
    }

    @Test func clampsItsPlacementOntoTheSlide() {
        let placement = LayerPlacement(centerX: -1, centerY: 2, scale: 10, rotation: 3 * .pi)

        let clamped = placement.clamped(span: 1)

        #expect(clamped.centerX == 0)
        #expect(clamped.centerY == 1)
        #expect(clamped.scale == LayerPlacement.scales.upperBound)
        #expect(abs(abs(clamped.rotation) - .pi) < 1e-9)
        #expect(LayerPlacement(scale: 0).clamped(span: 1).scale == LayerPlacement.scales.lowerBound)
    }

    /// A panorama cut down to fewer slides keeps each layer where it sat on its own slide, on
    /// the last one, rather than piling them against the edge.
    @Test func movesLayersPastANarrowerSpanOntoItsLastSlide() {
        #expect(LayerPlacement(centerX: 4.25).clamped(span: 3).centerX == 2.25)
        #expect(LayerPlacement(centerX: 2.5).clamped(span: 1).centerX == 0.5)
        #expect(LayerPlacement(centerX: 3).clamped(span: 2).centerX == 2)
        // A layer still on the slide, or a span grown wider, stays put.
        #expect(LayerPlacement(centerX: 1.75).clamped(span: 2).centerX == 1.75)
        #expect(LayerPlacement(centerX: 1.75).clamped(span: 5).centerX == 1.75)
    }

    @Test func newTextReadsOnItsSlide() {
        #expect(TextLayer(on: .white).color == .black)
        #expect(TextLayer(on: .black).color == .white)
        #expect(TextLayer(on: RGBColor(red: 0.93, green: 0.91, blue: 0.99)).color == .black)
    }

    /// The highlight takes the color, and the letters turn whichever of black or white reads on it.
    @Test func highlightedLettersReadOnTheirBox() {
        let lavender = RGBColor(red: 0.93, green: 0.91, blue: 0.99)
        let navy = RGBColor(red: 0.1, green: 0.1, blue: 0.4)

        #expect(TextLayer(color: lavender).letterColor == lavender)
        #expect(TextLayer(color: lavender, isHighlighted: true).letterColor == .black)
        #expect(TextLayer(color: navy, isHighlighted: true).letterColor == .white)
    }

    @Test func clampsAPicturesBorderAndBlur() {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10)
        let layer = Layer(content: .image(ImageLayer(image: image, borderWidth: 1, blur: -1)))

        guard case .image(let clamped) = layer.clamped(span: 1).content else {
            Issue.record("Expected an image")
            return
        }
        #expect(clamped.borderWidth == ImageLayer.maximumBorderWidth)
        #expect(clamped.blur == 0)
    }

    @Test func blankTextIsNothingToDraw() {
        #expect(TextLayer(text: " \n ").isBlank)
        #expect(!TextLayer(text: " a ").isBlank)
    }
}
