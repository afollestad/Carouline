//
//  SlideLayers.swift
//  Swipeset
//

import SwiftUI

/// What a layer can ask its screen to do.
struct LayerActions {
    /// Selects the layer to move, size and turn it.
    let select: (LayerAddress) -> Void
    let setPlacement: (LayerPlacement, LayerAddress) -> Void
    /// Moves the layer up its slide's stack, or down for a negative offset.
    let move: (LayerAddress, Int) -> Void
    let delete: (LayerAddress) -> Void
    /// Opens the layers sheet at the layer's editor, if its kind has one yet.
    let edit: (LayerAddress) -> Void
    /// Opens the layers sheet for a slide, at its list or past it at the pages given.
    let openSheet: (UUID, [LayersPage]) -> Void
    /// Whether a slide's layers sheet is open, which the slide presents it by.
    let isShowingSheet: (UUID) -> Binding<Bool>
    /// A slide's layers sheet.
    let sheet: (UUID) -> LayersSheet?

    /// Whether `layer` has an editor yet, which `edit` opens.
    static func canEdit(_ layer: Layer) -> Bool {
        LayerKind(of: layer) == .text
    }

    static let preview = LayerActions(
        select: { _ in },
        setPlacement: { _, _ in },
        move: { _, _ in },
        delete: { _ in },
        edit: { _ in },
        openSheet: { _, _ in },
        isShowingSheet: { _ in .constant(false) },
        sheet: { _ in nil }
    )
}

/// How a slide's layers respond on the strip, which thumbnails leave out.
struct LayerInteraction {
    let session: LayerSession
    let actions: LayerActions
    /// The selected layer, when it's on this slide.
    let selectedLayerID: UUID?
    /// Whether a photo or a layer is selected anywhere on the strip, while which a long press is
    /// the start of a drag rather than a menu.
    let isAnythingSelected: Bool
    /// Whether a photo is selected, which drags beneath the layers rather than them taking touches.
    let isPhotoSelected: Bool
    /// Whether the session's draft is on this slide, which then draws it in place of its layer.
    let isDrafting: Bool
}

/// A slide's layers over a canvas of `size` spanning `span` slides, each where the export draws
/// it, and clipped to the slide as the export is.
struct SlideLayers: View {
    let layers: [Layer]
    let projectID: UUID
    let slideID: UUID
    let span: Int
    /// The slide's background, which a missing picture's placeholder reads on.
    let background: RGBColor
    let size: CGSize
    /// Nil draws the layers without taking touches, as thumbnails do.
    var interaction: LayerInteraction?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let interaction, interaction.isDrafting {
                DraftedLayers(slide: self, interaction: interaction)
            } else {
                stack(layers)
            }
            if let interaction, interaction.selectedLayerID != nil {
                SnapGuides(session: interaction.session, canvas: LayerCanvas(size: size, span: span))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .allowsHitTesting(interaction.map { !$0.isPhotoSelected } ?? false)
    }

    /// `layers`, bottom to top, the selected one at its live placement.
    func stack(_ layers: [Layer]) -> some View {
        ForEach(Array(layers.enumerated()), id: \.element.id) { index, layer in
            let position = LayerPosition(index: index, count: layers.count)
            if let interaction, interaction.selectedLayerID == layer.id {
                LiveLayer(layer: layer, position: position, slide: self, interaction: interaction)
            } else {
                PlacedLayer(layer: layer, placement: layer.placement, position: position, slide: self, interaction: interaction)
            }
        }
    }

    func address(of layer: Layer) -> LayerAddress {
        LayerAddress(projectID: projectID, slideID: slideID, layerID: layer.id)
    }
}

/// Where a layer sits in its slide's stack, which its z-order actions need.
private struct LayerPosition {
    let index: Int
    let count: Int

    var isTop: Bool { index == count - 1 }
    var isBottom: Bool { index == 0 }
}

