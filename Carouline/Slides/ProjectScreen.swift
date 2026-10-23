//
//  ProjectScreen.swift
//  Carouline
//

import SwiftUI

/// A project's slides, where they're added, arranged and filled.
struct ProjectScreen: View {
    let library: ProjectLibrary
    let projectID: UUID
    /// What's open over the screen. Asks go through it, since one made while another is up
    /// never shows.
    @State private var presenter = PresentationQueue<ProjectPresentation>()
    /// Whether what's open opened as a sheet or a popover pointing at what opened it, which it
    /// stays until it closes. Turning a phone or resizing a window would otherwise ask for one
    /// while the other is still leaving, which never shows.
    @State private var openedStyle = OpenedStyle()
    @State private var stripPosition: StripItem?
    @State private var session: CropSession
    @State private var layerSession: LayerSession
    /// The photo held to put in whichever cell is tapped next, as moving one without a drag does.
    @State private var held: HeldPhoto?
    /// A held photo waiting for the slide the layout sheet adds, which takes it in its first cell.
    @State private var heldForNewSlide: HeldPhoto?
    @State private var trayRemovals: TrayRemovals
    /// Photos already tried quietly, so one whose original is gone isn't tried on every redraw.
    @State private var quietRestores: Set<UUID> = []
    @Environment(\.photoLibrary) private var photoLibrary
    /// The text size outside the strip, which caps its own, for the layers sheet it presents.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// `selection`, when given, opens with that photo selected to frame, `layerSession` with its
    /// layer selected, `held` with that photo held to place, and `trayRemoval` asking about removing
    /// those tray photos, as snapshots need.
    init(
        library: ProjectLibrary,
        projectID: UUID,
        selection: CellAddress? = nil,
        layerSession: LayerSession = LayerSession(),
        held: HeldPhoto? = nil,
        trayRemoval: TrayRemoval? = nil
    ) {
        self.library = library
        self.projectID = projectID
        _session = State(initialValue: CropSession(selection: selection))
        _layerSession = State(initialValue: layerSession)
        _held = State(initialValue: held)
        _trayRemovals = State(initialValue: TrayRemovals(pending: trayRemoval))
    }

    var body: some View {
        if let project = library.project(projectID) {
            content(project)
                .tracksPopovers()
        } else {
            // Another window deleted it.
            ContentUnavailableView("Project Deleted", systemImage: "trash")
                .background {
                    GlowBackdrop()
                }
        }
    }

