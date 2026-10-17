//
//  CustomRatioPage.swift
//  Carouline
//

import SwiftUI

/// The New Project sheet's page for a ratio and size of the user's own, the size kept to the
/// ratio whichever side is typed.
struct CustomRatioPage: View {
    @Binding var draft: CustomRatioDraft
    /// Whether the sheet is at full height, where it's opaque rather than glass.
    let isFull: Bool
    /// Whether the shape can be saved as a preset, which a newer build's presets file stops.
    let canSave: Bool
    let onCreate: (AspectRatio) -> Void
    @FocusState private var focusedField: NumberField?
    private static let presetNameRow = "presetName"
    /// The focused field's selection, all of its text as it takes focus.
    @State private var selection: TextSelection?

    /// The fields that hold a number, which select all of it as they take focus, so typing
    /// replaces the number rather than adding to it.
    private enum NumberField: Hashable {
        case ratioWidth
        case ratioHeight
        case pixelWidth
        case pixelHeight

        var keyPath: KeyPath<CustomRatioDraft, String> {
            switch self {
            case .ratioWidth: \.ratioWidth
            case .ratioHeight: \.ratioHeight
            case .pixelWidth: \.pixelWidth
            case .pixelHeight: \.pixelHeight
            }
        }

        /// Sets the field's text through the draft's own setter, which sizes the other side to
        /// the ratio.
        func set(_ text: String, in draft: inout CustomRatioDraft) {
            switch self {
            case .ratioWidth: draft.setRatioWidth(text)
            case .ratioHeight: draft.setRatioHeight(text)
            case .pixelWidth: draft.setPixelWidth(text)
            case .pixelHeight: draft.setPixelHeight(text)
            }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section {
                    ShapePreview(draft: draft)
                        .listRowBackground(Color.clear)
                }
                Section {
                    HStack {
                        // Labeled again, since a field with a prompt leaves its title out for VoiceOver.
                        TextField("Ratio width", text: text(.ratioWidth), selection: selection(.ratioWidth), prompt: Text("Width"))
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .ratioWidth)
                            .accessibilityLabel("Ratio width")
                        Text(":")
                            .accessibilityHidden(true)
                        TextField("Ratio height", text: text(.ratioHeight), selection: selection(.ratioHeight), prompt: Text("Height"))
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .ratioHeight)
                            .accessibilityLabel("Ratio height")
                    }
                    .font(.title3)
                    .multilineTextAlignment(.center)
                } header: {
                    header("Ratio")
                } footer: {
                    footer(draft.problems.contains(.ratio) ? CustomRatioDraft.Problem.ratio.message : nil)
                }
                Section {
                    sideRow("Width", field: .pixelWidth)
                    sideRow("Height", field: .pixelHeight)
                } header: {
                    header("Size")
                } footer: {
                    footer(sizeNote)
                }
                if canSave {
                    Section {
                        Toggle("Save as Preset", isOn: $draft.savesPreset)
                        if draft.savesPreset {
                            LabeledContent("Name") {
                                // VoiceOver reads the row's label for it.
                                TextField("Preset name", text: $draft.presetName, prompt: Text("Optional"))
                                    .multilineTextAlignment(.trailing)
                            }
                            .id(Self.presetNameRow)
                        }
                    } header: {
                        header("Preset")
                    } footer: {
                        footer("Saved shapes show under Custom.")
                    }
                }
            }
            // Room between a section's footer and the next one's header, which the default
            // leaves reading as one block.
            .listSectionSpacing(28)
            // The sheet's glass shows through, except at full height, where the sheet is opaque
            // and the rows would be lost on it.
            .scrollContentBackground(isFull ? .visible : .hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focusedField) { _, field in
                selectAll(of: field)
            }
            .onChange(of: draft.savesPreset) { _, savesPreset in
                guard savesPreset else {
                    return
                }
                // Brings the name field that turning it on adds into view, with the note below it,
                // once the list has the field, which it doesn't yet as the switch turns on.
                // Centered, since a bottom anchor stops short of the note: the field is near the
                // list's end, so the list scrolls as far as it goes, bringing the note in too.
                Task {
                    withAnimation {
                        proxy.scrollTo(Self.presetNameRow, anchor: .center)
                    }
                }
            }
        }
        .navigationTitle("Custom Ratio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create", systemImage: "checkmark", role: .confirm) {
                    if let ratio = draft.aspectRatio {
                        onCreate(ratio)
                    }
                }
                .disabled(draft.aspectRatio == nil)
            }
        }
    }

    /// What's wrong with the size, or else how its sides follow the ratio.
    private var sizeNote: String {
        draft.problems.contains(.size) ? CustomRatioDraft.Problem.size.message : "Type either side, and the other follows the ratio."
    }

    private func sideRow(_ title: String, field: NumberField) -> some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField("\(title) in pixels", text: text(field), selection: selection(field))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: field)
                    .accessibilityLabel("in pixels")
                Text("px")
                    .accessibilityHidden(true)
            }
        }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(Color.primary)
    }

    /// In the primary color, since a bright photo through the sheet's glass washes gray out.
    @ViewBuilder
    private func footer(_ text: String?) -> some View {
        if let text {
            Text(text)
                .foregroundStyle(Color.primary)
        }
    }

    private func text(_ field: NumberField) -> Binding<String> {
        Binding {
            draft[keyPath: field.keyPath]
        } set: { text in
            field.set(text, in: &draft)
        }
    }

    /// The selection while `field` has focus, and none otherwise, so one field's selection never
    /// reaches another's text.
    private func selection(_ field: NumberField) -> Binding<TextSelection?> {
        Binding {
            focusedField == field ? selection : nil
        } set: { selection in
            if focusedField == field {
                self.selection = selection
            }
        }
    }

    /// Selects all of `field`'s text as it takes focus, so the first key typed replaces it.
    private func selectAll(of field: NumberField?) {
        guard let field else {
            selection = nil
            return
        }
        let text = draft[keyPath: field.keyPath]
        selection = TextSelection(range: text.startIndex..<text.endIndex)
    }
}