/// The slide's layers with the session's draft in place of its layer, or on top as a new one.
/// Only this view reads the draft, which changes with each keystroke, so typing redraws just the
/// edited slide.
private struct DraftedLayers: View {
    let slide: SlideLayers
    let interaction: LayerInteraction

    var body: some View {
        var layers = slide.layers
        if let draft = interaction.session.draft {
            if let index = layers.firstIndex(where: { $0.id == draft.id }) {
                layers[index].content = draft.content
            } else if interaction.session.isDraftNew {
                layers.append(draft)
            }
        }
        return slide.stack(layers)
    }
}

/// The selected layer, at the placement a gesture is moving it to. Only this view reads the
/// session's live placement, so a gesture redraws it alone.
private struct LiveLayer: View {
    let layer: Layer
    let position: LayerPosition
    let slide: SlideLayers
    let interaction: LayerInteraction

    var body: some View {
        PlacedLayer(
            layer: layer,
            placement: interaction.session.livePlacement ?? layer.placement,
            position: position,
            slide: slide,
            interaction: interaction
        )
    }
}

/// One layer at `placement`, turned about its center, with what it responds to on the strip.
private struct PlacedLayer: View {
    let layer: Layer
    let placement: LayerPlacement
    let position: LayerPosition
    let slide: SlideLayers
    let interaction: LayerInteraction?

    /// A fingertip's target, for text in small type or a small picture.
    private static let minimumTarget: CGFloat = 44

    var body: some View {
        var placed = layer
        placed.placement = placement
        let frame = LayerGeometry.frame(of: placed, canvas: slide.size, span: slide.span)
        let isSelected = interaction?.selectedLayerID == layer.id
        let content = LayerContentView(layer: layer, projectID: slide.projectID, background: slide.background, size: frame.size)
            .overlay {
                // Not around new text with nothing typed yet, which takes no room.
                if isSelected, !frame.isEmpty {
                    // Outside the layer, so it never reads as a picture's border.
                    Rectangle()
                        .stroke(.tint, lineWidth: 2)
                        .padding(-5)
                        .accessibilityHidden(true)
                }
            }
            .rotationEffect(.radians(placement.rotation))
        return accessible(content, isSelected: isSelected)
            .position(x: frame.midX, y: frame.midY)
            .contentShape(
                [.interaction, .contextMenuPreview],
                LayerHitShape(frame: frame, rotation: placement.rotation, minimumSide: Self.minimumTarget)
            )
            .onTapGesture {
                if !isSelected {
                    interaction?.actions.select(slide.address(of: layer))
                } else if LayerActions.canEdit(layer) {
                    interaction?.actions.edit(slide.address(of: layer))
                }
            }
            // No menu while anything's selected, where a long press is the start of a drag, and
            // the bar below offers the same choices.
            .contextMenu {
                if let interaction, !interaction.isAnythingSelected {
                    menu(interaction.actions)
                }
            }
    }

    @ViewBuilder
    private func menu(_ actions: LayerActions) -> some View {
        let address = slide.address(of: layer)
        if LayerActions.canEdit(layer) {
            Button("Edit…", systemImage: "pencil") {
                // Selected too, as a row's tap does, so its slide comes to the middle and its
                // outline shows what the editor edits.
                actions.select(address)
                actions.edit(address)
            }
        }
        Button("Bring Forward", systemImage: "square.2.layers.3d.top.filled") {
            actions.move(address, 1)
        }
        .disabled(position.isTop)
        Button("Send Backward", systemImage: "square.2.layers.3d.bottom.filled") {
            actions.move(address, -1)
        }
        .disabled(position.isBottom)
        Divider()
        Button("Delete Layer", systemImage: "trash", role: .destructive) {
            actions.delete(address)
        }
    }

