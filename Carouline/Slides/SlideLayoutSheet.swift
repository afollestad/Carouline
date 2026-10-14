//
//  SlideLayoutSheet.swift
//  Carouline
//

import SwiftUI

/// What the layout sheet is choosing for.
enum LayoutPurpose: Hashable, Identifiable {
    case newSlide
    case change(UUID)

    var id: Self { self }
}

/// The layout sheet for a project, which adds a slide in the layout chosen or gives a slide it.
struct SlideLayoutSheet: View {
    let library: ProjectLibrary
    let project: Project
    let purpose: LayoutPurpose
    /// Runs with a new slide's ID, and whether it's the project's first.
    let onAdd: (UUID, Bool) -> Void

    var body: some View {
        let slide: Slide? = switch purpose {
        case .newSlide: nil
        case .change(let slideID): project.slides.first { $0.id == slideID }
        }
        LayoutSheet(aspectRatio: project.aspectRatio, current: slide?.layout) { layout in
            slide.map { ProjectLibrary.photosLost(changing: $0, to: layout) } ?? 0
        } onChoose: { layout in
            if let slide {
                library.changeLayout(of: slide.id, in: project.id, to: layout)
            } else {
                let isFirst = library.project(project.id)?.slides.isEmpty ?? false
                if let slideID = library.addSlide(layout, to: project.id) {
                    onAdd(slideID, isFirst)
                }
            }
        }
    }
}

#Preview {
    let project = SampleProjects.all[0]
    Color.clear
        .sheet(isPresented: .constant(true)) {
            SlideLayoutSheet(
                library: ProjectLibrary(store: MockProjectStore(), projects: [project]),
                project: project,
                purpose: .change(project.slides[0].id)
            ) { _, _ in }
        }
}