/// The shape the fields make, faded while they make none, with its ratio and size.
private struct ShapePreview: View {
    let draft: CustomRatioDraft

    var body: some View {
        VStack(spacing: 8) {
            // Solid, so the shape keeps its contrast on the sheet's glass.
            RoundedRectangle(cornerRadius: 8)
                .fill(.tint)
                .aspectRatio(draft.previewRatio ?? 1, contentMode: .fit)
                .frame(width: 96, height: 96)
                .opacity(draft.aspectRatio == nil ? 0.35 : 1)
                .accessibilityHidden(true)
            Text(caption)
                .font(.headline)
                .accessibilityLabel(draft.aspectRatio.map { "\($0.spokenRatio), \($0.pixelWidth) by \($0.pixelHeight) pixels" } ?? "")
                .accessibilityHidden(draft.aspectRatio == nil)
        }
        .frame(maxWidth: .infinity)
    }

    /// The ratio and size, the size without grouping, as its fields write it, or a space while
    /// there's no shape, so the row keeps its height.
    private var caption: String {
        guard let ratio = draft.aspectRatio else {
            return " "
        }
        let width = ratio.pixelWidth.formatted(.number.grouping(.never))
        let height = ratio.pixelHeight.formatted(.number.grouping(.never))
        return "\(ratio.label) · \(width) × \(height)"
    }
}

#Preview {
    @Previewable @State var draft = CustomRatioDraft()
    Color.clear
        .sheet(isPresented: .constant(true)) {
            NavigationStack {
                CustomRatioPage(draft: $draft, isFull: false, canSave: true) { _ in }
            }
            .presentationDetents([.medium, .large])
            .foregroundStyle(Color.primary)
            .tint(.accentColor)
        }
}
