//
//  ProjectScreen.swift
//  Swipeset
//

import PhotosUI
import SwiftUI

/// A project's slides, where they're added, arranged and filled.
struct ProjectScreen: View {
    let library: ProjectLibrary
    let projectID: UUID
    /// What's open over the screen. Asks go through it, since one made while another is up
    /// never shows.
    @State private var presenter = PresentationQueue<Presentation>()
    @State private var stripPosition: StripItem?
    /// The cell the photo picker fills, and the slide's other empty cells when it picks several.
    /// Kept apart from `presenter`, which the picker clears as it closes, possibly before it
    /// hands over the pick.
    @State private var pickTarget: CellAddress?
    @State private var pickLimit = 1
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var session: CropSession
    /// The style being edited, which the slides draw while the style sheet is open.
    @State private var styleDraft: SlideStyle?
    /// Photos already tried quietly, so one whose original is gone isn't tried on every redraw.
    @State private var quietRestores: Set<UUID> = []
    @Environment(\.photoLibrary) private var photoLibrary
    #if DEBUG
    @Environment(DebugSettings.self) private var debug: DebugSettings?
    #endif

    /// `selection`, when given, opens with that photo selected to frame, as snapshots need.
    init(library: ProjectLibrary, projectID: UUID, selection: CellAddress? = nil) {
        self.library = library
        self.projectID = projectID
        _session = State(initialValue: CropSession(selection: selection))
    }

    var body: some View {
        if let project = library.project(projectID) {
            content(project)
        } else {
            // Another window deleted it.
            ContentUnavailableView("Project Deleted", systemImage: "trash")
                .background {
                    GlowBackdrop()
                }
        }
    }

    private func content(_ project: Project) -> some View {
        let shown = shown(project)
        let screen = strip(shown)
            .overlay(alignment: .bottom) {
                selectionBar
            }
            .animation(.smooth(duration: 0.25), value: session.selection)
            .sensoryFeedback(.selection, trigger: session.selection) { _, selection in
                selection != nil
            }
            // A selected photo deleted with its slide, or dropped by a new layout, leaves nothing
            // to frame, and nothing to bring the strip's scrolling back.
            .onChange(of: selectedPhotoID) { _, photoID in
                if photoID == nil, session.selection != nil {
                    session.liveCrop = nil
                    session.selection = nil
                }
            }
            .background {
                SlideBackdrop(slide: frontSlide(of: shown), projectID: projectID, style: shown.style, aspectRatio: shown.aspectRatio)
            }
            .navigationTitle(nameBinding)
            .navigationBarTitleDisplayMode(.inline)
            .navigationSubtitle(project.summary)
            .toolbarTitleMenu {
                RenameButton()
            }
            .toolbar {
                toolbar(project)
            }
            .onChange(of: presenter.current == .style) { _, isStyling in
                if !isStyling {
                    saveStyleDraft()
                    styleDraft = nil
                }
            }
        return presentations(over: screen, project: project)
    }

    private func toolbar(_ project: Project) -> ProjectToolbar {
        ProjectToolbar(
            project: project,
            exporter: SlideExporter(paths: library.store.paths),
            isStyling: isPresenting(.style),
            isExporting: isPresenting(.export),
            style: styleDraftBinding(project),
            onStyle: {
                // Not again while it's open, which would drop the unsaved draft.
                if presenter.current != .style {
                    styleDraft = project.style
                }
                presenter.present(.style)
            },
            onShare: {
                select(nil)
                presenter.present(.export)
            },
            onCommitStyle: saveStyleDraft,
            onPopoverGone: { presenter.presentPending() }
        )
    }

    /// The layout sheet, the photo picker and the camera, which open over the screen.
    private func presentations(over screen: some View, project: Project) -> some View {
        screen
            .sheet(item: layoutPurpose) { purpose in
                layoutSheet(for: purpose, in: project)
                    .onDisappear { presenter.presentPending() }
            }
            .photosPicker(
                isPresented: isPresenting(.photoPicker),
                selection: $pickedItems,
                maxSelectionCount: pickLimit,
                // Numbered in the order they're picked, which is the order they fill the cells.
                selectionBehavior: .ordered,
                matching: .images,
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            )
            .onChange(of: pickedItems) { _, items in
                importPicked(items)
            }
            .fullScreenCover(item: cameraTarget) { target in
                CameraPicker { image in
                    Task {
                        await library.importPhoto(into: target, assetIdentifier: nil) { .image(image) }
                    }
                }
                .ignoresSafeArea()
                .onDisappear { presenter.presentPending() }
            }
            #if DEBUG
            .task {
                await openDebugSheet()
            }
            #endif
    }

