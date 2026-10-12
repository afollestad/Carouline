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
    @State private var layoutPurpose: LayoutPurpose?
    @State private var stripPosition: StripItem?
    @State private var isPickingPhoto = false
    /// The cell the photo picker fills. Kept apart from `isPickingPhoto`, which the picker clears
    /// as it closes, possibly before it hands over the pick.
    @State private var pickTarget: CellAddress?
    @State private var pickedItem: PhotosPickerItem?
    @State private var cameraTarget: CellAddress?
    @State private var session: CropSession
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
        }
    }

    private func content(_ project: Project) -> some View {
        strip(project)
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
            .background(Color(.systemGroupedBackground))
            .navigationTitle(nameBinding)
            .navigationBarTitleDisplayMode(.inline)
            .navigationSubtitle(project.summary)
            .toolbarTitleMenu {
                RenameButton()
            }
            .sheet(item: $layoutPurpose) { purpose in
                layoutSheet(for: purpose, in: project)
            }
            .photosPicker(
                isPresented: $isPickingPhoto,
                selection: $pickedItem,
                matching: .images,
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            )
            .onChange(of: pickedItem) { _, item in
                importPicked(item)
            }
            .fullScreenCover(item: $cameraTarget) { target in
                CameraPicker { image in
                    Task {
                        await library.importPhoto(into: target, assetIdentifier: nil) { .image(image) }
                    }
                }
                .ignoresSafeArea()
            }
            #if DEBUG
            .task {
                await openDebugSheet()
            }
            #endif
    }

    private func strip(_ project: Project) -> some View {
        SlideStrip(
            project: project,
            position: $stripPosition,
            importingCells: library.importingCells,
            cellActions: cellActions,
            session: session,
            onBackgroundTap: { select(nil) },
            onAddSlide: { layoutPurpose = .newSlide },
            onChangeLayout: { layoutPurpose = .change($0) },
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
            }
        )
    }

    private var cellActions: CellActions {
        CellActions(
            choosePhoto: { address in
                pickTarget = address
                isPickingPhoto = true
            },
            takePhoto: CameraPicker.isAvailable ? { cameraTarget = $0 } : nil,
            removePhoto: { address in
                withAnimation {
                    library.removePhoto(at: address)
                }
            },
            select: { select($0) },
            setCrop: { crop, address in
                library.setCrop(crop, at: address)
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
                    pickTarget = selection
                    isPickingPhoto = true
                },
                onTakePhoto: {
                    saveLiveCrop()
                    cameraTarget = selection
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

    /// Copies the picker's photo into the cell it was opened for, keeping the photo's library
    /// identifier so the copy can be restored from it.
    private func importPicked(_ item: PhotosPickerItem?) {
        guard let item, let target = pickTarget else {
            return
        }
        pickedItem = nil
        pickTarget = nil
        Task {
            await library.importPhoto(into: target, assetIdentifier: item.itemIdentifier) {
                try await item.loadTransferable(type: PickedPhoto.self).map { .file($0.url) }
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
            } else if let slideID = library.addSlide(layout, to: projectID) {
                withAnimation {
                    stripPosition = .slide(slideID)
                }
            }
        }
    }

    #if DEBUG
    /// Selects `-DebugSelectCell`'s photo, and opens `-DebugSheet`'s sheet after a moment, since a
    /// presentation on the first frame doesn't render.
    private func openDebugSheet() async {
        let slides = library.project(projectID)?.slides ?? []
        if let (slide, cell) = debug?.selectedCell, slides.indices.contains(slide) {
            select(CellAddress(projectID: projectID, slideID: slides[slide].id, index: cell))
        }
        guard debug?.sheet == .layout else {
            return
        }
        try? await Task.sleep(for: .milliseconds(500))
        layoutPurpose = .newSlide
    }
    #endif
}

/// What the layout sheet is choosing for.
private enum LayoutPurpose: Hashable, Identifiable {
    case newSlide
    case change(UUID)

    var id: Self { self }
}

#Preview {
    NavigationStack {
        ProjectScreen(
            library: ProjectLibrary(store: MockProjectStore(), projects: SampleProjects.all),
            projectID: SampleProjects.sampleID(1)
        )
    }
}
