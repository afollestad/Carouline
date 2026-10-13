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
    @State private var presenter = PresentationQueue<ProjectPresentation>()
    @State private var stripPosition: StripItem?
    /// The cell the photo picker fills, and the slide's other empty cells when it picks several.
    /// Kept apart from `presenter`, which the picker clears as it closes, possibly before it
    /// hands over the pick.
    @State private var pickTarget: CellAddress?
    @State private var pickLimit = 1
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var session: CropSession
    @State private var layerSession: LayerSession
    /// The style being edited, which the slides draw while the style sheet is open.
    @State private var styleDraft: SlideStyle?
    /// Photos already tried quietly, so one whose original is gone isn't tried on every redraw.
    @State private var quietRestores: Set<UUID> = []
    @Environment(\.photoLibrary) private var photoLibrary
    /// The text size outside the strip, which caps its own, for the layers sheet it presents.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    #if DEBUG
    @Environment(DebugSettings.self) private var debug: DebugSettings?
    #endif

    /// `selection`, when given, opens with that photo selected to frame, and `layerSession`
    /// with its layer selected, as snapshots need.
    init(library: ProjectLibrary, projectID: UUID, selection: CellAddress? = nil, layerSession: LayerSession = LayerSession()) {
        self.library = library
        self.projectID = projectID
        _session = State(initialValue: CropSession(selection: selection))
        _layerSession = State(initialValue: layerSession)
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
            .modifier(SelectionBarOverlay(
                library: library,
                session: session,
                onChoosePhoto: { selection in
                    // Saved first, so the replacement doesn't inherit an unsaved zoom.
                    saveLiveCrop()
                    choosePhotos(for: selection)
                },
                onTakePhoto: { selection in
                    saveLiveCrop()
                    presenter.present(.camera(selection))
                },
                onRemove: { selection in
                    select(nil)
                    withAnimation {
                        library.removePhoto(at: selection)
                    }
                },
                onCommitZoom: saveLiveCrop,
                onDone: { select(nil) }
            ))
            .modifier(LayerBarOverlay(
                project: shown,
                session: layerSession,
                actions: layerActions,
                onCommitSize: saveLivePlacement,
                onDone: { selectLayer(nil) }
            ))
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
            // The only presentation with no content to call `presentPending()` as it goes, which
            // it needn't, since it covers the screen and nothing can be asked for behind it.
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
    private func isPresenting(_ shown: ProjectPresentation) -> Binding<Bool> {
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
            layerSession: layerSession,
            layerActions: layerActions,
            layersSlideID: layersSlideID,
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

    /// Selects the photo at `address` to frame, or nothing, saving whatever the last photo or
    /// layer was left at, and brings the photo's slide to the middle.
    private func select(_ address: CellAddress?) {
        saveLiveCrop()
        saveLivePlacement()
        if let address {
            followSelection(on: address.slideID, to: nil)
        }
        layerSession.selection = nil
        session.selection = address
        if let address {
            withAnimation {
                stripPosition = .slide(address.slideID)
            }
        }
    }

    /// Selects the layer at `address` to move, size and turn, or none, saving whatever the last
    /// photo or layer was left at, and brings the layer's slide to the middle.
    private func selectLayer(_ address: LayerAddress?) {
        saveLiveCrop()
        saveLivePlacement()
        if let address {
            followSelection(on: address.slideID, to: address)
        }
        session.selection = nil
        layerSession.selection = address
        if let address {
            withAnimation {
                stripPosition = .slide(address.slideID)
            }
        }
    }

    /// Moves an open layer editor on to the layer at `address`, or back to the list for a photo or
    /// a layer with no editor, saving the draft first, so edits never land on the wrong layer. A
    /// selection on another slide than the sheet's leaves the editor be.
    private func followSelection(on slideID: UUID, to address: LayerAddress?) {
        guard slideID == layersSlideID, let draftLayerID = layerSession.draftLayerID, draftLayerID != address?.layerID,
              !layerSession.sheetPath.isEmpty else {
            return
        }
        layerSession.saveDraft(to: library, projectID: projectID)
        let layer = address.flatMap { library.layer(at: $0) }
        layerSession.sheetPath = layer.flatMap { LayerActions.canEdit($0) ? [.text($0.id)] : nil } ?? []
    }

    /// Saves a placement the size slider left unsaved, as VoiceOver's adjustments do, since they
    /// never end an edit.
    private func saveLivePlacement() {
        if let selection = layerSession.selection, let livePlacement = layerSession.livePlacement {
            layerSession.commitPlacement(livePlacement, at: selection, to: library)
        }
        layerSession.livePlacement = nil
    }

    private var layersSlideID: UUID? {
        if case .layers(let slideID) = presenter.current { slideID } else { nil }
    }

    private var layerActions: LayerActions {
        ProjectLayerActions(
            library: library,
            projectID: projectID,
            session: layerSession,
            presenter: $presenter,
            dynamicTypeSize: dynamicTypeSize,
            select: selectLayer
        )
        .actions
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
        SlideLayoutSheet(library: library, project: project, purpose: purpose) { slideID, isFirst in
            if isFirst {
                // The strip appears with its first slide in the middle already, and a scroll as
                // it appears would push the slides down until the next scroll.
                stripPosition = nil
            } else {
                withAnimation {
                    stripPosition = .slide(slideID)
                }
            }
        }
    }

    #if DEBUG
    /// Selects `-DebugSelectCell`'s photo or `-DebugSelectLayer`'s layer, and opens
    /// `-DebugSheet`'s sheet, after a moment, since a presentation on the first frame doesn't
    /// render, and the strip can't scroll to a slide before it has measured the slides.
    private func openDebugSheet() async {
        guard debug?.selectedCell != nil || debug?.selectedLayer != nil || (debug?.sheet).map({ $0 != .newProject }) == true else {
            return
        }
        try? await Task.sleep(for: .milliseconds(500))
        let slides = library.project(projectID)?.slides ?? []
        if let (slide, cell) = debug?.selectedCell, slides.indices.contains(slide) {
            select(CellAddress(projectID: projectID, slideID: slides[slide].id, index: cell))
        }
        if let (slide, layer) = debug?.selectedLayer, slides.indices.contains(slide), slides[slide].layers.indices.contains(layer) {
            selectLayer(LayerAddress(projectID: projectID, slideID: slides[slide].id, layerID: slides[slide].layers[layer].id))
        }
        let layerSlideID = layerSession.selection?.slideID ?? slides.first?.id
        switch debug?.sheet {
        case .export: presenter.present(.export)
        case .layout: presenter.present(.layout(.newSlide))
        case .layers: layerSlideID.map { layerActions.openSheet($0, []) }
        case .addLayer: layerSlideID.map { layerActions.openSheet($0, [.add]) }
        case .editLayer: layerSession.selection.map { layerActions.edit($0) }
        case .newProject, nil: break
        }
    }
    #endif
}

#Preview {
    NavigationStack {
        ProjectScreen(
            library: ProjectLibrary(store: MockProjectStore(), projects: SampleProjects.all),
            projectID: SampleProjects.sampleID(1)
        )
    }
}
