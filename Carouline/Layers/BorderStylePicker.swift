//
//  BorderStylePicker.swift
//  Carouline
//

import SwiftUI

/// The border styles on offer, each a small frame drawn with its own edge, in a row that scrolls
/// across its form row.
struct BorderStylePicker: View {
    let styles: [BorderStyle]
    let selected: BorderStyle
    let pick: (BorderStyle) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(styles, id: \.self) { style in
                    BorderStyleTile(style: style, isSelected: style == selected) {
                        pick(style)
                    }
                }
            }
            // Padded rather than given content margins, so the row scrolls edge to edge.
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .listRowInsets(EdgeInsets())
    }
}

/// A border style as a small framed picture, over its name.
private struct BorderStyleTile: View {
    let style: BorderStyle
    let isSelected: Bool
    let action: () -> Void
    /// The font tiles' size, which fits "Postage Stamp" too, growing with the text size, since
    /// sheets aren't capped.
    @ScaledMetric(relativeTo: .caption2) private var width: CGFloat = 84
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 68
    @ScaledMetric(relativeTo: .caption2) private var sampleHeight: CGFloat = 34

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                BorderStyleSample(style: style)
                    .frame(width: sampleHeight * 4 / 3, height: sampleHeight)
                Text(style.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: width, height: height)
            // A plain fill rather than glass, which the sheet's own glass already is.
            .background(.fill.quaternary, in: .rect(cornerRadius: 12))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.tint, lineWidth: 2)
                }
            }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A style's frame around an empty picture, drawn solid in the accent by the layers' own code.
private struct BorderStyleSample: View {
    let style: BorderStyle

    /// A border thicker than a picture's can be, so its edge shows at this size.
    private static let borderWidth = 0.14
    /// A seed whose torn and burnt edges read as such at this size.
    private static let seed = UUID(uuid: (7, 1, 9, 4, 2, 8, 6, 3, 5, 0, 7, 2, 9, 1, 4, 8))

    var body: some View {
        let picture = ImageLayer(
            image: PlacedImage(assetIdentifier: nil, pixelWidth: 4, pixelHeight: 3),
            borderWidth: Self.borderWidth,
            borderStyle: style
        )
        let frame = LayerGeometry.size(of: Layer(content: .image(picture)), slideWidth: 1)
        Canvas { context, size in
            let accent = Color.accentColor.resolve(in: context.environment).cgColor
            context.withCGContext { cgContext in
                let box = CGRect(origin: .zero, size: size)
                let edge = BorderEdge.edge(for: picture, seed: Self.seed)
                    ?? BorderEdge.edge(around: box, keeping: nil, style: .plain, size: 0, seed: Self.seed)
                LayerRenderer.drawEdge(edge, color: accent, in: cgContext, box: box)
                // The picture punched out, so the tile shows through as it.
                cgContext.setBlendMode(.clear)
                cgContext.fill(LayerGeometry.pictureRect(of: picture, inFrame: box))
            }
        }
        .aspectRatio(frame, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#Preview {
    @Previewable @State var selected = BorderStyle.wavy
    Form {
        Section("Border") {
            BorderStylePicker(styles: BorderStyle.allCases, selected: selected) { style in
                selected = style
            }
        }
    }
    .tint(.accentColor)
}
