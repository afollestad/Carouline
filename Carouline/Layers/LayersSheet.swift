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
    /// Whether the keyboard is on screen or headed there, which UIKit says before it moves the
    /// sheet either way.
    @State private var isKeyboardUp = false
    /// The sheet's top while text is typed with no keyboard up, made room for only once it has
    /// stayed there for `keyboardWait`, since UIKit reports the sheet there before the keyboard
    /// lifts it.
    @State private var unliftedTop: CGFloat?
    /// The picker for a picture to add, opened from the sheet, since one opened from the screen
    /// can't show over it.
    @State private var isPickingImage = false
    @State private var pickedImage: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// Just the text field over the keyboard, so the slide stays in view while it's typed in: the
    /// title bar and the gap under it, the field's row, 55 pt at the default text size and growing
    /// with it, since sheets aren't capped, and a margin under it. Less however far the sheet
    /// shows over the keyboard past its height, as a phone's does.
    static func typingHeight(at size: DynamicTypeSize, margin: CGFloat, bottomInset: CGFloat) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        let fieldRow = UIFontMetrics(forTextStyle: .title3).scaledValue(for: 55, compatibleWith: traits)
        return SheetHeight.contentTop(margin: margin) + fieldRow + margin
            - SheetHeight.reachOverKeyboard(bottomInset: bottomInset)
    }
    /// An iPad popover's size: tall enough for the text editor's field, typefaces and colors
    /// without scrolling.
    static let popoverSize = CGSize(width: 380, height: 451)
    /// More than a fast drag moves the sheet between two frames, and less than it jumps as it
    /// opens, closes or snaps to a height, so a drag's steps land at once and a jump animates.
    private static let dragStep: CGFloat = 30
    /// Longer than the keyboard takes to begin showing as text is typed, so a sheet it hasn't
    /// lifted by then has no keyboard coming, as with a hardware one.
    private static let keyboardWait = Duration.seconds(1)

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
                case .addImage:
                    AddImageLayerPage(
                        library: library,
                        projectID: projectID,
                        slideID: slideID,
                        onAdd: { photo in
                            let source = library.trayCopySource(of: photo, in: projectID)
                            actions.importImage(slideID, photo.image.assetIdentifier) {
                                try await source()
                            }
                        },
                        chooseFromLibrary: { isPickingImage = true },
                        close: close
                    )
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
        .environment(\.layersSheetMargin, session.sheetMargin)
        .background {
            SheetInsetsReader { insets in
                session.sheetMargin = insets.margin
                session.sheetBottomInset = insets.bottom
            }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let screen = notification.object as? UIScreen else {
                return
            }
            isKeyboardUp = frame.intersects(screen.bounds)
        }
        // A sheet the keyboard hasn't lifted by now won't be, so the slides make room for it there.
        .task(id: unliftedTop) {
            guard let top = unliftedTop else {
                return
            }
            try? await Task.sleep(for: Self.keyboardWait)
            if !Task.isCancelled {
                makeRoom(SheetHeight.room(stripBottom: session.stripBottom, sheetTop: top))
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
            // Typing starts with the slides kept where they are until the keyboard lifts the
            // sheet, or doesn't come, and ends with no sheet left waiting for it.
            unliftedTop = nil
            guard !isTyping, !isGone, let restingHeight else {
                return
            }
            // Room for where it's headed, so slides typed on from another height go straight
            // there, rather than to wherever the sheet passes on its way. Not as it goes, which
            // ends the typing too and leaves no room.
            session.sheetRoom = restingHeight
            awaitsRest = true
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
        .task {
            addOnOpening()
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
        .height(typingSheetHeight)
    }

    private var typingSheetHeight: CGFloat {
        Self.typingHeight(at: dynamicTypeSize, margin: session.sheetMargin, bottomInset: session.sheetBottomInset)
    }

    /// A share of the strip, which the strip makes room above, or the system's half height until
    /// the strip has measured itself, as previews and snapshots never do.
    private var restingDetent: PresentationDetent {
        restingHeight.map { .height($0) } ?? .medium
    }

    private var restingHeight: CGFloat? {
        SheetHeight.restingHeight(
            stripHeight: session.stripHeight,
            typingHeight: typingSheetHeight,
            margin: session.sheetMargin
        )
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
    /// or rides the keyboard. While text is typed, at once only with the keyboard up, as UIKit
    /// reports the sheet where it waits before the keyboard lifts it and again as the keyboard
    /// goes, and otherwise once it stays there. Nor on its way to resting after typing, until it
    /// gets there, as UIKit reports the heights it passes.
    private func follow(_ top: CGFloat) {
        guard !isGone else {
            return
        }
        if isTyping {
            guard isKeyboardUp else {
                unliftedTop = top
                return
            }
            unliftedTop = nil
        }
        let room = SheetHeight.room(stripBottom: session.stripBottom, sheetTop: top)
        if awaitsRest {
            if let restingHeight, abs(room - restingHeight) > SheetHeight.settlingSlack {
                return
            }
            awaitsRest = false
        }
        makeRoom(room)
    }

    /// Makes `room` for the sheet: at once for a drag's small steps, and animated for a jump.
    private func makeRoom(_ room: CGFloat) {
        withTransaction(\.disablesAnimations, abs(room - session.sheetRoom) < Self.dragStep) {
            session.sheetRoom = room
        }
    }

    /// Starts adding the layer the sheet was opened to add, if any.
    private func addOnOpening() {
        guard let kind = session.addsOnOpening else {
            return
        }
        session.addsOnOpening = nil
        add(kind)
    }

    /// Adds a layer of `kind`: new text starts as a draft in the middle of the slide, or of the
    /// panorama slide in the middle of the strip, and opens in its editor.
    /// A picture is picked first, on a page of the tray's photos with a way to the library's, and
    /// lands there once it's copied. A page rather than the library's picker at once, which can't
    /// show while the sheet that asks for it is still opening.
    /// A color the picker left unsaved is saved first, so new text reads on it.
    private func add(_ kind: LayerKind) {
        session.endStyling(to: library, projectID: projectID)
        guard let project = library.project(projectID), let slide = project.slides.first(where: { $0.id == slideID }) else {
            return
        }
        switch kind {
        case .text:
            let layer = Layer(
                content: .text(TextLayer(on: slide.style.background)),
                placement: .middle(ofSpan: slide.span, front: session.frontSlideIndex(of: slideID))
            )
            session.saveDraft(to: library, projectID: projectID)
            session.beginDraft(of: layer, on: slideID, isNew: true)
            actions.select(LayerAddress(projectID: projectID, slideID: slideID, layerID: layer.id))
            session.sheetPath = [.text(layer.id)]
        case .image:
            session.sheetPath.append(.addImage)
        }
    }
}

/// The sheet's top, kept without redrawing the sheet as it changes, as it does each frame of a drag.
private final class MeasuredTop {
    var value: CGFloat?
}

/// Reads two insets of the controller showing the sheet: its layout margin, which its lists inset
/// their sections by, 16 on most devices and 20 on the largest phones, and its bottom safe area,
/// which a phone's sheet reaches over past its height and an iPad's has none of. SwiftUI exposes no
/// such margin, and its safe area takes the keyboard in.
private struct SheetInsetsReader: UIViewRepresentable {
    struct Insets: Equatable {
        let margin: CGFloat
        let bottom: CGFloat
    }

    let onChange: (Insets) -> Void

    func makeUIView(context: Context) -> ReaderView {
        ReaderView(onChange: onChange)
    }

    func updateUIView(_ view: ReaderView, context: Context) {
        view.onChange = onChange
    }

    final class ReaderView: UIView {
        var onChange: (Insets) -> Void
        private var reported: Insets?

        init(onChange: @escaping (Insets) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        override func layoutMarginsDidChange() {
            super.layoutMarginsDidChange()
            report()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            report()
        }

        private func report() {
            var responder = next
            while let candidate = responder, !(candidate is UIViewController) {
                responder = candidate.next
            }
            guard let controller = responder as? UIViewController, let view = controller.view else { return }
            let insets = Insets(margin: controller.systemMinimumLayoutMargins.leading, bottom: view.safeAreaInsets.bottom)
            guard insets != reported else { return }
            reported = insets
            // After this layout pass, since the state it sets is read by the view being laid out.
            DispatchQueue.main.async { [onChange] in onChange(insets) }
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