    /// `project` as the strip draws it, in the style being edited.
    private func shown(_ project: Project) -> Project {
        var project = project
        if let styleDraft {
            project.style = styleDraft
        }
        return project
    }

    /// The slide in the middle of the strip, which lights the backdrop.
    private func frontSlide(of project: Project) -> Slide? {
        switch stripPosition {
        case .slide(let slideID): project.slides.first { $0.id == slideID } ?? project.slides.first
        case .add: project.slides.last
        case nil: project.slides.first
        }
    }

    /// Whether `shown` is open, as a presentation modifier reads and dismisses it. A dismissal
    /// closes `shown` only while it's still open, never one opened since.
    private func isPresenting(_ shown: Presentation) -> Binding<Bool> {
        Binding {
            presenter.current == shown
        } set: { isPresented in
            if !isPresented {
                presenter.dismiss(shown)
            }
        }
    }

    private var layoutPurpose: Binding<LayoutPurpose?> {
        Binding {
            guard case .layout(let purpose) = presenter.current else {
                return nil
            }
            return purpose
        } set: { purpose in
            if purpose == nil {
                presenter.dismiss { if case .layout = $0 { true } else { false } }
            }
        }
    }

    private var cameraTarget: Binding<CellAddress?> {
        Binding {
            guard case .camera(let target) = presenter.current else {
                return nil
            }
            return target
        } set: { target in
            if target == nil {
                presenter.dismiss { if case .camera = $0 { true } else { false } }
            }
        }
    }

    private func styleDraftBinding(_ project: Project) -> Binding<SlideStyle> {
        Binding {
            styleDraft ?? project.style
        } set: { style in
            styleDraft = style
        }
    }

    private func saveStyleDraft() {
        if let styleDraft {
            library.setStyle(styleDraft, of: projectID)
        }
    }

