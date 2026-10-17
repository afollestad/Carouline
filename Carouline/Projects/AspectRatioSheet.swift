//
//  AspectRatioSheet.swift
//  Carouline
//

import SwiftUI

/// Picks the slide shape a new project starts with: a preset, or a ratio and size of the user's
/// own.
struct AspectRatioSheet: View {
    let onChoose: (AspectRatio) -> Void
    @State private var path: [Page]
    @State private var detent: PresentationDetent
    /// The custom page's fields, kept while the sheet is open, so going back to the presets
    /// doesn't lose what was typed.
    @State private var draft: CustomRatioDraft
    @Environment(\.dismiss) private var dismiss

    private enum Page: Hashable {
        case custom
    }

    /// Opens on the custom page with `draft`, when it's given, as snapshots and
    /// `-DebugSheet customRatio` need.
    init(startsOnCustom draft: CustomRatioDraft? = nil, onChoose: @escaping (AspectRatio) -> Void) {
        self.onChoose = onChoose
        _path = State(initialValue: draft == nil ? [] : [.custom])
        _detent = State(initialValue: draft == nil ? .medium : .large)
        _draft = State(initialValue: draft ?? CustomRatioDraft())
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                    Section {
                        ForEach(AspectRatio.presets, id: \.self) { ratio in
                            Button {
                                choose(ratio)
                            } label: {
                                RatioTile(title: ratio.label, caption: ratio.uses ?? "") {
                                    // Solid, so the shape keeps its contrast on the sheet's glass.
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.tint)
                                        .aspectRatio(ratio.widthOverHeight, contentMode: .fit)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(ratio.spokenRatio) \(ratio.name), \(ratio.uses ?? "")")
                        }
                    }
                    Section {
                        Button {
                            path.append(.custom)
                            // Room for every field, which the keyboard would grow it to anyway.
                            detent = .large
                        } label: {
                            RatioTile(title: "New", caption: "Any ratio and size") {
                                NewShape()
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("New custom ratio")
                        .accessibilityHint("Choose your own ratio and export size.")
                    } header: {
                        Text("Custom")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                            .accessibilityAddTraits(.isHeader)
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
            .navigationDestination(for: Page.self) { _ in
                CustomRatioPage(draft: $draft, isFull: detent == .large, onCreate: choose)
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .foregroundStyle(Color.primary)
        .tint(.accentColor)
    }

    /// Creates the project and closes the whole sheet, which a pushed page's own `dismiss` would
    /// only take back a page.
    private func choose(_ ratio: AspectRatio) {
        onChoose(ratio)
        dismiss()
    }
}

/// A shape's tile: its preview frame, drawn in a box every shape shares, over its title and caption.
private struct RatioTile<Preview: View>: View {
    let title: String
    let caption: String
    @ViewBuilder let preview: Preview

    var body: some View {
        VStack(spacing: 6) {
            preview
                .frame(width: 72, height: 72)
                .padding(.bottom, 4)
            Text(title)
                .font(.headline)
            Text(caption)
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

/// An outline to fill with a shape of the user's own. In the primary color, since a thin line or a
/// glyph in the accent washes out on the sheet's glass.
private struct NewShape: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
        }
        .foregroundStyle(Color.primary)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AspectRatioSheet { _ in }
        }
}
