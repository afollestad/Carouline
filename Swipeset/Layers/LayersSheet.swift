//
//  LayersSheet.swift
//  Swipeset
//

import SwiftUI

/// One sheet for a slide's layers: the list, the page for adding one, and each kind's editor,
/// pushed onto one navigation stack. Adding and editing share its look and its behavior.
struct LayersSheet: View {
    let library: ProjectLibrary
    let projectID: UUID
    let slideID: UUID
    @Bindable var session: LayerSession
    let actions: LayerActions
    /// The kinds of layer it offers to add.
    let kinds: [LayerKind]
    /// The screen's text size. The strip caps its own, which the sheet, presented from a slide,
    /// would otherwise take, and sheets stay uncapped.
    let dynamicTypeSize: DynamicTypeSize
    /// Runs as the sheet's content goes, once it no longer covers the screen.
    let onGone: () -> Void
    @State private var detent = PresentationDetent.medium
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// Just the text field over the keyboard, so the slide stays in view while it's typed in: 90 pt
    /// for the grabber and the title bar, and 60 for a line of the field, which grows with the text
    /// size, since sheets aren't capped.
    static func typingHeight(at size: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        return 90 + UIFontMetrics(forTextStyle: .title3).scaledValue(for: 60, compatibleWith: traits)
    }
    /// An iPad popover's size: the Style popover's width, and tall enough for the text editor's
    /// field, typefaces and colors without scrolling.
    static let popoverSize = CGSize(width: 380, height: 480)

    var body: some View {
        NavigationStack(path: $session.sheetPath) {
            LayerList(
                library: library,
                projectID: projectID,
                slideID: slideID,
                session: session,
                actions: actions,
                kinds: kinds,
                onAdd: add,
                close: close
            )
            .navigationDestination(for: LayersPage.self) { page in
                switch page {
                case .add:
                    AddLayerPage(kinds: kinds, onAdd: add, close: close)
                case .text(let layerID):
                    TextLayerEditor(
                        layerID: layerID,
                        library: library,
                        projectID: projectID,
                        slideID: slideID,
                        session: session,
                        close: close
                    )
                    // A new page for each layer, even one swapped in where another's was, so each
                    // starts and saves its own draft.
                    .id(layerID)
                }
            }
        }
        .presentationDetents([typingDetent, .medium, .large], selection: $detent)
        // The slides stay in view and in reach above the sheet, so each change shows on them.
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .foregroundStyle(Color.primary)
        .tint(.accentColor)
        .dynamicTypeSize(dynamicTypeSize)
        .onChange(of: session.typingLayerID != nil) { _, isTyping in
            withAnimation {
                detent = isTyping ? typingDetent : .medium
            }
        }
        .onDisappear {
            session.typingLayerID = nil
            session.keyboardRoom = 0
            session.saveDraft(to: library, projectID: projectID)
            onGone()
        }
        // Typing survives the app being closed from the background.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                session.saveDraft(to: library, projectID: projectID, endingEdit: false)
            }
        }
    }

    private var typingDetent: PresentationDetent {
        .height(Self.typingHeight(at: dynamicTypeSize))
    }

    private func close() {
        dismiss()
    }

    /// Adds a layer of `kind`: new text starts as a draft in the middle of the slide, or of a
    /// panorama's middle slide, since its own middle can fall on a cut, and opens in its editor.
    private func add(_ kind: LayerKind) {
        guard let project = library.project(projectID), let slide = project.slides.first(where: { $0.id == slideID }) else {
            return
        }
        switch kind {
        case .text:
            let layer = Layer(
                content: .text(TextLayer(on: project.style.background)),
                placement: LayerPlacement(centerX: Double(slide.span / 2) + 0.5)
            )
            session.saveDraft(to: library, projectID: projectID)
            session.beginDraft(of: layer, on: slideID, isNew: true)
            actions.select(LayerAddress(projectID: projectID, slideID: slideID, layerID: layer.id))
            session.sheetPath = [.text(layer.id)]
        case .image:
            break
        }
    }
}

#Preview {
    let project = SampleProjects.all[0]
    Color.clear
        .sheet(isPresented: .constant(true)) {
            LayersSheet(
                library: ProjectLibrary(store: MockProjectStore(), projects: [project]),
                projectID: project.id,
                slideID: project.slides[0].id,
                session: LayerSession(),
                actions: .preview,
                kinds: [.text],
                dynamicTypeSize: .large
            ) {}
        }
}