    private func strip(_ project: Project) -> some View {
        let strip = SlideStrip(
            project: project,
            position: $stripPosition,
            importingCells: library.importingCells,
            cellActions: cellActions,
            session: session,
            onBackgroundTap: { select(nil) },
            onAddSlide: { presenter.present(.layout(.newSlide)) },
            onChangeLayout: { presenter.present(.layout(.change($0))) },
            onMove: { slideID, offset in
                withAnimation {
                    library.moveSlide(slideID, in: projectID, by: offset)
                    // Follows the slide, so it stays in front of whoever moved it.
                    stripPosition = .slide(slideID)
                }
            },
            onDelete: { slideID in
                withAnimation {
                    library.deleteSlide(slideID, in: projectID)
                }
            },
            onSetSpan: { slideID, span in
                withAnimation {
                    library.setSpan(span, of: slideID, in: projectID)
                    // Brought to the front, as a move is, should the menu be a neighbor's.
                    stripPosition = .slide(slideID)
                }
            }
        )
        // Slides leave fixed room for their captions and buttons, which larger text overflows.
        return strip.dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var cellActions: CellActions {
        CellActions(
            choosePhoto: { choosePhotos(for: $0) },
            takePhoto: CameraPicker.isAvailable ? { presenter.present(.camera($0)) } : nil,
            removePhoto: { address in
                withAnimation {
                    library.removePhoto(at: address)
                }
            },
            select: { select($0) },
            setCrop: { crop, address in
                library.setCrop(crop, at: address)
            },
            restorePhoto: { address in
                Task {
                    await library.restorePhoto(at: address, from: photoLibrary, asking: true)
                }
            },
            restorePhotoQuietly: { address in
                guard let imageID = library.photo(at: address)?.id, !quietRestores.contains(imageID) else {
                    return
                }
                quietRestores.insert(imageID)
                Task {
                    await library.restorePhoto(at: address, from: photoLibrary, asking: false)
                }
            }
        )
    }

    @ViewBuilder
    private var selectionBar: some View {
        if let selection = session.selection, let photo = library.photo(at: selection) {
            SelectionBar(
                photo: photo,
                session: session,
                hasCamera: CameraPicker.isAvailable,
                onChoosePhoto: {
                    // Saved first, so the replacement doesn't inherit an unsaved zoom.
                    saveLiveCrop()
                    choosePhotos(for: selection)
                },
                onTakePhoto: {
                    saveLiveCrop()
                    presenter.present(.camera(selection))
                },
                onReset: {
                    session.liveCrop = nil
                    library.setCrop(ImageCrop(), at: selection)
                },
                onRemove: {
                    select(nil)
                    withAnimation {
                        library.removePhoto(at: selection)
                    }
                },
                onCommitZoom: saveLiveCrop,
                onDone: { select(nil) }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var selectedPhotoID: UUID? {
        session.selection.flatMap { library.photo(at: $0)?.id }
    }

    /// Selects the photo at `address` to frame, or none, saving whatever the last one was left
    /// at, and brings the photo's slide to the middle.
    private func select(_ address: CellAddress?) {
        saveLiveCrop()
        session.selection = address
        if let address {
            withAnimation {
                stripPosition = .slide(address.slideID)
            }
        }
    }

    /// Saves a crop the zoom slider left unsaved, as VoiceOver's adjustments and `axe slider` do,
    /// since they never end an edit.
    private func saveLiveCrop() {
        if let selection = session.selection, let liveCrop = session.liveCrop {
            library.setCrop(liveCrop, at: selection)
        }
        session.liveCrop = nil
    }

    /// Opens the picker for the cell at `address`, taking as many photos as its slide has empty
    /// cells when it's empty, or one to replace its photo.
    private func choosePhotos(for address: CellAddress) {
        pickTarget = address
        pickLimit = library.pickLimit(for: address)
        presenter.present(.photoPicker)
    }

    /// Copies the picker's photos into the cell it was opened for and, when there are several, the
    /// slide's other empty cells, keeping each photo's library identifier so its copy can be
    /// restored from it.
    private func importPicked(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty, let target = pickTarget else {
            return
        }
        pickedItems = []
        pickTarget = nil
        for (item, address) in zip(items, library.cellsToFill(from: target, count: items.count)) {
            Task {
                await library.importPhoto(into: address, assetIdentifier: item.itemIdentifier) {
                    try await item.loadTransferable(type: PickedPhoto.self).map { .file($0.url) }
                }
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding {
            library.project(projectID)?.name ?? ""
        } set: { name in
            library.rename(projectID, to: name)
        }
    }

    private func layoutSheet(for purpose: LayoutPurpose, in project: Project) -> some View {
        let slide: Slide? = switch purpose {
        case .newSlide: nil
        case .change(let slideID): project.slides.first { $0.id == slideID }
        }
        return LayoutSheet(aspectRatio: project.aspectRatio, current: slide?.layout) { layout in
            slide.map { ProjectLibrary.photosLost(changing: $0, to: layout) } ?? 0
        } onChoose: { layout in
            if let slide {
                library.changeLayout(of: slide.id, in: projectID, to: layout)
            } else {
                let isFirst = library.project(projectID)?.slides.isEmpty ?? false
                guard let slideID = library.addSlide(layout, to: projectID) else {
                    return
                }
                if isFirst {
                    // The strip appears with its first slide in the middle already, and a scroll
                    // as it appears would push the slides down until the next scroll.
                    stripPosition = nil
                } else {
                    withAnimation {
                        stripPosition = .slide(slideID)
                    }
                }
            }
        }
    }

    #if DEBUG
    /// Selects `-DebugSelectCell`'s photo and opens `-DebugSheet`'s sheet after a moment, since a
    /// presentation on the first frame doesn't render, and the strip can't scroll to a photo's
    /// slide before it has measured the slides.
    private func openDebugSheet() async {
        guard debug?.selectedCell != nil || debug?.sheet == .layout || debug?.sheet == .export else {
            return
        }
        try? await Task.sleep(for: .milliseconds(500))
        let slides = library.project(projectID)?.slides ?? []
        if let (slide, cell) = debug?.selectedCell, slides.indices.contains(slide) {
            select(CellAddress(projectID: projectID, slideID: slides[slide].id, index: cell))
        }
        if debug?.sheet == .export {
            presenter.present(.export)
        } else if debug?.sheet == .layout {
            presenter.present(.layout(.newSlide))
        }
    }
    #endif
}

/// What the layout sheet is choosing for.
private enum LayoutPurpose: Hashable, Identifiable {
    case newSlide
    case change(UUID)

    var id: Self { self }
}

/// What the project screen opens over itself.
private enum Presentation: Hashable {
    case layout(LayoutPurpose)
    case photoPicker
    case camera(CellAddress)
    case style
    case export
}

#Preview {
    NavigationStack {
        ProjectScreen(
            library: ProjectLibrary(store: MockProjectStore(), projects: SampleProjects.all),
            projectID: SampleProjects.sampleID(1)
        )
    }
}
