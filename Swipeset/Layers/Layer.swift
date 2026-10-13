//
//  Layer.swift
//  Swipeset
//

import Foundation

/// Text or an image drawn over a slide's cells. A slide stacks its layers bottom to top, over
/// its layout, which stays beneath them all.
nonisolated struct Layer: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var content: LayerContent
    var placement: LayerPlacement

    init(id: UUID = UUID(), content: LayerContent, placement: LayerPlacement = LayerPlacement()) {
        self.id = id
        self.content = content
        self.placement = placement
    }

    /// The image the layer shows, whose copy its project's folder keeps.
    var image: PlacedImage? {
        if case .image(let layer) = content {
            layer.image
        } else {
            nil
        }
    }

    /// The layer kept within range on a slide `span` slides wide.
    func clamped(span: Int) -> Layer {
        var layer = self
        layer.placement = placement.clamped(span: span)
        if case .image(let image) = content {
            layer.content = .image(image.clamped())
        }
        return layer
    }
}

/// Where a layer sits on its slide, independent of the size the slide is drawn at.
nonisolated struct LayerPlacement: Codable, Hashable, Sendable {
    /// The layer's center across the slide, in slide widths from its left edge, from 0 to its
    /// span. Measured in slide widths rather than across the whole, so a layer stays where it is
    /// on its slide when a panorama spans more slides or fewer.
    var centerX: Double
    /// The layer's center down the slide, as a fraction of its height.
    var centerY: Double
    /// How many times its natural size the layer draws.
    var scale: Double
    /// Radians clockwise.
    var rotation: Double

    init(centerX: Double = 0.5, centerY: Double = 0.5, scale: Double = 1, rotation: Double = 0) {
        self.centerX = centerX
        self.centerY = centerY
        self.scale = scale
        self.rotation = rotation
    }

    /// A fifth of its natural size is about as small as a layer's text stays readable in an
    /// export, and four times makes a natural-size image two slides wide, past filling one.
    static let scales = 0.2...4.0

    /// The placement kept on a slide `span` slides wide: its center on the slide, its scale in
    /// `scales`, and its rotation within half a turn either way. A center past a narrower span's
    /// end moves onto the last slide at the same place within its own, rather than piling up
    /// against the edge.
    func clamped(span: Int) -> LayerPlacement {
        let width = Double(max(1, span))
        var placement = self
        if centerX > width {
            placement.centerX = centerX - (centerX - width).rounded(.up)
        }
        placement.centerX = min(max(placement.centerX, 0), width)
        placement.centerY = min(max(centerY, 0), 1)
        placement.scale = min(max(scale, Self.scales.lowerBound), Self.scales.upperBound)
        placement.rotation = remainder(rotation, 2 * .pi)
        return placement
    }
}

/// What a layer draws.
nonisolated enum LayerContent: Hashable, Sendable {
    case text(TextLayer)
    case image(ImageLayer)
}

/// Keyed by the kind of layer, as `{"text": {…}}` or `{"image": {…}}`, rather than the
/// synthesized form's unlabeled `_0`.
nonisolated extension LayerContent: Codable {
    private enum CodingKeys: String, CodingKey {
        case text
        case image
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try container.decodeIfPresent(TextLayer.self, forKey: .text) {
            self = .text(text)
        } else {
            self = .image(try container.decode(ImageLayer.self, forKey: .image))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text): try container.encode(text, forKey: .text)
        case .image(let image): try container.encode(image, forKey: .image)
        }
    }
}

/// Text over a slide, in one font and color.
nonisolated struct TextLayer: Codable, Hashable, Sendable {
    var text: String
    var font: LayerFont
    var color: RGBColor
    var alignment: TextLayerAlignment
    var hasShadow: Bool
    /// Whether a rounded box in `color` sits behind the text, which turns black or white to
    /// read on it.
    var isHighlighted: Bool

    init(
        text: String = "",
        font: LayerFont = .sans,
        color: RGBColor = .white,
        alignment: TextLayerAlignment = .center,
        hasShadow: Bool = false,
        isHighlighted: Bool = false
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.alignment = alignment
        self.hasShadow = hasShadow
        self.isHighlighted = isHighlighted
    }

    /// New text that reads on a slide of `background`: black on a light one, white on a dark one.
    init(on background: RGBColor) {
        self.init(color: background.isLight ? .black : .white)
    }

    /// The color the letters draw in: the layer's own, or black or white on its highlight.
    var letterColor: RGBColor {
        guard isHighlighted else {
            return color
        }
        return color.isLight ? .black : .white
    }

    /// Whether there's nothing to draw, which a text layer is never saved with.
    var isBlank: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

nonisolated enum TextLayerAlignment: String, CaseIterable, Codable, Hashable, Sendable {
    case leading
    case center
    case trailing
}

/// A picture over a slide, framed or outlined by an optional border.
nonisolated struct ImageLayer: Codable, Hashable, Sendable {
    /// Always shown whole, at its default crop.
    var image: PlacedImage
    /// The border's width, as a fraction of the image's longer side, so a frame or a sticker's
    /// outline grows and shrinks with it.
    var borderWidth: Double
    var borderColor: RGBColor
    /// The blur's radius, as a fraction of the image's longer side.
    var blur: Double

    /// A frame a twelfth of a picture's side reads as a thick mat without crowding the picture.
    static let maximumBorderWidth = 0.08
    /// A tenth of a picture's side blurs it past recognition.
    static let maximumBlur = 0.1

    init(image: PlacedImage, borderWidth: Double = 0, borderColor: RGBColor = .white, blur: Double = 0) {
        self.image = image
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.blur = blur
    }

    func clamped() -> ImageLayer {
        var layer = self
        layer.borderWidth = min(max(borderWidth, 0), Self.maximumBorderWidth)
        layer.blur = min(max(blur, 0), Self.maximumBlur)
        return layer
    }
}

/// A layer on a slide of a project.
nonisolated struct LayerAddress: Hashable, Identifiable, Sendable {
    let projectID: UUID
    let slideID: UUID
    let layerID: UUID

    var id: Self { self }
}