    /// The layer as one element for VoiceOver, with its menu's choices as actions and, while
    /// it's selected, steps to move, size and turn it in place of gestures. Applied before the
    /// layer is positioned, so its frame is the layer's own rather than the whole slide's.
    private func accessible(_ content: some View, isSelected: Bool) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityHint(isSelected || interaction == nil ? "" : "Selects the layer to move, resize and turn it")
            .accessibilityAction {
                if !isSelected {
                    interaction?.actions.select(slide.address(of: layer))
                }
            }
            .accessibilityActions {
                if let interaction {
                    if isSelected {
                        Button("Move Left") { nudge(interaction, x: -0.05) }
                        Button("Move Right") { nudge(interaction, x: 0.05) }
                        Button("Move Up") { nudge(interaction, y: -0.05) }
                        Button("Move Down") { nudge(interaction, y: 0.05) }
                        Button("Make Bigger") { nudge(interaction, scale: 1.1) }
                        Button("Make Smaller") { nudge(interaction, scale: 1 / 1.1) }
                        Button("Turn Left") { nudge(interaction, rotation: -.pi / 12) }
                        Button("Turn Right") { nudge(interaction, rotation: .pi / 12) }
                    }
                    menu(interaction.actions)
                }
            }
    }

    /// Moves the layer a twentieth of its slide, sizes it by `scale`, or turns it by `rotation`,
    /// for VoiceOver, which can't drag, pinch or twist.
    private func nudge(_ interaction: LayerInteraction, x: Double = 0, y: Double = 0, scale: Double = 1, rotation: Double = 0) {
        var placement = placement
        placement.centerX += x
        placement.centerY += y
        placement.scale *= scale
        placement.rotation += rotation
        interaction.actions.setPlacement(placement, slide.address(of: layer))
    }
}

/// Where a layer takes touches, in its slide's space: its turned box, grown to a fingertip's
/// target, and cut to the slide, since clipping hides a layer past the slide's edge but leaves
/// it there to touch.
private struct LayerHitShape: Shape {
    let frame: CGRect
    let rotation: Double
    let minimumSide: CGFloat

    func path(in rect: CGRect) -> Path {
        let grownX = max(0, (minimumSide - frame.width) / 2)
        let grownY = max(0, (minimumSide - frame.height) / 2)
        let box = frame.insetBy(dx: -grownX, dy: -grownY)
        let turn = CGAffineTransform(translationX: box.midX, y: box.midY)
            .rotated(by: rotation)
            .translatedBy(x: -box.midX, y: -box.midY)
        return Path(box).applying(turn).intersection(Path(rect))
    }
}

/// The guides a moving layer has snapped to: a line across the slide on each axis it's centered
/// on, drawn twice like the panorama's seams so it shows on any photo.
private struct SnapGuides: View {
    let session: LayerSession
    let canvas: LayerCanvas

    var body: some View {
        ZStack {
            GuideLines(snap: session.snap, canvas: canvas)
                .stroke(.black.opacity(0.35), lineWidth: 3)
            GuideLines(snap: session.snap, canvas: canvas)
                .stroke(.tint, lineWidth: 1.5)
        }
        .frame(width: canvas.size.width, height: canvas.size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct GuideLines: Shape {
    let snap: LayerSnap
    let canvas: LayerCanvas

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if let guideX = snap.guideX {
            let x = rect.minX + guideX * canvas.slideWidth
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        if let guideY = snap.guideY {
            let y = rect.minY + guideY * rect.height
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
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
                // New text has nothing to read out until it's typed.
                .accessibilityLabel(text.isBlank ? "Text layer, empty" : "Text layer, “\(text.text)”")
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
    let slide = project.slides[2]
    SlideView(slide: slide, style: project.style)
        .overlay {
            SlideLayers(
                layers: slide.layers,
                projectID: project.id,
                slideID: slide.id,
                span: slide.span,
                background: project.style.background,
                size: CGSize(width: 320, height: 400),
                interaction: LayerInteraction(
                    session: LayerSession(selection: LayerAddress(projectID: project.id, slideID: slide.id, layerID: slide.layers[0].id)),
                    actions: .preview,
                    selectedLayerID: slide.layers[0].id,
                    isAnythingSelected: true,
                    isPhotoSelected: false,
                    isDrafting: false
                )
            )
        }
        .frame(width: 320, height: 400)
}
