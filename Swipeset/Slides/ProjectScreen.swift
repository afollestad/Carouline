//
//  ProjectScreen.swift
//  Swipeset
//

import SwiftUI

/// A project's slides, where they're added, arranged and filled.
struct ProjectScreen: View {
    let library: ProjectLibrary
    let projectID: UUID
    @State private var layoutPurpose: LayoutPurpose?
    @State private var stripPosition: StripItem?
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
        SlideStrip(
            project: project,
            position: $stripPosition,
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
        #if DEBUG
        .task {
            await openDebugSheet()
        }
        #endif
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
