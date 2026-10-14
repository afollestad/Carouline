//
//  LayerGeometryTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

struct LayerGeometryTests {
    private func picture(width: Int, height: Int, border: Double = 0) -> Layer {
        Layer(content: .image(ImageLayer(image: PlacedImage(assetIdentifier: nil, pixelWidth: width, pixelHeight: height), borderWidth: border)))
    }

    /// The same layer sits at the same share of the slide on a phone's card and in a 1080-pixel
    /// export, so the screen shows what posts.
    @Test func placesALayerAlikeAtEverySize() {
        let layer = Layer(content: .text(TextLayer(text: "Day one")), placement: LayerPlacement(centerX: 0.3, centerY: 0.7, scale: 1.5))

        let small = LayerGeometry.frame(of: layer, canvas: CGSize(width: 300, height: 375), span: 1)
        let large = LayerGeometry.frame(of: layer, canvas: CGSize(width: 1080, height: 1350), span: 1)

        let ratio = 1080.0 / 300.0
        #expect(abs(large.midX - small.midX * ratio) < 0.001)
        #expect(abs(large.midY - small.midY * ratio) < 0.001)
        #expect(abs(large.width - small.width * ratio) < 0.001)
        #expect(abs(large.height - small.height * ratio) < 0.001)
    }

    /// Text stops shrinking once a line is `minimumSide` of a slide, however narrow its
    /// characters, and a picture once its shorter side is, border aside, unless it's wide enough
    /// that it stops at the usual smallest scale first, or so narrow that only the largest
    /// reaches it.
    @Test func keepsALayerFromShrinkingToNothing() {
        let dot = TextLayer(text: ".")
        let line = Double(TextLayerLayout.make(for: dot).lineHeight / LayerGeometry.referenceSlideWidth)
        let smallest = LayerGeometry.scales(of: Layer(content: .text(dot))).lowerBound

        #expect(abs(smallest * line - Double(LayerGeometry.minimumSide)) < 1e-9)
        #expect(LayerGeometry.scales(of: Layer(content: .text(TextLayer(text: "Day one by the river")))).lowerBound == smallest)
        #expect(LayerGeometry.scales(of: picture(width: 400, height: 300)) == LayerPlacement.scales)
        let strip = LayerGeometry.scales(of: picture(width: 1000, height: 100))
        #expect(abs(strip.lowerBound - 0.8) < 1e-9)
        #expect(LayerGeometry.scales(of: picture(width: 1000, height: 100, border: 0.08)) == strip)
        #expect(LayerGeometry.scales(of: picture(width: 6000, height: 100)) == 4...4)
    }

    /// A panorama measures layers from one of its slides, so a layer is as big on a panorama as on
    /// a slide, and its center counts slide widths from the left.
    @Test func measuresAPanoramaFromOneSlide() {
        let layer = picture(width: 400, height: 200)
        var crossing = layer
        crossing.placement.centerX = 2

        let single = LayerGeometry.frame(of: layer, canvas: CGSize(width: 1080, height: 1350), span: 1)
        let panorama = LayerGeometry.frame(of: crossing, canvas: CGSize(width: 3240, height: 1350), span: 3)

        #expect(single.size == panorama.size)
        #expect(panorama.midX == 2160)
    }

    /// A layer takes a touch across its box turned with it: a quarter turn stands a wide picture
    /// on end.
    @Test func containsAPointInItsTurnedBox() {
        var layer = picture(width: 400, height: 200)
        layer.placement = LayerPlacement(centerX: 0.5, centerY: 0.5, rotation: .pi / 2)
        let canvas = LayerCanvas(size: CGSize(width: 400, height: 400), span: 1)

        // Upright it's 200 across and 100 down about the middle; turned, 100 across and 200 down.
        #expect(LayerGeometry.contains(CGPoint(x: 200, y: 280), layer: layer, on: canvas))
        #expect(!LayerGeometry.contains(CGPoint(x: 280, y: 200), layer: layer, on: canvas))
    }

    /// Small type takes a touch across a fingertip, which grows with the canvas's points on screen
    /// while the slides are scaled down.
    @Test func containsAFingertipAroundASmallLayer() {
        let layer = Layer(content: .text(TextLayer(text: "Hi")), placement: LayerPlacement(scale: 0.25))
        let canvas = LayerCanvas(size: CGSize(width: 400, height: 400), span: 1)
        let scaled = LayerCanvas(size: canvas.size, span: 1, screenPoint: 2)

        #expect(LayerGeometry.contains(CGPoint(x: 220, y: 200), layer: layer, on: canvas))
        #expect(!LayerGeometry.contains(CGPoint(x: 230, y: 200), layer: layer, on: canvas))
        #expect(LayerGeometry.contains(CGPoint(x: 240, y: 200), layer: layer, on: scaled))
        #expect(!LayerGeometry.contains(CGPoint(x: 250, y: 200), layer: layer, on: scaled))
    }

