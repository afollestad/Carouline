//
//  LayerBar.swift
//  Carouline
//

import SwiftUI

/// Glass controls for the selected layer along the bottom of the project screen: restack,
/// straighten or delete it, size it, edit it, and finish. Restacking, straightening and deleting
/// share a menu, which leaves the slider room to move in, as `SelectionBar` does for a photo.
struct LayerBar: View {
    let layer: Layer
    let session: LayerSession
    let isTop: Bool
    let isBottom: Bool
    let onBringForward: () -> Void
    let onSendBackward: () -> Void
    let onStraighten: () -> Void
    let onDelete: () -> Void
    /// Saves the slider's size once it's let go.
    let onCommitSize: () -> Void
    /// Opens the layer's editor.
    let onEdit: () -> Void
    let onDone: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    Button("Bring Forward", systemImage: "square.2.layers.3d.top.filled", action: onBringForward)
                        .disabled(isTop)
                    Button("Send Backward", systemImage: "square.2.layers.3d.bottom.filled", action: onSendBackward)
                        .disabled(isBottom)
                    Button("Straighten", systemImage: "arrow.counterclockwise", action: onStraighten)
                        .disabled(placement.rotation == 0)
                    Divider()
                    Button("Delete Layer", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Label("Layer Options", systemImage: "square.3.layers.3d")
                }
                sizeSlider
                Button("Edit Layer", systemImage: "pencil", action: onEdit)
                    .accessibilityHint(LayerKind(of: layer).editHint)
                Button("Done", systemImage: "checkmark", action: onDone)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
                    .tourTarget(.layerDone)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
        // The bar's width holds the controls, not more text.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var placement: LayerPlacement {
        session.livePlacement ?? layer.placement
    }

    /// Slides along the scale's logarithm, so halving and doubling take the same distance and
    /// small sizes get as much of the track as large ones.
    private var sizeSlider: some View {
        let scales = LayerGeometry.scales(of: layer)
        return Slider(value: size, in: log2(scales.lowerBound)...log2(scales.upperBound)) {
            Text("Size")
        } onEditingChanged: { isEditing in
            if !isEditing {
                onCommitSize()
            }
        }
        .accessibilityValue(Text(placement.scale, format: .percent.precision(.fractionLength(0))))
        .padding(.horizontal, 16)
        .frame(height: 48)
        .glassEffect(.regular, in: Capsule())
    }

    private var size: Binding<Double> {
        Binding {
            log2(placement.scale)
        } set: { size in
            var placement = placement
            placement.scale = pow(2, size)
            session.livePlacement = placement
        }
    }
}

#Preview {
    let layer = Layer(content: .text(TextLayer(text: "Lisbon")), placement: LayerPlacement(scale: 1.5, rotation: 0.1))
    VStack {
        Spacer()
        LayerBar(
            layer: layer,
            session: LayerSession(),
            isTop: true,
            isBottom: false,
            onBringForward: {},
            onSendBackward: {},
            onStraighten: {},
            onDelete: {},
            onCommitSize: {},
            onEdit: {},
            onDone: {}
        )
    }
    .background { GlowBackdrop() }
}
