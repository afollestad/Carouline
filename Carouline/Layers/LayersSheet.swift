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
    /// Waits for the sheet to come to rest before the strip makes room for it.
    @State private var settling = Settling()
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
    /// Longer than the gap between a drag's frames, so the strip makes room once, where the sheet
    /// comes to rest, rather than following it frame by frame.
    private static let settleDelay = Duration.milliseconds(120)

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
        .environment(\.isLayersSheetFull, height == .large)
        // Measured on screen rather than taken from the detent, so the room includes any gap below
        // a sheet that floats over the bottom safe area.
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .global).minY
        } action: { top in
            settling.run(after: Self.settleDelay) {
                settle(at: top)
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
            // Room for where it's headed, so slides typed on from another height go straight
            // there, rather than to full size until it settles. Not as it goes, which ends the
            // typing too and leaves no room.
            if !isTyping, !settling.isStopped, let restingHeight {
                session.sheetRoom = restingHeight
            }
        }
        .onAppear {
            settling.start()
        }
        .onDisappear {
            settling.stop()
            session.typingLayerID = nil
            session.keyboardRoom = 0
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

    /// Half the strip, which the strip makes room above on a phone, or the system's half height
    /// until the strip has measured itself, as previews and snapshots never do.
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

    /// Makes room for the sheet where it came to rest, once that's the height selected, which a
    /// drag writes back as it lets go. Not partway, where a finger held still mid-drag leaves it,
    /// nor riding the keyboard, whose room the strip takes from the keyboard's own.
    private func settle(at top: CGFloat) {
        let room = SheetHeight.room(stripBottom: session.stripBottom, sheetTop: top)
        guard !isTyping, let restingHeight, SheetHeight.rests(
            at: height,
            room: room,
            typingHeight: Self.typingHeight(at: dynamicTypeSize),
            restingHeight: restingHeight,
            stripHeight: session.stripHeight
        ) else {
            return
        }
        // None at large, which covers the slides however small they'd be, so they're whole again
        // as it's dragged back down.
        session.sheetRoom = height == .large ? 0 : room
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

/// Runs an action once whatever keeps restarting it holds still for a moment, until it's stopped
/// for good, as a sheet's geometry still changes while it goes.
private final class Settling {
    private var task: Task<Void, Never>?
    /// Whether it's stopped for good, as it is once the sheet starts going.
    private(set) var isStopped = false

    func run(after delay: Duration, _ action: @escaping @MainActor () -> Void) {
        task?.cancel()
        guard !isStopped else {
            return
        }
        task = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, self?.isStopped == false else {
                return
            }
            action()
        }
    }

    func start() {
        isStopped = false
    }

    func stop() {
        isStopped = true
        task?.cancel()
        task = nil
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
