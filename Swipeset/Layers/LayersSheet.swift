//
//  LayersSheet.swift
//  Swipeset
//

import PhotosUI
import SwiftUI

/// One sheet for a slide's layers: the list, the page for adding one, and each kind's editor,
/// pushed onto one navigation stack. Adding and editing share its look and its behavior.
struct LayersSheet: View {
    let library: ProjectLibrary
    let projectID: UUID
    let slideID: UUID
    @Bindable var session: LayerSession
    let actions: LayerActions
    /// The screen's text size. The strip caps its own, which the sheet, presented from a slide,
    /// would otherwise take, and sheets stay uncapped.
    let dynamicTypeSize: DynamicTypeSize
    /// Runs as the sheet's content goes, once it no longer covers the screen.
    let onGone: () -> Void
    @State private var detent = PresentationDetent.medium
    /// The picker for a picture to add, opened from the sheet, since one opened from the screen
    /// can't show over it.
    @State private var isPickingImage = false
    @State private var pickedImage: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// Just the text field over the keyboard, so the slide stays in view while it's typed in: 90 pt
    /// for the grabber and the title bar, and 60 for a line of the field, which grows with the text
    /// size, since sheets aren't capped.
    static func typingHeight(at size: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        return 90 + UIFontMetrics(forTextStyle: .title3).scaledValue(for: 60, compatibleWith: traits)
    }
    /// An iPad popover's size: tall enough for the text editor's field, typefaces and colors
    /// without scrolling.
    static let popoverSize = CGSize(width: 380, height: 480)

    var body: some View {
        NavigationStack(path: $session.sheetPath) {
            LayerList(
                library: library,
                projectID: projectID,
                slideID: slideID,
                session: session,
                actions: actions,
                onAdd: add,
                close: close
            )
            .navigationDestination(for: LayersPage.self) { page in
                switch page {
                case .add:
                    AddLayerPage(library: library, slideID: slideID, onAdd: add, close: close)
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
                case .image(let layerID):
                    ImageLayerEditor(
                        layerID: layerID,
                        library: library,
                        projectID: projectID,
                        slideID: slideID,
                        session: session,
                        close: close
                    )
                    .id(layerID)
                }
            }
        }
        .photosPicker(
            isPresented: $isPickingImage,
            selection: $pickedImage,
            matching: .images,
            // As stored, so a PNG keeps its transparency.
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        )
        .onChange(of: pickedImage) { _, item in
            guard let item else {
                return
            }
            pickedImage = nil
            actions.importImage(slideID, item.itemIdentifier) {
                try await item.loadTransferable(type: PickedPhoto.self).map { .file($0.url) }
            }
        }
        .presentationDetents(detents, selection: $detent)
        // A swipe scrolls down to the slide's style, below its layers, or past a field being typed
        // in to its typefaces, rather than growing the sheet over the slide it changes.
        .presentationContentInteraction(.scrolls)
        // The slides stay in view and in reach above the sheet, so each change shows on them.
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .foregroundStyle(Color.primary)
        .tint(.accentColor)
        .dynamicTypeSize(dynamicTypeSize)
        .onChange(of: isTyping) { _, isTyping in
            withAnimation {
                detent = isTyping ? typingDetent : .medium
            }
        }
        .onDisappear {
            session.typingLayerID = nil
            session.keyboardRoom = 0
            session.saveDraft(to: library, projectID: projectID)
            session.endStyling(to: library, projectID: projectID)
            onGone()
        }
        // Typing and a slide's blur and style survive the app being closed from the background.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                session.saveDraft(to: library, projectID: projectID, endingEdit: false)
                session.endStyling(to: library, projectID: projectID)
            }
        }
    }

    private var typingDetent: PresentationDetent {
        .height(Self.typingHeight(at: dynamicTypeSize))
    }

    /// Just the text field's height while it's typed in, since the keyboard grows a sheet to the
    /// largest it offers as it shows, over the slide, whichever is selected. The slides behind stay
    /// dimmed then, as a sheet without `.medium` to be undimmed through dims them.
    private var detents: Set<PresentationDetent> {
        isTyping ? [typingDetent] : [typingDetent, .medium, .large]
    }

    private var isTyping: Bool {
        session.typingLayerID != nil
    }

    private func close() {
        dismiss()
    }

    /// Adds a layer of `kind`: new text starts as a draft in the middle of the slide, or of a
    /// panorama's middle slide, since its own middle can fall on a cut, and opens in its editor.
    /// A picture is picked first, and lands there once it's copied. A color the picker left
    /// unsaved is saved first, so new text reads on it.
    private func add(_ kind: LayerKind) {
        session.endStyling(to: library, projectID: projectID)
        guard let project = library.project(projectID), let slide = project.slides.first(where: { $0.id == slideID }) else {
            return
        }
        switch kind {
        case .text:
            let layer = Layer(
                content: .text(TextLayer(on: slide.style.background)),
                placement: .middle(ofSpan: slide.span)
            )
            session.saveDraft(to: library, projectID: projectID)
            session.beginDraft(of: layer, on: slideID, isNew: true)
            actions.select(LayerAddress(projectID: projectID, slideID: slideID, layerID: layer.id))
            session.sheetPath = [.text(layer.id)]
        case .image:
            isPickingImage = true
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
                dynamicTypeSize: .large
            ) {}
        }
}
