//
//  SlideLayers.swift
//  Carouline
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
    /// Opens the layers sheet at the layer's editor.
    let edit: (LayerAddress) -> Void
    /// Opens the layers sheet for a slide, at its list or past it at the pages given.
    let openSheet: (UUID, [LayersPage]) -> Void
    /// Opens the layers sheet for a slide to add a layer of a kind: a text layer's editor, or the
    /// picker for a picture.
    let addLayer: (UUID, LayerKind) -> Void
    /// Copies a picture onto a slide as a layer, with its library identifier, from what the
    /// picker hands over.
    let importImage: (UUID, String?, @escaping @Sendable () async throws -> PhotoSource?) -> Void
    /// Copies a layer's missing picture in again from the photo library, as the user asked, if
    /// the layer still shows that copy, by its ID.
    let restoreImage: (LayerAddress, UUID) -> Void
    /// Tries that once for each missing copy, as it's shown, without asking for access.
    let restoreImageQuietly: (LayerAddress, UUID) -> Void
    /// Whether a slide's layers sheet is open, which its caption's menu waits out, and an iPad's
    /// slide presents its popover by.
    let isShowingSheet: (UUID) -> Binding<Bool>
    /// Whether a slide presents its layers sheet as a popover pointing at it, as on a wide screen.
    /// On a compact width the screen presents it as a sheet instead.
    let showsPopover: Bool
    /// A slide's layers sheet.
    let sheet: (UUID) -> LayersSheet?

    static let preview = LayerActions(
        select: { _ in },
        setPlacement: { _, _ in },
        move: { _, _ in },
        delete: { _ in },
        edit: { _ in },
        openSheet: { _, _ in },
        addLayer: { _, _ in },
        importImage: { _, _, _ in },
        restoreImage: { _, _ in },
        restoreImageQuietly: { _, _ in },
        isShowingSheet: { _ in .constant(false) },
        showsPopover: false,
        sheet: { _ in nil }
    )
}

