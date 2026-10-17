//
//  AspectRatioSheet.swift
//  Carouline
//

import SwiftUI

/// Picks the slide shape a new project starts with.
struct AspectRatioSheet: View {
    let onChoose: (AspectRatio) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                    ForEach(AspectRatio.presets, id: \.self) { ratio in
                        Button {
                            onChoose(ratio)
                            dismiss()
                        } label: {
                            RatioTile(ratio: ratio)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(ratio.spokenRatio) \(ratio.name), \(ratio.uses ?? "")")
                    }
                }
                .padding()
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetCloseItem {
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .foregroundStyle(Color.primary)
        .tint(.accentColor)
    }
}

/// A shape's preview frame, drawn to its proportions in a box every shape shares.
private struct RatioTile: View {
    let ratio: AspectRatio

    var body: some View {
        VStack(spacing: 6) {
            // Solid, so the shape keeps its contrast on the sheet's glass.
            RoundedRectangle(cornerRadius: 6)
                .fill(.tint)
                .aspectRatio(ratio.widthOverHeight, contentMode: .fit)
                .frame(width: 72, height: 72)
                .padding(.bottom, 4)
            Text(ratio.label)
                .font(.headline)
            Text(ratio.uses ?? "")
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        // A plain fill rather than glass, which the sheet's own glass already is.
        .background(.fill.quaternary, in: .rect(cornerRadius: 16))
        .contentShape(.rect(cornerRadius: 16))
        .hoverEffect(.highlight)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AspectRatioSheet { _ in }
        }
}
