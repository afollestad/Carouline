//
//  AspectRatioSheet.swift
//  Carouline
//

import SwiftUI

/// Picks the slide shape a new project starts with: a preset, a shape saved from the custom page,
/// or a ratio and size of the user's own.
struct AspectRatioSheet: View {
    let presets: CustomPresets
    let onChoose: (AspectRatio) -> Void
    @State private var path: [Page]
    @State private var detent: PresentationDetent
    /// The custom page's fields, kept while the sheet is open, so going back to the presets
    /// doesn't lose what was typed.
    @State private var draft: CustomRatioDraft
    /// Whether the saved shapes show their delete badges.
    @State private var isEditing: Bool
    @Environment(\.dismiss) private var dismiss

    private enum Page: Hashable {
        case custom
    }

    /// Opens on the custom page with `draft`, when it's given, or with the saved shapes being
    /// edited, as snapshots and `-DebugSheet customRatio` need.
    init(
        presets: CustomPresets,
        startsOnCustom draft: CustomRatioDraft? = nil,
        isEditing: Bool = false,
        onChoose: @escaping (AspectRatio) -> Void
    ) {
        self.presets = presets
        self.onChoose = onChoose
        _path = State(initialValue: draft == nil ? [] : [.custom])
        _detent = State(initialValue: draft == nil ? .medium : .large)
        _draft = State(initialValue: draft ?? CustomRatioDraft())
        _isEditing = State(initialValue: isEditing)
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
                                    RatioShape(ratio: ratio)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(ratio.spokenRatio) \(ratio.name), \(ratio.uses ?? "")")
                        }
                        // With the presets until there are saved shapes to give a section of
                        // their own.
                        if presets.presets.isEmpty {
                            newTile
                        }
                    }
                    if !presets.presets.isEmpty {
                        Section {
                            ForEach(presets.presets) { preset in
                                savedTile(preset)
                            }
                            if !isEditing {
                                newTile
                            }
                        } header: {
                            customHeader
                        }
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
                CustomRatioPage(draft: $draft, isFull: detent == .large, canSave: presets.canSave, onCreate: create)
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .foregroundStyle(Color.primary)
        .tint(.accentColor)
    }

    /// The Custom section's title, with Edit for its saved shapes. Done in the solid accent, and
    /// Edit in the primary color, since a faint accent washes out on the sheet's glass.
    private var customHeader: some View {
        HStack {
            Text("Custom")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if isEditing {
                Button("Done") {
                    withAnimation {
                        isEditing = false
                    }
                }
                .buttonStyle(.borderedProminent)
                // The sheet's primary color would draw over the button's own white.
                .foregroundStyle(.white)
            } else {
                Button("Edit") {
                    withAnimation {
                        isEditing = true
                    }
                }
                .buttonStyle(.bordered)
                .tint(Color.primary)
                .accessibilityHint("Shows a delete button on each saved shape.")
            }
        }
        .controlSize(.small)
        // Set apart from the presets above, as a section of its own.
        .padding(.top, 16)
        // Room above the first row for its delete badges, clear of Done.
        .padding(.bottom, 4)
    }

    private func savedTile(_ preset: CustomPreset) -> some View {
        Button {
            choose(preset.aspectRatio)
        } label: {
            RatioTile(title: preset.aspectRatio.label, caption: preset.caption) {
                RatioShape(ratio: preset.aspectRatio)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.spokenLabel)
        .contextMenu {
            Button("Delete Preset", systemImage: "trash", role: .destructive) {
                delete(preset)
            }
            // Red like its title, rather than the sheet's accent, which would wash out on the glass.
            .tint(.red)
        }
        .accessibilityActions {
            Button("Delete") {
                delete(preset)
            }
        }
        // Only the badge takes a touch while editing, which is VoiceOver's way to delete then too.
        .allowsHitTesting(!isEditing)
        .accessibilityHidden(isEditing)
        .overlay(alignment: .topTrailing) {
            if isEditing {
                DeleteBadge(label: "Delete \(preset.spokenLabel)") {
                    delete(preset)
                }
            }
        }
    }

    private var newTile: some View {
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
    }

    /// Saves the shape first, when the custom page asks to, then creates the project with it.
    private func create(_ ratio: AspectRatio) {
        if draft.savesPreset {
            presets.save(ratio, name: draft.presetName)
        }
        choose(ratio)
    }

    /// Creates the project and closes the whole sheet, which a pushed page's own `dismiss` would
    /// only take back a page.
    private func choose(_ ratio: AspectRatio) {
        onChoose(ratio)
        dismiss()
    }

    /// Ends editing with the last saved shape, since nothing's left to delete.
    private func delete(_ preset: CustomPreset) {
        withAnimation {
            presets.delete(preset.id)
            if presets.presets.isEmpty {
                isEditing = false
            }
        }
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

/// A shape drawn to its proportions. Solid, so it keeps its contrast on the sheet's glass.
private struct RatioShape: View {
    let ratio: AspectRatio

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.tint)
            .aspectRatio(ratio.widthOverHeight, contentMode: .fit)
    }
}

/// An outline to fill with a shape of the user's own, smaller than the box the shapes share, so it
/// reads as a button rather than a square slide. In the primary color, since a thin line or a glyph
/// in the accent washes out on the sheet's glass.
private struct NewShape: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
        }
        .frame(width: 56, height: 56)
        .foregroundStyle(Color.primary)
    }
}

/// The button that deletes a saved shape while editing, over its tile's corner: solid red with
/// white on it, so it reads on the glass, in a fingertip's target.
private struct DeleteBadge: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        // Its middle just inside the tile's corner, its target reaching no further than the gap
        // above the tile.
        .offset(x: 14, y: -14)
        .transition(.scale.combined(with: .opacity))
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AspectRatioSheet(presets: CustomPresets(presets: [])) { _ in }
        }
}