    /// A layer past the slide's edge still takes a drag there, which a thin panorama needs, where
    /// a fingertip's reach is taller than the slide.
    @Test func containsAPointPastTheSlidesEdge() {
        var layer = picture(width: 400, height: 200)
        layer.placement.centerX = 0.95
        let canvas = LayerCanvas(size: CGSize(width: 400, height: 400), span: 1)

        #expect(LayerGeometry.contains(CGPoint(x: 450, y: 200), layer: layer, on: canvas))
    }

    @Test func containsAPointOnAPanoramasLaterSlide() {
        var layer = picture(width: 400, height: 200)
        layer.placement.centerX = 2
        let panorama = LayerCanvas(size: CGSize(width: 1200, height: 400), span: 3)

        #expect(LayerGeometry.contains(CGPoint(x: 800, y: 200), layer: layer, on: panorama))
        #expect(!LayerGeometry.contains(CGPoint(x: 200, y: 200), layer: layer, on: panorama))
    }

    /// A tall picture is as big as a wide one: its longer side is half a slide, whichever it is.
    @Test func sizesAPictureByItsLongerSide() {
        let wide = LayerGeometry.size(of: picture(width: 400, height: 100), slideWidth: 1000)
        let tall = LayerGeometry.size(of: picture(width: 100, height: 400), slideWidth: 1000)

        #expect(wide == CGSize(width: 500, height: 125))
        #expect(tall == CGSize(width: 125, height: 500))
    }

    @Test func growsAPicturesFrameByItsBorder() {
        let framed = LayerGeometry.size(of: picture(width: 400, height: 200, border: 0.05), slideWidth: 1000)

        // A 500 by 250 picture, and a border a twentieth of its longer side either side.
        #expect(framed == CGSize(width: 550, height: 300))
        let border = LayerGeometry.borderWidth(
            of: ImageLayer(image: PlacedImage(assetIdentifier: nil, pixelWidth: 1, pixelHeight: 1), borderWidth: 0.05),
            inFrame: framed
        )
        #expect(abs(border - 25) < 0.001)
    }

    /// Lines break once, at the reference size, so they're the same whatever the text is drawn at.
    @Test func wrapsLongTextIntoLinesThatFitTheWrapWidth() {
        let text = TextLayer(text: "Our favourite spot to watch the sun set over the river")
        let layout = TextLayerLayout.make(for: text)

        #expect(layout.lines.count > 1)
        let wrap = LayerGeometry.wrapWidth * LayerGeometry.referenceSlideWidth
        #expect(layout.lines.allSatisfy { $0.width <= wrap + 0.5 })
        #expect(layout.textSize.height == CGFloat(layout.lines.count) * layout.lineHeight)
    }

    @Test func keepsTheTextsOwnLineBreaksButNotTrailingOnes() {
        let layout = TextLayerLayout.make(for: TextLayer(text: "Day\n\nOne\n\n"))

        #expect(layout.lines.count == 3)
        #expect(layout.lines[1].width == 0)
    }

    @Test func padsAHighlightedBox() {
        let text = TextLayer(text: "Hi")
        let layout = TextLayerLayout.make(for: text)
        let plain = layout.boxSize(isHighlighted: false)
        let highlighted = layout.boxSize(isHighlighted: true)

        #expect(plain == layout.textSize)
        #expect(abs(highlighted.width - plain.width - 2 * TextLayerLayout.highlightPadding.width * layout.fontSize) < 0.001)
        #expect(abs(highlighted.height - plain.height - 2 * TextLayerLayout.highlightPadding.height * layout.fontSize) < 0.001)
    }

    @Test func blankTextTakesNoRoom() {
        #expect(TextLayerLayout.make(for: TextLayer(text: "")).textSize == .zero)
    }

    /// A blur is a share of the slide or picture, so it blurs alike on any screen and in the export.
    @Test func scalesABlurWithWhatItBlurs() {
        #expect(LayerGeometry.blurRadius(0.02, slideWidth: 1080) == 21.6)
        #expect(LayerGeometry.blurRadius(0.02, slideWidth: 540) == 10.8)
        let picture = ImageLayer(image: PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 200), blur: 0.05)
        #expect(LayerGeometry.blurRadius(of: picture, pictureSize: CGSize(width: 200, height: 100)) == 10)
    }

    /// A picture's shadow is a share of the picture's longer side, its border left out, so it
    /// stays put as the border changes.
    @Test func scalesAShadowWithItsPicture() {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 200)
        let size = CGSize(width: 200, height: 100)
        let shadow = LayerGeometry.Shadow(radius: 200 * LayerGeometry.pictureShadowRadius, offset: 200 * LayerGeometry.pictureShadowOffset)
        #expect(LayerGeometry.shadow(of: ImageLayer(image: image, hasShadow: true), pictureSize: size) == shadow)
        #expect(LayerGeometry.shadow(of: ImageLayer(image: image, borderWidth: 0.08, hasShadow: true), pictureSize: size) == shadow)
        #expect(LayerGeometry.shadow(of: ImageLayer(image: image), pictureSize: size) == nil)
    }
}
