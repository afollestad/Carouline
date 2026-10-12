//
//  StyleSheet.swift
//  Swipeset
//

import SwiftUI

/// The spacing, border and background every slide in a project shares. It edits a draft the
/// slides behind it draw live, and saves when a slider is let go, a color is picked, or it closes.
struct StyleSheet: View {
    @Binding var style: SlideStyle
    let onCommit: () -> Void
    @Environment(\.dismiss) private var dismiss

    /// White and black, which most carousels use, and the icon's lavender and mint.
    private static let swatches: [(name: String, color: RGBColor)] = [
        ("White", .white),
        ("Black", .black),
        ("Lavender", RGBColor(red: 0.93, green: 0.91, blue: 0.99)),
        ("Mint", RGBColor(red: 0.85, green: 0.97, blue: 0.91))
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Spacing") {
                    widthSlider("Spacing", value: $style.spacing, maximum: SlideStyle.maximumSpacing)
                }
                Section("Border") {
                    widthSlider("Border", value: $style.border, maximum: SlideStyle.maximumBorder)
                }
                Section("Background") {
                    ColorPicker("Color", selection: background, supportsOpacity: false)
                    HStack(spacing: 12) {
                        ForEach(Self.swatches, id: \.name) { swatch in
                            SwatchButton(name: swatch.name, color: swatch.color, isSelected: style.background == swatch.color) {
                                style.background = swatch.color
                                onCommit()
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        // The slides stay in view and in reach above the sheet, so each change shows on them.
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .foregroundStyle(Color.primary)
        .tint(.accentColor)
    }

    /// A slider for a share of the slide's width, read out as a percentage.
    private func widthSlider(_ title: String, value: Binding<Double>, maximum: Double) -> some View {
        HStack(spacing: 12) {
            Slider(value: value, in: 0...maximum) {
                Text(title)
            } onEditingChanged: { isEditing in
                if !isEditing {
                    onCommit()
                }
            }
            Text(value.wrappedValue, format: .percent.precision(.fractionLength(1)))
                .monospacedDigit()
                .foregroundStyle(Color.secondary)
                .frame(minWidth: 48, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    private var background: Binding<Color> {
        Binding {
            style.background.color
        } set: { color in
            style.background = RGBColor(UIColor(color))
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
    @Previewable @State var style = SlideStyle.standard
    Color.clear
        .sheet(isPresented: .constant(true)) {
            StyleSheet(style: $style) {}
        }
}
