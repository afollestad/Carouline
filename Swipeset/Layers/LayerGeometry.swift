//
//  LayerGeometry.swift
//  Swipeset
//

import CoreGraphics

/// Where a layer sits and how big it draws, from its placement and its slide. The screen and the
/// export both measure layers here, so a layer sits the same in each.
nonisolated enum LayerGeometry {
    /// A slide's width in an export, which text lays out at before it's scaled, so its lines
    /// break the same on every screen.
    static let referenceSlideWidth: CGFloat = 1080
    /// Type at a layer's natural size, as a fraction of a slide's width: a headline's size on a
    /// phone-sized slide.
    static let fontSize: CGFloat = 0.08
    /// Where lines wrap at a layer's natural size, as a fraction of a slide's width, leaving a
    /// margin either side.
    static let wrapWidth: CGFloat = 0.8
    /// A picture's longer side at a layer's natural size, as a fraction of a slide's width: half,
    /// so it sits over the slide without hiding it.
    static let pictureSide: CGFloat = 0.5

    /// One slide's width on a canvas spanning `span` slides, which every layer measure scales by.
    static func slideWidth(canvas: CGSize, span: Int) -> CGFloat {
        canvas.width / CGFloat(max(1, span))
    }

    /// The layer's unturned frame on a canvas of `canvas` spanning `span` slides, its border or
    /// highlight included.
    static func frame(of layer: Layer, canvas: CGSize, span: Int) -> CGRect {
        let slideWidth = slideWidth(canvas: canvas, span: span)
        let size = size(of: layer, slideWidth: slideWidth)
        let center = CGPoint(x: layer.placement.centerX * slideWidth, y: layer.placement.centerY * canvas.height)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    /// The layer's unturned size on slides `slideWidth` wide, its border or highlight included.
    static func size(of layer: Layer, slideWidth: CGFloat) -> CGSize {
        switch layer.content {
        case .text(let text):
            let box = TextLayerLayout.make(for: text).boxSize(isHighlighted: text.isHighlighted)
            let scale = layer.placement.scale * slideWidth / referenceSlideWidth
            return CGSize(width: box.width * scale, height: box.height * scale)
        case .image(let picture):
            let size = pictureSize(of: picture.image, scale: layer.placement.scale, slideWidth: slideWidth)
            let border = borderWidth(of: picture, pictureSize: size)
            return CGSize(width: size.width + 2 * border, height: size.height + 2 * border)
        }
    }

    /// A picture's own size, inside its border, at `scale` on slides `slideWidth` wide: its
    /// longer side `pictureSide` of a slide at natural size, so a tall picture is as big as a
    /// wide one.
    static func pictureSize(of image: PlacedImage, scale: Double, slideWidth: CGFloat) -> CGSize {
        let longer = pictureSide * scale * slideWidth
        let width = CGFloat(max(1, image.pixelWidth))
        let height = CGFloat(max(1, image.pixelHeight))
        return width >= height
            ? CGSize(width: longer, height: longer * height / width)
            : CGSize(width: longer * width / height, height: longer)
    }

    /// A picture's border width for a picture drawn at `pictureSize`.
    static func borderWidth(of picture: ImageLayer, pictureSize: CGSize) -> CGFloat {
        picture.borderWidth * max(pictureSize.width, pictureSize.height)
    }

    /// A slide's blur on slides `slideWidth` wide, as a Gaussian's sigma: what SwiftUI's
    /// `blur(radius:)` takes, and what the export blurs by in the same gamma-encoded sRGB, so the
    /// two match. Measured against each other at sigmas of 10 to 30, a spreading blur's 10–90%
    /// rise agrees within 2 pixels, and SwiftUI's opaque one is about 5% sharper, too little to
    /// see.
    static func blurRadius(_ blur: Double, slideWidth: CGFloat) -> CGFloat {
        blur * slideWidth
    }

    /// A picture's blur, as a Gaussian's sigma like a slide's, when it's drawn at `pictureSize`:
    /// a share of its longer side, so it blurs alike at any size.
    static func blurRadius(of picture: ImageLayer, pictureSize: CGSize) -> CGFloat {
        picture.blur * max(pictureSize.width, pictureSize.height)
    }

    /// A picture's border width when its frame, border included, is `frame`: the picture and a
    /// border either side, each a share of the picture's longer side.
    static func borderWidth(of picture: ImageLayer, inFrame frame: CGSize) -> CGFloat {
        picture.borderWidth * max(frame.width, frame.height) / (1 + 2 * picture.borderWidth)
    }
}
