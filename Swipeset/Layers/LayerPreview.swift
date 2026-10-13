//
//  LayerPreview.swift
//  Swipeset
//

import SwiftUI

/// A layer drawn small, as the layer list's rows show it: text as "Aa" in its typeface, in the
/// primary color, which stays legible on the sheet's glass whatever the text's, or the picture
/// with its border but not its blur, which would leave too little at this size to tell it by.
struct LayerPreview: View {
    let layer: Layer
    let projectID: UUID

    /// The tile's side, a list row's icon size.
    static let side: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            // A plain fill rather than glass, which the sheet's own glass already is.
            .fill(.fill.quaternary)
            .overlay {
                content
            }
            .clipShape(.rect(cornerRadius: 10))
            .frame(width: Self.side, height: Self.side)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch layer.content {
        case .text(let text):
            Text("Aa")
                .font(Font(text.font.uiFont(size: 20) as CTFont))
                .foregroundStyle(Color.primary)
        case .image(let picture):
            let size = LayerGeometry.size(of: Layer(content: layer.content), slideWidth: 1)
            let fitted = Self.fitted(size, in: Self.side - 10)
            LayerContentView(layer: Self.unblurred(layer), projectID: projectID, background: .white, size: fitted)
                .frame(width: fitted.width, height: fitted.height)
                .id(picture.image.id)
        }
    }

    /// `layer` without its blur.
    private static func unblurred(_ layer: Layer) -> Layer {
        var layer = layer
        if case .image(var picture) = layer.content {
            picture.blur = 0
            layer.content = .image(picture)
        }
        return layer
    }

    /// `size` scaled to fit a square of `side`.
    private static func fitted(_ size: CGSize, in side: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: side, height: side)
        }
        let scale = side / max(size.width, size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

#Preview {
    let project = SampleProjects.all[0]
    HStack(spacing: 12) {
        ForEach(project.slides.flatMap(\.layers)) { layer in
            LayerPreview(layer: layer, projectID: project.id)
        }
    }
    .padding()
}
