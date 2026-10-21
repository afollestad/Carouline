//
//  LayerGeometry.swift
//  Carouline
//

import CoreGraphics

/// Where a layer sits and how big it draws, from its placement and its slide. The screen and the
/// export both measure layers here, so a layer sits the same in each.
nonisolated enum LayerGeometry {
    /// A preset's slide width in an export, which text lays out at before it's scaled to the
    /// slide's, so its lines break the same on every screen and in an export of any size.
    static let referenceSlideWidth = CGFloat(AspectRatio.presetWidth)
    /// Type at a layer's natural size, as a fraction of a slide's width: a headline's size on a
    /// phone-sized slide.
    static let fontSize: CGFloat = 0.08
    /// Where lines wrap at a layer's natural size, as a fraction of a slide's width, leaving a
    /// margin either side.
    static let wrapWidth: CGFloat = 0.8
    /// A picture's longer side at a layer's natural size, as a fraction of a slide's width: half,
    /// so it sits over the slide without hiding it.
    static let pictureSide: CGFloat = 0.5
    /// A fingertip's target on screen, which text in small type or a small picture takes touches
    /// across.
    static let minimumTarget: CGFloat = 44
    /// How small a line of text or a picture's shorter side goes, as a fraction of a slide's
    /// width: a twenty-fifth, which leaves type of about 11 to 15 points, as small as a phone's
    /// footnotes, on a slide shown as wide as the phone, and a narrow picture a strip that shows.
    static let minimumSide: CGFloat = 0.04
    /// A picture's shadow, as shares of its longer side: its blur, as a Gaussian's sigma like a
    /// picture's blur, and how far down it falls. Soft and close, as text's is, so it lifts the
    /// picture off a busy slide without reading as a dark band along its edge.
    static let pictureShadowRadius: CGFloat = 0.03
    static let pictureShadowOffset: CGFloat = 0.02
    /// An instant photo's bottom margin, as a multiple of its border's other sides: about a
    /// Polaroid's, with room under the picture to write on.
    static let instantBottomMargin: CGFloat = 4

    /// A shadow's blur, as a Gaussian's sigma, and how far down it falls, in the layer's own
    /// space, so it turns with the layer.
    struct Shadow: Equatable {
        let radius: CGFloat
        let offset: CGFloat
    }

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

    /// The layer's unturned frame on `canvas`, grown to a fingertip's target on screen, which is
    /// where it takes touches.
    static func hitBox(of layer: Layer, on canvas: LayerCanvas) -> CGRect {
        let frame = frame(of: layer, canvas: canvas.size, span: canvas.span)
        let side = minimumTarget * canvas.screenPoint
        return frame.insetBy(dx: -max(0, (side - frame.width) / 2), dy: -max(0, (side - frame.height) / 2))
    }

    /// Whether `point`, in `canvas`'s coordinates, falls in `layer`'s hit box turned with it. Not
    /// cut to the slide, so a fingertip's reach past a thin panorama's edge still finds it.
    static func contains(_ point: CGPoint, layer: Layer, on canvas: LayerCanvas) -> Bool {
        let box = hitBox(of: layer, on: canvas)
        return box.contains(point.applying(turn(about: box, by: layer.placement.rotation).inverted()))
    }

    /// Turns by `rotation` radians about `box`'s center, as a layer turns.
    static func turn(about box: CGRect, by rotation: Double) -> CGAffineTransform {
        CGAffineTransform(translationX: box.midX, y: box.midY)
            .rotated(by: rotation)
            .translatedBy(x: -box.midX, y: -box.midY)
    }

    /// The scales `layer` can take: `LayerPlacement.scales`, starting where a line of its text, or
    /// a picture's shorter side, is `minimumSide` if that's later, so a pinch never shrinks it to
    /// nothing. Text measures a line rather than its box, and a picture leaves out its border, so
    /// a lone narrow character shrinks as far as a word, and editing a layer's text, highlight or
    /// border never resizes it. A picture too narrow to reach it by the largest scale can take
    /// only that.
    static func scales(of layer: Layer) -> ClosedRange<Double> {
        let scales = LayerPlacement.scales
        let side: CGFloat
        switch layer.content {
        case .text(let text):
            side = TextLayerLayout.make(for: text).lineHeight / referenceSlideWidth
        case .image(let picture):
            let size = pictureSize(of: picture.image, scale: 1, slideWidth: 1)
            side = min(size.width, size.height)
        }
        return min(max(scales.lowerBound, Double(minimumSide / side)), scales.upperBound)...scales.upperBound
    }

    /// The layer's unturned size on slides `slideWidth` wide, its border or highlight included.
    static func size(of layer: Layer, slideWidth: CGFloat) -> CGSize {
        switch layer.content {
        case .text(let text):
            let box = TextLayerLayout.make(for: text).boxSize(isHighlighted: text.isHighlighted)
            let scale = layer.placement.scale * slideWidth / referenceSlideWidth
            return CGSize(width: box.width * scale, height: box.height * scale)
        case .image(let picture):
            return frameSize(of: picture, pictureSize: pictureSize(of: picture.image, scale: layer.placement.scale, slideWidth: slideWidth))
        }
    }

    /// A picture's frame, its border included, around the picture drawn at `pictureSize`: the
    /// border all round, and an instant photo's deeper margin below.
    static func frameSize(of picture: ImageLayer, pictureSize: CGSize) -> CGSize {
        let border = borderWidth(of: picture, pictureSize: pictureSize)
        return CGSize(
            width: pictureSize.width + 2 * border,
            height: pictureSize.height + border + bottomMargin(of: picture, border: border)
        )
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

    /// A picture's shadow when it's drawn at `pictureSize`, or nil when it has none. Measured
    /// from the picture alone, so it stays put as the border changes.
    static func shadow(of picture: ImageLayer, pictureSize: CGSize) -> Shadow? {
        guard picture.hasShadow else {
            return nil
        }
        let side = max(pictureSize.width, pictureSize.height)
        return Shadow(radius: pictureShadowRadius * side, offset: pictureShadowOffset * side)
    }

    /// Where a picture sits in its frame `frame`, border included: inset by its border, a share of
    /// the picture's longer side, and by an instant photo's deeper margin below. Solved from the
    /// frame's width, which every style's border grows alike, and the picture's shape.
    static func pictureRect(of picture: ImageLayer, inFrame frame: CGRect) -> CGRect {
        // The picture's size with its longer side 1.
        let shape = pictureSize(of: picture.image, scale: 1, slideWidth: 1 / pictureSide)
        let border = picture.borderWidth * frame.width / (shape.width + 2 * picture.borderWidth)
        let bottom = bottomMargin(of: picture, border: border)
        return CGRect(
            x: frame.minX + border,
            y: frame.minY + border,
            width: max(0, frame.width - 2 * border),
            height: max(0, frame.height - border - bottom)
        )
    }

    private static func bottomMargin(of picture: ImageLayer, border: CGFloat) -> CGFloat {
        picture.drawnBorderStyle == .instant ? instantBottomMargin * border : border
    }
}
