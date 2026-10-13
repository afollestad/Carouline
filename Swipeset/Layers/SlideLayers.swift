//
//  SlideLayers.swift
//  Swipeset
//

import SwiftUI

/// A slide's layers over a canvas of `size` spanning `span` slides, each where the export draws
/// it, and clipped to the slide as the export is.
struct SlideLayers: View {
    let layers: [Layer]
    let projectID: UUID
    let span: Int
    /// The slide's background, which a missing picture's placeholder reads on.
    let background: RGBColor
    let size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layers) { layer in
                let frame = LayerGeometry.frame(of: layer, canvas: size, span: span)
                LayerContentView(layer: layer, projectID: projectID, background: background, size: frame.size)
                    .rotationEffect(.radians(layer.placement.rotation))
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        // Drawn, not touched, until layers can be selected.
        .allowsHitTesting(false)
    }
}

/// One layer's content in its unturned frame of `size`, its border or highlight included.
struct LayerContentView: View {
    let layer: Layer
    let projectID: UUID
    let background: RGBColor
    let size: CGSize

    var body: some View {
        switch layer.content {
        case .text(let text):
            TextLayerView(text: text, size: size)
                .accessibilityElement()
                .accessibilityLabel("Text layer, “\(text.text)”")
        case .image(let picture):
            PictureLayerView(picture: picture, projectID: projectID, background: background, size: size)
        }
    }
}

/// Text drawn by the export's own code, scaled from the reference size, so it breaks and sizes
/// exactly as the export does.
private struct TextLayerView: View {
    let text: TextLayer
    let size: CGSize

    var body: some View {
        // Room past the box for a shadow, which a canvas would otherwise clip.
        let fontSize = LayerGeometry.fontSize * LayerGeometry.referenceSlideWidth * scale
        let overflow = (LayerRenderer.shadowOffset + 2 * LayerRenderer.shadowBlur) * fontSize
        Canvas { context, _ in
            context.withCGContext { cgContext in
                LayerRenderer.drawText(text, in: cgContext, box: CGRect(origin: CGPoint(x: overflow, y: overflow), size: size))
            }
        }
        .frame(width: size.width + 2 * overflow, height: size.height + 2 * overflow)
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    /// How much smaller than at the reference size the text draws.
    private var scale: CGFloat {
        let reference = TextLayerLayout.make(for: text).boxSize(isHighlighted: text.isHighlighted)
        return reference.width > 0 ? size.width / reference.width : 0
    }
}

/// A picture in its frame, inside its border, which an opaque picture fills as a ring of its
/// border color.
private struct PictureLayerView: View {
    let picture: ImageLayer
    let projectID: UUID
    let background: RGBColor
    let size: CGSize
    @State private var isMissing = false

    var body: some View {
        let border = LayerGeometry.borderWidth(of: picture, inFrame: size)
        CellPhoto(image: picture.image, projectID: projectID, isMissing: $isMissing) {
            MissingLayerPicture(background: background)
        }
        .frame(width: max(0, size.width - 2 * border), height: max(0, size.height - 2 * border))
        .padding(border)
        .background(picture.image.fileFormat == .jpeg ? picture.borderColor.color : .clear)
        .accessibilityElement()
        .accessibilityLabel(isMissing ? "Image layer, unavailable" : "Image layer")
        .accessibilityAddTraits(isMissing ? [] : .isImage)
    }
}

/// What a picture layer shows when its copy can't be read: the fill a missing photo shows, with
/// a warning.
private struct MissingLayerPicture: View {
    let background: RGBColor

    var body: some View {
        ZStack {
            PlaceholderCell(background: background)
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(Color.secondary)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    let project = SampleProjects.all[0]
    let slide = project.slides[0]
    SlideView(slide: slide, style: project.style)
        .overlay {
            SlideLayers(
                layers: slide.layers,
                projectID: project.id,
                span: slide.span,
                background: project.style.background,
                size: CGSize(width: 320, height: 400)
            )
        }
        .frame(width: 320, height: 400)
}
