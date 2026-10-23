//
//  LayerTests.swift
//  CaroulineTests
//

import Foundation
import Testing
@testable import Carouline

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

    /// A picture without a shadow saves as it did before shadows, and one saved then reads as
    /// having none.
    @Test func savesAShadowOnlyWhenAPictureHasOne() throws {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10)
        let plain = Layer(content: .image(ImageLayer(image: image)))
        let shadowed = Layer(content: .image(ImageLayer(image: image, hasShadow: true)))

        #expect(try !json(plain).contains("hasShadow"))
        #expect(try json(shadowed).contains(#""hasShadow":true"#))
        #expect(try JSONDecoder().decode(Layer.self, from: Data(json(shadowed).utf8)) == shadowed)
    }

    /// A plain border saves as it did before styles, and one saved then reads as plain.
    @Test func savesABorderStyleOnlyWhenItHasOne() throws {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10)
        let plain = Layer(content: .image(ImageLayer(image: image, borderWidth: 0.04)))
        let wavy = Layer(content: .image(ImageLayer(image: image, borderWidth: 0.04, borderStyle: .wavy)))

        #expect(try !json(plain).contains("borderStyle"))
        #expect(try json(wavy).contains(#""borderStyle":"wavy""#))
        #expect(try JSONDecoder().decode(Layer.self, from: Data(json(wavy).utf8)) == wavy)
    }

    /// Text with a plain highlight saves its keys as it did before styles, and text saved then
    /// reads as plain.
    @Test func savesAHighlightStyleOnlyWhenItHasOne() throws {
        let plain = TextLayer(text: "Hi", isHighlighted: true)
        let torn = TextLayer(text: "Hi", isHighlighted: true, highlightStyle: .torn)
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(plain)) as? [String: Any])

        #expect(Set(object.keys) == ["text", "font", "color", "alignment", "hasShadow", "isHighlighted"])
        #expect(try json(Layer(content: .text(torn))).contains(#""highlightStyle":"torn""#))
        #expect(try JSONDecoder().decode(TextLayer.self, from: JSONEncoder().encode(torn)) == torn)
    }

    /// A newer build's border style draws plain here, but saves back as it was.
    @Test func keepsABorderStyleItDoesntOffer() throws {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10)
        let layer = Layer(content: .image(ImageLayer(image: image, borderWidth: 0.04, borderStyle: BorderStyle(rawValue: "neon"))))

        let decoded = try JSONDecoder().decode(Layer.self, from: Data(try json(layer).utf8))

        guard case .image(let picture) = decoded.content else {
            Issue.record("Expected an image")
            return
        }
        #expect(picture.borderStyle.rawValue == "neon")
        #expect(picture.drawnBorderStyle == .plain)
        #expect(BorderEdge.edge(for: picture, seed: decoded.id) == nil)
    }

    /// A highlight has no picture for an instant photo's frame to hold, so it draws plain there.
    @Test func drawsAStyleOnlyWhereItsOffered() {
        #expect(BorderStyle.instant.drawn(on: .photo) == .instant)
        #expect(BorderStyle.instant.drawn(on: .highlight) == .plain)
        #expect(BorderStyle.torn.drawn(on: .highlight) == .torn)
        #expect(BorderStyle.allCases.allSatisfy { $0.drawn(on: .photo) == $0 })
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

    /// JSON can't hold a value that isn't finite, so one would stop the project saving.
    @Test func resetsValuesThatAreNotFinite() {
        let placement = LayerPlacement(centerX: .infinity, centerY: .nan, scale: .nan, rotation: .infinity)

        #expect(placement.clamped(span: 3) == LayerPlacement.middle(ofSpan: 3))
    }

    /// A new layer lands on the panorama slide in the middle of the strip, where it's in view, or
    /// else on the panorama's middle slide.
    @Test func placesANewLayerOnThePanoramaSlideInFront() {
        #expect(LayerPlacement.middle(ofSpan: 5, front: 0).centerX == 0.5)
        #expect(LayerPlacement.middle(ofSpan: 5, front: 4).centerX == 4.5)
        #expect(LayerPlacement.middle(ofSpan: 5).centerX == 2.5)
        #expect(LayerPlacement.middle(ofSpan: 2).centerX == 1.5)
    }

    /// A front past a panorama narrowed since lands on its last slide.
    @Test func keepsANewLayersSlideWithinItsPanorama() {
        #expect(LayerPlacement.middle(ofSpan: 3, front: 7).centerX == 2.5)
        #expect(LayerPlacement.middle(ofSpan: 1, front: 2).centerX == 0.5)
    }

    /// A layer saved or loaded smaller than it goes, as before it had a smallest size, grows to it.
    @Test func clampsALayerToItsSmallestSize() {
        let layer = Layer(content: .text(TextLayer(text: "Hi")), placement: LayerPlacement(scale: 0.2))

        #expect(layer.clamped(span: 1).placement.scale == LayerGeometry.scales(of: layer).lowerBound)
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

    /// An editor changes text whole, and a picture's look but never which picture it is, which a
    /// restore made meanwhile may have changed.
    @Test func editsContentKeepingThePicture() {
        let text = LayerContent.text(TextLayer(text: "Lisbon"))
        let edited = LayerContent.text(TextLayer(text: "Porto"))
        #expect(text.editing(edited) == edited)

        let restored = PlacedImage(assetIdentifier: "A", pixelWidth: 10, pixelHeight: 10)
        let shown = LayerContent.image(ImageLayer(image: restored))
        let missing = PlacedImage(assetIdentifier: "A", pixelWidth: 10, pixelHeight: 10)
        let draft = LayerContent.image(ImageLayer(image: missing, borderWidth: 0.04, borderStyle: .torn, blur: 0.02, hasShadow: true))
        #expect(shown.editing(draft) == .image(ImageLayer(image: restored, borderWidth: 0.04, borderStyle: .torn, blur: 0.02, hasShadow: true)))
        #expect(shown.editing(edited) == nil)
    }
}
