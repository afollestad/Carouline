//
//  LayoutSheet.swift
//  Swipeset
//

import SwiftUI

/// Picks the layout for a new slide, or a new one for an existing slide.
struct LayoutSheet: View {
    let aspectRatio: AspectRatio
    /// The slide's layout when changing one, marked as the starting point.
    let current: SlideLayout?
    /// How many photos a layout would remove, which the sheet asks about before choosing it.
    let photosLost: (SlideLayout) -> Int
    let onChoose: (SlideLayout) -> Void
    @State private var pendingLayout: SlideLayout?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: 12)], spacing: 12) {
                    ForEach(SlideLayout.allCases) { layout in
                        Button {
                            choose(layout)
                        } label: {
                            LayoutTile(layout: layout, previewSize: previewSize, isCurrent: layout == current)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(layout.name)
                        .accessibilityHint(layout == .panorama ? "One photo across several slides that swipe as one image" : "")
                        .accessibilityAddTraits(layout == current ? .isSelected : [])
                    }
                }
                .padding()
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle(current == nil ? "New Slide" : "Change Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetCloseItem {
                    dismiss()
                }
            }
            .confirmationDialog(
                pendingTitle,
                isPresented: Binding { pendingLayout != nil } set: { if !$0 { pendingLayout = nil } },
                titleVisibility: .visible,
                presenting: pendingLayout
            ) { layout in
                Button("Change Layout", role: .destructive) {
                    finish(layout)
                }
            } message: { layout in
                let count = layout.grid.cells.count
                Text("“\(layout.name)” holds \(count == 1 ? "1 photo" : "\(count) photos"), so the slide's last ones are removed.")
            }
        }
        .presentationDetents([.medium, .large])
        .foregroundStyle(Color.primary)
        .tint(.accentColor)
    }

    /// Small enough that a row fits three portrait tiles on an iPhone, and capped by width so a
    /// landscape tile doesn't take a row to itself.
    private var previewSize: CGSize {
        let ratio = aspectRatio.widthOverHeight
        let height = min(96, 150 / ratio)
        return CGSize(width: height * ratio, height: height)
    }

    private var tileWidth: CGFloat {
        max(previewSize.width + 24, 96)
    }

    private var pendingTitle: String {
        guard let pendingLayout else {
            return ""
        }
        let count = photosLost(pendingLayout)
        return count == 1 ? "Remove 1 Photo?" : "Remove \(count) Photos?"
    }

    private func choose(_ layout: SlideLayout) {
        if layout == current {
            dismiss()
        } else if photosLost(layout) > 0 {
            pendingLayout = layout
        } else {
            finish(layout)
        }
    }

    private func finish(_ layout: SlideLayout) {
        onChoose(layout)
        dismiss()
    }
}

/// A layout drawn as tinted cells on the tile, with gaps wide enough to read at this size
/// whatever the project's own spacing, or a panorama as a band cut into slides.
private struct LayoutTile: View {
    private static let diagramStyle = SlideStyle(spacing: 0.06, border: 0, background: .white)

    let layout: SlideLayout
    let previewSize: CGSize
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 8) {
            diagram
                .frame(width: previewSize.width, height: previewSize.height)
                .accessibilityHidden(true)
            Text(layout.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.fill.quaternary, in: .rect(cornerRadius: 16))
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.tint, lineWidth: 2)
            }
        }
        .contentShape(.rect(cornerRadius: 16))
        .hoverEffect(.highlight)
    }

    @ViewBuilder
    private var diagram: some View {
        if layout == .panorama {
            // As wide as a slide's tile, and as tall as a default panorama of these slides.
            RoundedRectangle(cornerRadius: 3)
                .fill(.tint)
                .overlay {
                    SeamLines(span: Slide.defaultPanoramaSpan)
                        .stroke(.white, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
                .frame(height: previewSize.height / CGFloat(Slide.defaultPanoramaSpan))
        } else {
            SlideCells(layout: layout, style: Self.diagramStyle) {
                // Solid, so the cells keep their contrast on the sheet's glass.
                ForEach(layout.grid.cells.indices, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.tint)
                }
            }
        }
    }
}

#Preview("New") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            LayoutSheet(aspectRatio: .portrait, current: nil) { _ in 0 } onChoose: { _ in }
        }
}

#Preview("Change Panorama") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            LayoutSheet(aspectRatio: .portrait, current: .panorama) { _ in 0 } onChoose: { _ in }
        }
}

#Preview("Change") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            LayoutSheet(aspectRatio: .landscape, current: .grid) { _ in 1 } onChoose: { _ in }
        }
}
