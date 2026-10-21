//
//  ImageLayerEditor.swift
//  Carouline
//

import SwiftUI

/// The layers sheet's page for a picture layer: its border's style, width and color, which frame
/// an opaque picture and outline a transparent one, its blur and its shadow. It edits the session's
/// draft, which the slide draws as it changes, and saves the draft as a slider is let go and once
/// it closes.
struct ImageLayerEditor: View {
    let layerID: UUID
    let library: ProjectLibrary
    let projectID: UUID
    let slideID: UUID
    let session: LayerSession
    let delete: (LayerAddress) -> Void
    let close: () -> Void

    /// A border's width when its color is picked with none yet, so the pick shows: a print's narrow
    /// margin, or a sticker's die-cut edge.
    static let defaultBorderWidth = 0.03

    var body: some View {
        Form {
            Section("Border") {
                BorderStylePicker(
                    styles: BorderStyle.offered(on: picture?.image.fileFormat == .png ? .sticker : .photo),
                    selected: picture?.drawnBorderStyle ?? .plain,
                    pick: pickBorderStyle
                )
                PercentSlider(title: "Width", value: binding(\.borderWidth), maximum: ImageLayer.maximumBorderWidth) {
                    session.saveDraft(to: library, projectID: projectID, endingEdit: false)
                }
                ColorSwatches(title: "Color", color: borderColor)
            }
            Section("Blur") {
                // A share of the most, which reads plainer than a share of the picture's side.
                PercentSlider(title: "Blur", value: blur, maximum: 1, fractionLength: 0) {
                    session.saveDraft(to: library, projectID: projectID, endingEdit: false)
                }
            }
            Section {
                Toggle("Shadow", isOn: hasShadow)
            }
        }
        .layerPage(LayerKind.image.name, close: close)
        .modifier(LayerDraftEditing(
            page: .image(layerID),
            address: LayerAddress(projectID: projectID, slideID: slideID, layerID: layerID),
            library: library,
            session: session,
            delete: delete
        ))
    }

    /// The picture layer being edited, or none before its draft begins.
    private var picture: ImageLayer? {
        if case .image(let picture) = session.draftLayer(layerID)?.content {
            return picture
        }
        return nil
    }

    private func binding(_ keyPath: WritableKeyPath<ImageLayer, Double>) -> Binding<Double> {
        Binding {
            picture?[keyPath: keyPath] ?? 0
        } set: { value in
            guard var picture else {
                return
            }
            picture[keyPath: keyPath] = value
            session.draft?.content = .image(picture)
        }
    }

    /// The blur, as a share of the most.
    private var blur: Binding<Double> {
        let blur = binding(\.blur)
        return Binding {
            blur.wrappedValue / ImageLayer.maximumBlur
        } set: { share in
            blur.wrappedValue = share * ImageLayer.maximumBlur
        }
    }

    private var hasShadow: Binding<Bool> {
        Binding {
            picture?.hasShadow ?? false
        } set: { hasShadow in
            guard var picture else {
                return
            }
            picture.hasShadow = hasShadow
            session.draft?.content = .image(picture)
        }
    }

    /// Sets the border's style, and gives a border with no width one, so picking a style shows it.
    /// Plain leaves the width be, since it's no style to show.
    private func pickBorderStyle(_ style: BorderStyle) {
        guard var picture else {
            return
        }
        picture.borderStyle = style
        if style != .plain, picture.borderWidth == 0 {
            picture.borderWidth = Self.defaultBorderWidth
        }
        session.draft?.content = .image(picture)
    }

    /// The border's color, which also gives a border with no width one, so picking a color shows it.
    private var borderColor: Binding<RGBColor> {
        Binding {
            picture?.borderColor ?? .white
        } set: { color in
            guard var picture else {
                return
            }
            picture.borderColor = color
            if picture.borderWidth == 0 {
                picture.borderWidth = Self.defaultBorderWidth
            }
            session.draft?.content = .image(picture)
        }
    }
}

#Preview {
    let layer = Layer(content: .image(ImageLayer(
        image: PlacedImage(assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 1536),
        borderWidth: 0.04,
        hasShadow: true
    )))
    let session = LayerSession()
    let slideID = UUID()
    NavigationStack {
        ImageLayerEditor(
            layerID: layer.id,
            library: ProjectLibrary(store: MockProjectStore(), projects: []),
            projectID: UUID(),
            slideID: slideID,
            session: session,
            delete: { _ in },
            close: {}
        )
    }
    .tint(.accentColor)
    .onAppear {
        session.beginDraft(of: layer, on: slideID)
    }
}
