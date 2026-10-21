//
//  TextLayerEditor.swift
//  Carouline
//

import SwiftUI

/// The layers sheet's page for a text layer: its words, typeface, color, style and highlight. It
/// edits the session's draft, which the slide draws as it changes, and saves the draft once it
/// closes.
struct TextLayerEditor: View {
    let layerID: UUID
    let library: ProjectLibrary
    let projectID: UUID
    let slideID: UUID
    let session: LayerSession
    let delete: (LayerAddress) -> Void
    let close: () -> Void
    @FocusState private var isTyping: Bool

    var body: some View {
        Form {
            Section {
                TextField("Text", text: binding(\.text), prompt: Text("Type something"), axis: .vertical)
                    .font(.title3)
                    .lineLimit(1...6)
                    .focused($isTyping)
            }
            StyleSections(style: style) { style in
                Section("Font") {
                    fonts(selected: style.font)
                }
                Section("Color") {
                    ColorSwatches(title: "Color", color: binding(\.color, shown: style))
                }
                Section("Style") {
                    Picker("Alignment", selection: binding(\.alignment, shown: style)) {
                        Label("Leading", systemImage: "text.alignleft").tag(TextLayerAlignment.leading)
                        Label("Center", systemImage: "text.aligncenter").tag(TextLayerAlignment.center)
                        Label("Trailing", systemImage: "text.alignright").tag(TextLayerAlignment.trailing)
                    }
                    .pickerStyle(.segmented)
                    .labelStyle(.iconOnly)
                    Toggle("Shadow", isOn: binding(\.hasShadow, shown: style))
                }
                Section {
                    Toggle("Highlight", isOn: binding(\.isHighlighted, shown: style))
                    BorderStylePicker(surface: .highlight, selected: style.highlightStyle.drawn(on: .highlight), pick: pickHighlightStyle)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .layerPage("Text", close: close)
        .toolbar {
            // The return key adds a line, so this is how typing ends. In the title bar, as the
            // list's Done is: a keyboard toolbar covers the bottom of the typing height, so the
            // field scrolls up under the title to clear it.
            if isTyping {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) {
                        isTyping = false
                    }
                }
            }
        }
        .modifier(LayerDraftEditing(
            page: .text(layerID),
            address: LayerAddress(projectID: projectID, slideID: slideID, layerID: layerID),
            library: library,
            session: session,
            delete: delete
        ) {
            // Only its own typing: the next layer's editor may have begun its own already.
            if session.typingLayerID == layerID {
                session.typingLayerID = nil
            }
        })
        .onAppear {
            // A new layer has nothing to show until it's typed.
            if session.isDraftNew, text.isBlank {
                isTyping = true
            }
        }
        .onChange(of: isTyping) { _, isTyping in
            if isTyping {
                session.typingLayerID = layerID
            } else if session.typingLayerID == layerID {
                session.typingLayerID = nil
            }
        }
    }

    /// The text layer being edited, or blank text before its draft begins.
    private var text: TextLayer {
        if case .text(let text) = session.draftLayer(layerID)?.content {
            return text
        }
        return TextLayer()
    }

    /// The text layer's style, its words left out, which changes only as the style does.
    private var style: TextLayer {
        var style = text
        style.text = ""
        return style
    }

    /// The draft's `keyPath`, read from `shown` when it's given rather than from the draft, which
    /// changes with each keystroke and would redraw whatever reads it.
    private func binding<Value>(_ keyPath: WritableKeyPath<TextLayer, Value>, shown: TextLayer? = nil) -> Binding<Value> {
        Binding {
            (shown ?? text)[keyPath: keyPath]
        } set: { value in
            guard session.draftLayerID == layerID, case .text = session.draft?.content else {
                return
            }
            var text = text
            text[keyPath: keyPath] = value
            session.draft?.content = .text(text)
        }
    }

    /// Sets the highlight's style, and highlights text that isn't, so picking a style shows it.
    private func pickHighlightStyle(_ style: BorderStyle) {
        guard session.draftLayerID == layerID, case .text = session.draft?.content else {
            return
        }
        var text = text
        text.highlightStyle = style
        text.isHighlighted = true
        session.draft?.content = .text(text)
    }

    /// Each typeface on offer, drawn in itself.
    private func fonts(selected: LayerFont) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(LayerFont.allCases, id: \.self) { font in
                    FontTile(font: font, isSelected: selected == font) {
                        binding(\.font).wrappedValue = font
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

/// The editor's sections for the text's style, drawn from `style` alone, so they redraw as the
/// style changes rather than with each keystroke. SwiftUI compares it by `==`, as it does a view
/// holding a closure, without `.equatable()`, whose wrapper hides its sections from the form. The
/// setters they're drawn with only write the session's draft, so those kept from an earlier style
/// write it as well.
private struct StyleSections<Content: View>: View, Equatable {
    let style: TextLayer
    @ViewBuilder let content: (TextLayer) -> Content

    var body: some View {
        content(style)
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.style == rhs.style
    }
}

/// A typeface as "Aa" in itself, over its name.
private struct FontTile: View {
    let font: LayerFont
    let isSelected: Bool
    let action: () -> Void
    /// Room for "Aa" over the longest names, "Handwriting" and "Copperplate", growing with the
    /// text size, since sheets aren't capped.
    @ScaledMetric(relativeTo: .caption2) private var width: CGFloat = 84
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 68
    @ScaledMetric(relativeTo: .caption2) private var sampleSize: CGFloat = 24

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("Aa")
                    .font(Font(font.uiFont(size: sampleSize) as CTFont))
                    .lineLimit(1)
                    .accessibilityHidden(true)
                Text(font.name)
                    .font(.caption2)
                    .lineLimit(1)
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
        .accessibilityLabel(font.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    let layer = Layer(content: .text(TextLayer(text: "Lisbon", font: .serif, hasShadow: true)))
    let session = LayerSession()
    let slideID = UUID()
    NavigationStack {
        TextLayerEditor(
            layerID: layer.id,
            library: ProjectLibrary(store: MockProjectStore(), projects: []),
            projectID: UUID(),
            slideID: slideID,
            session: session,
            delete: { _ in },
            close: {}
        )
    }
    .tint(.accentColor)
    .onAppear {
        session.beginDraft(of: layer, on: slideID)
    }
}
