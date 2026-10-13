//
//  ColorSwatches.swift
//  Swipeset
//

import SwiftUI

/// A color picker row and a row of swatches beneath it, as two rows of a form section.
struct ColorSwatches: View {
    let title: String
    @Binding var color: RGBColor
    /// Runs once a color is picked, for a sheet that saves then.
    var onCommit: () -> Void = {}

    /// White and black, which most carousels use, and the icon's lavender and mint.
    static let swatches: [(name: String, color: RGBColor)] = [
        ("White", .white),
        ("Black", .black),
        ("Lavender", RGBColor(red: 0.93, green: 0.91, blue: 0.99)),
        ("Mint", RGBColor(red: 0.85, green: 0.97, blue: 0.91))
    ]

    var body: some View {
        ColorPicker(title, selection: picked, supportsOpacity: false)
        HStack(spacing: 12) {
            ForEach(Self.swatches, id: \.name) { swatch in
                SwatchButton(name: swatch.name, color: swatch.color, isSelected: color == swatch.color) {
                    color = swatch.color
                    onCommit()
                }
            }
        }
    }

    private var picked: Binding<Color> {
        Binding {
            color.color
        } set: { picked in
            color = RGBColor(UIColor(picked))
            onCommit()
        }
    }
}

private struct SwatchButton: View {
    let name: String
    let color: RGBColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.color)
                .overlay {
                    Circle()
                        .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator), lineWidth: isSelected ? 3 : 1)
                }
                .frame(width: 36, height: 36)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var color = RGBColor.white
    Form {
        Section("Background") {
            ColorSwatches(title: "Color", color: $color)
        }
    }
}
