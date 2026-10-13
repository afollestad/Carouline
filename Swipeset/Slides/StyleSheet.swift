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
                    ColorSwatches(title: "Color", color: $style.background, onCommit: onCommit)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetCloseItem {
                    dismiss()
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
                .foregroundStyle(Color.primary)
                .frame(minWidth: 48, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    @Previewable @State var style = SlideStyle.standard
    Color.clear
        .sheet(isPresented: .constant(true)) {
            StyleSheet(style: $style) {}
        }
}
