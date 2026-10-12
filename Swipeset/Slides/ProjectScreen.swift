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
    #if DEBUG
    @Environment(DebugSettings.self) private var debug: DebugSettings?
    #endif

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
            }
        )
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
    /// Opens `-DebugSheet`'s sheet after a moment, since a presentation on the first frame doesn't render.
    private func openDebugSheet() async {
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
