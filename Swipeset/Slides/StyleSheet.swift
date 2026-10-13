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
                    PercentSlider(title: "Spacing", value: $style.spacing, maximum: SlideStyle.maximumSpacing, onCommit: onCommit)
                }
                Section("Border") {
                    PercentSlider(title: "Border", value: $style.border, maximum: SlideStyle.maximumBorder, onCommit: onCommit)
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
}

#Preview {
    @Previewable @State var style = SlideStyle.standard
    Color.clear
        .sheet(isPresented: .constant(true)) {
            StyleSheet(style: $style) {}
        }
}
