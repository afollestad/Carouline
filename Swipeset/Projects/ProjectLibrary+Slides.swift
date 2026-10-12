//
//  ProjectLibrary+Slides.swift
//  Swipeset
//

import Foundation

extension ProjectLibrary {
    /// Appends a slide in `layout` to project `projectID`, returning the new slide's ID.
    @discardableResult
    func addSlide(_ layout: SlideLayout, to projectID: UUID) -> UUID? {
        guard project(projectID) != nil else {
            return nil
        }
        let slide = Slide(layout: layout)
        update(projectID) { $0.slides.append(slide) }
        return slide.id
    }

    /// Moves slide `slideID` `offset` places along, if there's room.
    func moveSlide(_ slideID: UUID, in projectID: UUID, by offset: Int) {
        guard let slides = project(projectID)?.slides,
              let index = slides.firstIndex(where: { $0.id == slideID }),
              slides.indices.contains(index + offset) else {
            return
        }
        update(projectID) { project in
            let slide = project.slides.remove(at: index)
            project.slides.insert(slide, at: index + offset)
        }
    }

    func deleteSlide(_ slideID: UUID, in projectID: UUID) {
        guard let slide = project(projectID)?.slides.first(where: { $0.id == slideID }) else {
            return
        }
        update(projectID, deletingImages: slide.cells.compactMap(\.image?.id)) { project in
            project.slides.removeAll { $0.id == slideID }
        }
    }

    /// Gives slide `slideID` a new layout, carrying its photos over in order and deleting any
    /// the new layout has no cell for.
    func changeLayout(of slideID: UUID, in projectID: UUID, to layout: SlideLayout) {
        guard let slide = project(projectID)?.slides.first(where: { $0.id == slideID }), slide.layout != layout else {
            return
        }
        let (cells, dropped) = Self.cells(of: slide, in: layout)
        update(projectID, deletingImages: dropped.map(\.id)) { project in
            guard let index = project.slides.firstIndex(where: { $0.id == slideID }) else {
                return
            }
            project.slides[index].layout = layout
            project.slides[index].cells = cells
        }
    }

    /// How many of `slide`'s photos `layout` has no cell for.
    static func photosLost(changing slide: Slide, to layout: SlideLayout) -> Int {
        cells(of: slide, in: layout).dropped.count
    }

    /// `slide`'s photos packed into `layout`'s cells in reading order, and those left over.
    private static func cells(of slide: Slide, in layout: SlideLayout) -> (cells: [Cell], dropped: [PlacedImage]) {
        let images = slide.cells.compactMap(\.image)
        let count = layout.grid.cells.count
        let cells = (0..<count).map { Cell(image: $0 < images.count ? images[$0] : nil) }
        return (cells, Array(images.dropFirst(count)))
    }
}