/// How a slide's layers respond on the strip, which thumbnails leave out.
struct LayerInteraction {
    let session: LayerSession
    let actions: LayerActions
    /// The selected layer, when it's on this slide.
    let selectedLayerID: UUID?
    /// Whether a photo or a layer is selected anywhere on the strip, while which a finger held down
    /// may start a drag on the selection or a pinch anywhere, rather than a menu.
    let isAnythingSelected: Bool
    /// Whether the session's draft is on this slide, which then draws it in place of its layer, or
    /// on top as a new one.
    let isDrafting: Bool
    /// How many of the slide's points a point on screen covers, which a fingertip's target grows by
    /// while the slides are scaled down.
    var screenPoint: CGFloat = 1
    /// The photo held to put in whichever cell or picture is tapped next, if any. A picture layer
    /// takes one from the tray; any other layer lets the tap through to the cell under it.
    var heldPhoto: HeldPhoto?
    /// Puts the held photo in the picture layer at an address.
    var placeHeld: (LayerAddress) -> Void = { _ in }
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
        // Read as a draft starts and ends, never `draft`, which changes with each keystroke.
        let hasNewDraft = interaction.map { $0.isDrafting && $0.session.isDraftNew } ?? false
        let count = layers.count + (hasNewDraft ? 1 : 0)
        ZStack(alignment: .topLeading) {
            ForEach(Array(layers.enumerated()), id: \.element.id) { index, layer in
                LayerSlot(layer: layer, position: LayerPosition(index: index, count: count), slide: self, interaction: interaction)
            }
            if hasNewDraft, let interaction {
                NewDraftLayer(position: LayerPosition(index: layers.count, count: count), slide: self, interaction: interaction)
            }
            if let interaction, interaction.selectedLayerID != nil {
                SnapGuides(session: interaction.session, canvas: LayerCanvas(size: size, span: span))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        // Even over a selected photo, so a tap on a layer selects it; a drag that starts there
        // still pans the photo, through the strip's selection gesture.
        .allowsHitTesting(interaction != nil)
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

/// One of the slide's layers, drawn by the same view however it's edited or selected, so a
/// picture keeps its state, rather than loading again, as its slide's editor opens and closes and
/// as it's selected. Only the edited layer reads the draft, which changes with each keystroke, and
/// only the selected one the live placement, which changes with each step of a gesture, so each
/// redraws that layer alone. A picture keeps the library's copy, as its draft saves, so a restore
/// made while its editor is open shows.
private struct LayerSlot: View {
    let layer: Layer
    let position: LayerPosition
    let slide: SlideLayers
    let interaction: LayerInteraction?

    var body: some View {
        PlacedLayer(layer: shown, placement: placement, position: position, slide: slide, interaction: interaction)
    }

    private var shown: Layer {
        guard let interaction, interaction.isDrafting, let draft = interaction.session.draftLayer(layer.id) else {
            return layer
        }
        var shown = layer
        shown.content = layer.content.editing(draft.content) ?? layer.content
        return shown
    }

    private var placement: LayerPlacement {
        guard let interaction, interaction.selectedLayerID == layer.id else {
            return layer.placement
        }
        return interaction.session.livePlacement ?? layer.placement
    }
}

/// A new layer's draft, on top of its slide's layers, since the library doesn't have it yet.
/// Nothing once the draft is dropped, while the session still holds that it's new until the sheet
/// goes.
private struct NewDraftLayer: View {
    let position: LayerPosition
    let slide: SlideLayers
    let interaction: LayerInteraction

    var body: some View {
        if let draft = interaction.session.draft {
            LayerSlot(layer: draft, position: position, slide: slide, interaction: interaction)
        }
    }
}

/// One layer at `placement`, turned about its center, with what it responds to on the strip.
private struct PlacedLayer: View {
    let layer: Layer
    let placement: LayerPlacement
    let position: LayerPosition
    let slide: SlideLayers
    let interaction: LayerInteraction?

    var body: some View {
        var placed = layer
        placed.placement = placement
        let frame = LayerGeometry.frame(of: placed, canvas: slide.size, span: slide.span)
        let canvas = LayerCanvas(size: slide.size, span: slide.span, screenPoint: interaction?.screenPoint ?? 1)
        let isSelected = interaction?.selectedLayerID == layer.id
        let content = LayerContentView(layer: layer, projectID: slide.projectID, background: slide.background, size: frame.size)
            .environment(\.missingPictureActions, missingPictureActions)
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
                LayerHitShape(box: LayerGeometry.hitBox(of: placed, on: canvas), rotation: placement.rotation)
            )
            .onTapGesture {
                if takesHeldPhoto {
                    interaction?.placeHeld(slide.address(of: layer))
                } else if !isSelected {
                    interaction?.actions.select(slide.address(of: layer))
                } else {
                    interaction?.actions.edit(slide.address(of: layer))
                }
            }
            // No menu while anything's selected, where a finger held down may start a drag or a
            // pinch, and the bar below offers the same choices, nor while a photo is held.
            .contextMenu {
                if let interaction, !interaction.isAnythingSelected, interaction.heldPhoto == nil {
                    menu(interaction.actions)
                }
            }
            // While a photo is held, only a picture that takes it, so a tap on any other layer
            // reaches the cell under it rather than selecting the layer and letting the photo go.
            .allowsHitTesting(interaction?.heldPhoto == nil || takesHeldPhoto)
    }

    /// Whether a tap puts the held photo in the layer: a picture, with a photo from the tray held.
    private var takesHeldPhoto: Bool {
        guard case .tray = interaction?.heldPhoto, layer.image != nil else {
            return false
        }
        return true
    }

    /// What the picture's placeholder offers, should its copy be missing.
    private var missingPictureActions: MissingPictureActions? {
        guard let actions = interaction?.actions, let image = layer.image else {
            return nil
        }
        let address = slide.address(of: layer)
        return MissingPictureActions(
            canRestore: image.assetIdentifier != nil,
            restore: { actions.restoreImage(address, image.id) },
            restoreQuietly: { actions.restoreImageQuietly(address, image.id) },
            delete: { actions.delete(address) }
        )
    }

    @ViewBuilder
    private func menu(_ actions: LayerActions) -> some View {
        let address = slide.address(of: layer)
        Button("Edit…", systemImage: "pencil") {
            // Selected too, as a row's tap does, so its slide comes to the middle and its
            // outline shows what the editor edits.
            actions.select(address)
            actions.edit(address)
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
            .accessibilityHint(accessibilityHint(isSelected: isSelected))
            .accessibilityAction {
                if takesHeldPhoto {
                    interaction?.placeHeld(slide.address(of: layer))
                } else if !isSelected, interaction?.heldPhoto == nil {
                    interaction?.actions.select(slide.address(of: layer))
                }
            }
            .accessibilityActions {
                if let interaction, interaction.heldPhoto == nil {
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

    private func accessibilityHint(isSelected: Bool) -> String {
        if takesHeldPhoto {
            "Puts the held photo in the picture"
        } else if isSelected || interaction == nil {
            ""
        } else {
            "Selects the layer to move, resize and turn it"
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

/// Where a layer takes taps, in its slide's space: its hit box turned with it, and cut to the
/// slide, since clipping hides a layer past the slide's edge but leaves it there to touch.
private struct LayerHitShape: Shape {
    /// The layer's unturned frame grown to a fingertip's target, from `LayerGeometry.hitBox`.
    let box: CGRect
    let rotation: Double

    func path(in rect: CGRect) -> Path {
        Path(box).applying(LayerGeometry.turn(about: box, by: rotation)).intersection(Path(rect))
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

#Preview {
    let project = SampleProjects.all[0]
    let slide = project.slides[2]
    SlideView(slide: slide, style: slide.style)
        .overlay {
            SlideLayers(
                layers: slide.layers,
                projectID: project.id,
                slideID: slide.id,
                span: slide.span,
                background: slide.style.background,
                size: CGSize(width: 320, height: 400),
                interaction: LayerInteraction(
                    session: LayerSession(selection: LayerAddress(projectID: project.id, slideID: slide.id, layerID: slide.layers[0].id)),
                    actions: .preview,
                    selectedLayerID: slide.layers[0].id,
                    isAnythingSelected: true,
                    isDrafting: false
                )
            )
        }
        .frame(width: 320, height: 400)
}