    private func content(_ project: Project) -> some View {
        let screen = strip(project)
            .modifier(selectionBar)
            .modifier(LayerBarOverlay(
                project: project,
                session: layerSession,
                actions: layerActions,
                onCommitSize: saveLivePlacement,
                onDone: { selectLayer(nil) }
            ))
            .modifier(PlacementBarOverlay(library: library, held: $held, onNewSlide: addSlide))
            .modifier(PhotoTrayOverlay(
                library: library,
                project: project,
                removals: trayRemovals,
                isShown: isTrayShown,
                actions: trayActions(project)
            ))
            .background {
                let front = project.frontSlide(at: stripPosition)
                SlideBackdrop(slide: front, projectID: projectID, aspectRatio: project.aspectRatio, layerSession: layerSession)
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
            .modifier(ProjectTourHost(
                project: project,
                stripPosition: stripPosition,
                presenter: presenter,
                photoSelection: session.selection,
                layerSelection: layerSession.selection,
                isHoldingPhoto: held != nil,
                isImportingToTray: library.importingTray[project.id] != nil,
                isFailing: library.failure != nil
            ))
        return presentations(over: screen, project: project)
    }

    /// The bar along the bottom while a photo is selected.
    private var selectionBar: SelectionBarOverlay {
        SelectionBarOverlay(
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
            onMove: { selection in
                saveLiveCrop()
                if let imageID = library.photo(at: selection)?.id {
                    hold(.cell(selection, imageID: imageID))
                }
            },
            onRemove: { selection in
                select(nil)
                withAnimation {
                    library.removePhoto(at: selection)
                }
            },
            onCommitZoom: saveLiveCrop,
            onDone: { select(nil) }
        )
    }

    private func toolbar(_ project: Project) -> ProjectToolbar {
        ProjectToolbar(
            project: project,
            exporter: exporter,
            // On a compact width it comes from the screen's sheet.
            isExporting: presenting.presentsAsSheets ? .constant(false) : presenting.isPresenting(.export),
            onShare: {
                select(nil)
                presenter.present(.export)
            },
            onPopoverGone: exportGone
        )
    }

    private var exporter: SlideExporter {
        SlideExporter(paths: library.store.paths)
    }

    /// Closes the export however it went, then opens what's waiting, so one that never shows can't
    /// stay asked for, which would keep anything else from opening.
    private func exportGone() {
        presenter.dismiss(.export)
        presenter.presentPending()
    }

    /// The screen's sheet, which shows the layout sheet and the export and layers sheets wherever
    /// they aren't popovers, and the photo picker and the camera, which open over the screen.
    private func presentations(over screen: some View, project: Project) -> some View {
        screen
            .sheet(item: presenting.sheetItem) { item in
                sheetContent(for: item, in: project)
            }
            .onChange(of: presenter.current) { _, current in
                openedStyle.prefersSheets = current.map(presenting.prefersSheets(for:))
                // A slide's layers cover the bar that shows a photo is held, and take its taps.
                if case .layers = current {
                    held = nil
                }
            }
            .modifier(PhotoPickerHost(library: library, removals: trayRemovals, presented: presenting.pickTarget))
            .fullScreenCover(item: presenting.cameraTarget) { target in
                CameraPicker { image in
                    Task {
                        await library.importPhoto(into: target, assetIdentifier: nil) { .image(image) }
                    }
                }
                .ignoresSafeArea()
                .onDisappear { presenter.presentPending() }
            }
            #if DEBUG
            .modifier(ProjectDebugLaunch(
                library: library,
                projectID: projectID,
                layerActions: layerActions,
                selectCell: { select($0) },
                selectLayer: { selectLayer($0) },
                selectedLayer: { layerSession.selection },
                present: { presenter.present($0) },
                hold: hold
            ))
            #endif
    }

    @ViewBuilder
    private func sheetContent(for item: ProjectPresentation, in project: Project) -> some View {
        switch item {
        case .layout(let purpose):
            layoutSheet(for: purpose, in: project)
                .onDisappear {
                    // Let go of when the sheet closes without a new slide to take it.
                    heldForNewSlide = nil
                    presenter.presentPending()
                }
        case .export:
            ExportSheet(project: project, exporter: exporter)
                .onDisappear(perform: exportGone)
        case .layers(let slideID):
            // Its `onGone` closes it and opens what's waiting.
            layerActions.sheet(slideID)
        case .photoPicker, .camera:
            EmptyView()
        }
    }

    /// What's open over the screen, as its presentations read and close it.
    private var presenting: ProjectPresenting {
        ProjectPresenting(
            presenter: $presenter,
            openedStyle: openedStyle,
            isCompact: horizontalSizeClass == .compact,
            project: library.project(projectID)
        )
    }

    private func strip(_ project: Project) -> some View {
        let strip = SlideStrip(
            project: project,
            position: $stripPosition,
            importingCells: library.importingCells,
            importingLayers: library.importingLayers,
            cellActions: cellActions,
            session: session,
            layerSession: layerSession,
            layerActions: layerActions,
            layersSlideID: layersSlideID,
            layersInSheet: presenting.presentsAsSheets,
            onBackgroundTap: {
                if presenter.dismiss(where: { $0.closesOnBackgroundTap }) {
                    return
                } else if held != nil {
                    held = nil
                } else {
                    select(nil)
                }
            },
            onAddSlide: addSlide,
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
            .environment(\.screenDynamicTypeSize, dynamicTypeSize)
            .onGeometryChange(for: CGSize.self, of: \.size) { openedStyle.stripSize = $0 }
    }

    private var cellActions: CellActions {
        ProjectCellActions(
            library: library,
            photoLibrary: photoLibrary,
            choosePhotos: { choosePhotos(for: $0) },
            takePhoto: CameraPicker.isAvailable ? { presenter.present(.camera($0)) } : nil,
            select: { select($0) },
            restoresQuietly: { quietRestores.insert($0).inserted },
            held: held,
            hold: hold,
            land: land,
            landInLayer: land(inLayer:)
        )
        .actions
    }

    /// Holds `photo` to put in whichever cell is tapped next, letting go of any selection.
    private func hold(_ photo: HeldPhoto) {
        select(nil)
        held = photo
    }

    /// Puts the held photo in the cell at `address`, or lets it go there when that's its own. A
    /// cell with a photo on its way in takes none, and leaves it held for another.
    private func land(at address: CellAddress) {
        guard let photo = held, !library.importingCells.contains(address) else {
            return
        }
        held = nil
        Task {
            await library.land(photo, at: address)
        }
    }

    /// Puts the held photo, one from the tray, in the picture layer at `address`.
    private func land(inLayer address: LayerAddress) {
        guard case .tray(let projectID, let photoID) = held, projectID == address.projectID else {
            return
        }
        held = nil
        Task {
            await library.replaceLayerImage(at: address, withTrayPhoto: photoID)
        }
    }

    /// Opens the layout sheet for a new slide, which takes any held photo in its first cell.
    private func addSlide() {
        if let held {
            startSlide(with: held)
        } else {
            presenter.present(.layout(.newSlide))
        }
    }

    /// Opens the layout sheet for a new slide that takes `photo` in its first cell.
    private func startSlide(with photo: HeldPhoto) {
        held = nil
        heldForNewSlide = photo
        presenter.present(.layout(.newSlide))
    }

    /// Whether the tray shows: while nothing else takes the bottom of the screen.
    private var isTrayShown: Bool {
        session.selection == nil && layerSession.selection == nil && held == nil && layersSlideID == nil && layerSession.sheetRoom == 0
    }

    private func trayActions(_ project: Project) -> TrayActions {
        ProjectTrayActions(
            library: library,
            project: project,
            frontSlide: stripPosition == .add ? nil : project.frontSlide(at: stripPosition),
            photoLibrary: photoLibrary,
            presenter: $presenter,
            hold: hold,
            startSlide: { startSlide(with: $0) },
            restoresQuietly: { quietRestores.insert($0).inserted }
        )
        .actions
    }

    /// Selects the photo at `address` to frame, or nothing, saving whatever the last photo or
    /// layer was left at, and brings the photo's slide to the middle.
    private func select(_ address: CellAddress?) {
        saveLiveCrop()
        saveLivePlacement()
        if let address {
            held = nil
            followSelection(on: address.slideID, to: nil)
        }
        layerSession.selection = nil
        session.selection = address
        if let address {
            bringForward(address.slideID)
        }
    }

    /// Selects the layer at `address` to move, size and turn, or none, saving whatever the last
    /// photo or layer was left at, and brings the layer's slide to the middle.
    private func selectLayer(_ address: LayerAddress?) {
        saveLiveCrop()
        saveLivePlacement()
        if let address {
            held = nil
            followSelection(on: address.slideID, to: address)
        }
        session.selection = nil
        layerSession.selection = address
        if let address {
            bringForward(address.slideID)
        }
    }

    /// Brings slide `slideID` to the middle of the strip, unless it's there already, where a panorama
    /// would move from the part in view to its own middle.
    private func bringForward(_ slideID: UUID) {
        guard library.project(projectID)?.isFront(slideID, at: stripPosition) != true else {
            return
        }
        withAnimation {
            stripPosition = .slide(slideID)
        }
    }

    /// Moves an open layer editor on to the layer at `address`, or back to the list for a photo,
    /// saving the draft first, so edits never land on the wrong layer. A selection on another
    /// slide than the sheet's leaves the editor be.
    private func followSelection(on slideID: UUID, to address: LayerAddress?) {
        guard slideID == layersSlideID, let draftLayerID = layerSession.draftLayerID, draftLayerID != address?.layerID,
              !layerSession.sheetPath.isEmpty else {
            return
        }
        layerSession.saveDraft(to: library, projectID: projectID)
        let layer = address.flatMap { library.layer(at: $0) }
        layerSession.sheetPath = layer.map { [.editor(for: $0)] } ?? []
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
            showsPopovers: !presenting.presentsAsSheets,
            dynamicTypeSize: dynamicTypeSize,
            select: selectLayer,
            photoSelection: { session.selection },
            photoLibrary: photoLibrary,
            restoresQuietly: { quietRestores.insert($0).inserted }
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
        presenter.present(.photoPicker(.cells(address, limit: library.pickLimit(for: address))))
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
            if let photo = heldForNewSlide {
                heldForNewSlide = nil
                Task {
                    await library.land(photo, at: CellAddress(projectID: projectID, slideID: slideID, index: 0))
                }
            }
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
}

#Preview {
    NavigationStack {
        ProjectScreen(
            library: ProjectLibrary(store: MockProjectStore(), projects: SampleProjects.all),
            projectID: SampleProjects.sampleID(1)
        )
    }
}
