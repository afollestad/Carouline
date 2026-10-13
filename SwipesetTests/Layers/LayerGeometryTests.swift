//
//  LayerGeometryTests.swift
//  SwipesetTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Swipeset

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
