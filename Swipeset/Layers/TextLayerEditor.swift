//
//  TextLayerEditor.swift
//  Swipeset
//

import SwiftUI

/// The layers sheet's page for a text layer: its words, typeface, color and style. It edits the
/// session's draft, which the slide draws as it changes, and saves the draft once it closes.
struct TextLayerEditor: View {
    let layerID: UUID
    let library: ProjectLibrary
    let projectID: UUID
    let slideID: UUID
    let session: LayerSession
    let close: () -> Void
    @FocusState private var isTyping: Bool
    @State private var keyboardHeight: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Form {
            Section {
                TextField("Text", text: binding(\.text), prompt: Text("Type something"), axis: .vertical)
                    .font(.title3)
                    .lineLimit(1...6)
                    .focused($isTyping)
            }
            Section("Font") {
                fonts
            }
            Section("Color") {
                ColorSwatches(title: "Color", color: binding(\.color))
            }
            Section("Style") {
                Picker("Alignment", selection: binding(\.alignment)) {
                    Label("Leading", systemImage: "text.alignleft").tag(TextLayerAlignment.leading)
                    Label("Center", systemImage: "text.aligncenter").tag(TextLayerAlignment.center)
                    Label("Trailing", systemImage: "text.alignright").tag(TextLayerAlignment.trailing)
                }
                .pickerStyle(.segmented)
                .labelStyle(.iconOnly)
                Toggle("Shadow", isOn: binding(\.hasShadow))
                Toggle("Highlight", isOn: binding(\.isHighlighted))
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .layerPage("Text", close: close)
        .toolbar {
            // The return key adds a line, so this is how typing ends.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTyping = false
                }
            }
        }
        .onAppear {
            // Another layer's editor may not have gone yet, and SwiftUI doesn't order the two.
            if session.draftLayerID != layerID {
                session.saveDraft(to: library, projectID: projectID)
            }
            let address = LayerAddress(projectID: projectID, slideID: slideID, layerID: layerID)
            if let layer = library.layer(at: address) {
                session.beginDraft(of: layer, on: slideID)
            }
            // A new layer has nothing to show until it's typed.
            if session.isDraftNew, text.isBlank {
                isTyping = true
            }
        }
        .onDisappear {
            // Not while its page is back in the path, as after switching away and straight back,
            // where the new page for the layer has begun editing it already. Closing the sheet
            // leaves the path be, and the sheet saves then.
            guard !session.sheetPath.contains(.text(layerID)) else {
                return
            }
            // Only its own typing and draft: the next layer's editor may have begun its own already.
            if session.typingLayerID == layerID {
                session.typingLayerID = nil
                session.keyboardRoom = 0
            }
            if session.draftLayerID == layerID {
                session.saveDraft(to: library, projectID: projectID)
            }
        }
        .onChange(of: isTyping) { _, isTyping in
            if isTyping {
                session.typingLayerID = layerID
            } else if session.typingLayerID == layerID {
                session.typingLayerID = nil
            }
            updateKeyboardRoom()
        }
        // A layer deleted while its editor is open, from the slide or with it, leaves nothing to
        // edit. Only its own page goes, since the path may already be on to another layer's.
        .onChange(of: isGone, initial: true) { _, isGone in
            if isGone {
                session.sheetPath.removeAll { $0 == .text(layerID) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            keyboardHeight = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
            updateKeyboardRoom()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
            updateKeyboardRoom()
        }
    }

    /// Whether the layer is in neither the library nor, while it's new, the draft.
    private var isGone: Bool {
        let address = LayerAddress(projectID: projectID, slideID: slideID, layerID: layerID)
        return library.layer(at: address) == nil && !(session.isDraftNew && session.draftLayerID == layerID)
    }

    /// The text layer being edited, or blank text before its draft begins.
    private var text: TextLayer {
        if case .text(let text) = session.draftLayer(layerID)?.content {
            return text
        }
        return TextLayer()
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<TextLayer, Value>) -> Binding<Value> {
        Binding {
            text[keyPath: keyPath]
        } set: { value in
            guard session.draftLayerID == layerID, case .text = session.draft?.content else {
                return
            }
            var text = text
            text[keyPath: keyPath] = value
            session.draft?.content = .text(text)
        }
    }

    /// While typing, room for the keyboard and the short sheet over it, so the slide stays in
    /// view above them.
    private func updateKeyboardRoom() {
        session.keyboardRoom = isTyping ? keyboardHeight + LayersSheet.typingHeight(at: dynamicTypeSize) : 0
    }

    /// Each typeface on offer, drawn in itself.
    private var fonts: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(LayerFont.allCases, id: \.self) { font in
                    FontTile(font: font, isSelected: text.font == font) {
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
            close: {}
        )
    }
    .tint(.accentColor)
    .onAppear {
        session.beginDraft(of: layer, on: slideID)
    }
}
