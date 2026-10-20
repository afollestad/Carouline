//
//  LayersSheet.swift
//  Carouline
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
    /// The screen's text size. The strip caps its own, which an iPad's popover, presented from a
    /// slide, would otherwise take, and sheets stay uncapped.
    let dynamicTypeSize: DynamicTypeSize
    /// Runs as the sheet's content goes, once it no longer covers the screen.
    let onGone: () -> Void
    @State private var height = SheetHeight.resting
    /// Whether the sheet's content has gone, after which neither its geometry, still changing as
    /// it goes, nor typing ending with it makes room.
    @State private var isGone = false
    /// Whether typing has ended and the sheet is headed for its resting height, which the strip
    /// makes room for before it gets there.
    @State private var awaitsRest = false
    /// The sheet's top on screen as last measured, to make room from again once the strip changes
    /// size, as on a turn, which can measure the strip's new bottom after the sheet's new top.
    @State private var measuredTop = MeasuredTop()
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
    /// More than a fast drag moves the sheet between two frames, and less than it jumps as it
    /// opens, closes or snaps to a height, so a drag's steps land at once and a jump animates.
    private static let dragStep: CGFloat = 30

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
                        delete: actions.delete,
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
                        delete: actions.delete,
                        close: close
                    )
                    .id(layerID)
                }
            }
        }
        .environment(\.isLayersSheetFull, height == .large)
        // Measured on screen rather than worked out from the detent and the keyboard's height, since
        // the sheet floats over the bottom safe area and the keyboard by margins of its own, and so
        // the slides follow a drag.
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .global).minY
        } action: { top in
            measuredTop.value = top
            follow(top)
        }
        .onChange(of: session.stripHeight) {
            if let top = measuredTop.value {
                follow(top)
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
        .presentationDetents(detents, selection: detent)
        // A swipe scrolls down to the slide's style, below its layers, or past a field being typed
        // in to its typefaces, rather than growing the sheet over the slide it changes.
        .presentationContentInteraction(.scrolls)
        // The slides stay in view and in reach above the sheet, so each change shows on them.
        .presentationBackgroundInteraction(.enabled(upThrough: restingDetent))
        .foregroundStyle(Color.primary)
        .tint(.accentColor)
        .dynamicTypeSize(dynamicTypeSize)
        .onChange(of: isTyping) { _, isTyping in
            withAnimation {
                height = isTyping ? .typing : .resting
            }
            guard let restingHeight else {
                return
            }
            if isTyping {
                // No more than the resting room until the sheet rides the keyboard, rather than the
                // large height's, which would keep the slide typed on tiny until then, or throughout
                // if no keyboard shows.
                session.sheetRoom = min(session.sheetRoom, restingHeight)
            } else if !isGone {
                // Room for where it's headed, so slides typed on from another height go straight
                // there, rather than to wherever the sheet passes on its way. Not as it goes,
                // which ends the typing too and leaves no room.
                session.sheetRoom = restingHeight
                awaitsRest = true
            }
        }
        // A sheet dragged elsewhere before it rests is followed from there.
        .onChange(of: height) { _, height in
            if height != .resting {
                awaitsRest = false
            }
        }
        .onAppear {
            isGone = false
        }
        .onDisappear {
            isGone = true
            session.typingLayerID = nil
            session.sheetRoom = 0
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

    /// A share of the strip, which the strip makes room above, or the system's half height until
    /// the strip has measured itself, as previews and snapshots never do.
    private var restingDetent: PresentationDetent {
        restingHeight.map { .height($0) } ?? .medium
    }

    private var restingHeight: CGFloat? {
        SheetHeight.restingHeight(stripHeight: session.stripHeight, typingHeight: Self.typingHeight(at: dynamicTypeSize))
    }

    /// Just the text field's height while it's typed in, since the keyboard grows a sheet to the
    /// largest it offers as it shows, over the slide, whichever is selected. The slides behind stay
    /// dimmed then, as a sheet without its resting height to be undimmed through dims them.
    private var detents: Set<PresentationDetent> {
        isTyping ? [typingDetent] : [typingDetent, restingDetent, .large]
    }

    /// `height` as a detent, always one of `detents`, which the selection must be: the typing
    /// height while text is typed, even before `height` follows. A detent read back from a drag
    /// maps to its height, a resting height no taller than the typing one, or one left from a strip
    /// of another size, to resting.
    private var detent: Binding<PresentationDetent> {
        Binding {
            if isTyping {
                return typingDetent
            }
            return switch height {
            case .typing: typingDetent
            case .resting: restingDetent
            case .large: .large
            }
        } set: { detent in
            height = if detent == .large {
                .large
            } else if detent == typingDetent, detent != restingDetent {
                .typing
            } else {
                .resting
            }
        }
    }

    private var isTyping: Bool {
        session.typingLayerID != nil
    }

    private func close() {
        dismiss()
    }

    /// Makes room for the sheet wherever its top is, so the slides grow and shrink as it's dragged
    /// or rides the keyboard. Not while text is typed until the keyboard lifts it, nor on its way
    /// to resting after typing, until it gets there, since UIKit reports it at the heights it
    /// passes as the keyboard comes and goes.
    private func follow(_ top: CGFloat) {
        guard !isGone else {
            return
        }
        let room = SheetHeight.room(stripBottom: session.stripBottom, sheetTop: top)
        if isTyping, !SheetHeight.ridesKeyboard(room: room, typingHeight: Self.typingHeight(at: dynamicTypeSize)) {
            return
        }
        if awaitsRest {
            if let restingHeight, abs(room - restingHeight) > SheetHeight.settlingSlack {
                return
            }
            awaitsRest = false
        }
        withTransaction(\.disablesAnimations, abs(room - session.sheetRoom) < Self.dragStep) {
            session.sheetRoom = room
        }
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

/// The sheet's top, kept without redrawing the sheet as it changes, as it does each frame of a drag.
private final class MeasuredTop {
    var value: CGFloat?
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
