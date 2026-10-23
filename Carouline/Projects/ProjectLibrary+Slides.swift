//
//  ProjectLibrary+Slides.swift
//  Carouline
//

import Foundation

extension ProjectLibrary {
    /// Appends a slide in `layout` to project `projectID`, returning the new slide's ID. It takes
    /// the last slide's spacing and background, so a carousel stays alike until a slide is styled
    /// apart, but not its border, which frames that slide alone. A project's first takes the
    /// standard style.
    @discardableResult
    func addSlide(_ layout: SlideLayout, to projectID: UUID) -> UUID? {
        guard let project = project(projectID) else {
            return nil
        }
        var style = project.slides.last?.style ?? .standard
        style.border = SlideStyle.standard.border
        let slide = Slide(layout: layout, style: style)
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
        update(projectID, deletingImages: slide.images) { project in
            project.slides.removeAll { $0.id == slideID }
        }
    }

    /// Gives slide `slideID` a new layout, carrying its photos over in order and deleting any
    /// the new layout has no cell for. A panorama spans as many slides as its photo fills, which
    /// shows all of it once its framing is reset, since a zoom set for one slide's shape crops
    /// a panorama to a strip. Its blur, style and layers carry over, the layers shifting together
    /// with what it shows into or out of a panorama, as `Slide.keepLayers(from:slideSize:)` moves
    /// them. A slide with a photo on its way into a cell keeps its layout, since packing would move
    /// another photo into that cell, which the one landing would replace and delete.
    func changeLayout(of slideID: UUID, in projectID: UUID, to layout: SlideLayout) {
        guard let project = project(projectID),
              let slide = project.slides.first(where: { $0.id == slideID }),
              slide.layout != layout,
              !importingCells.contains(where: { $0.projectID == projectID && $0.slideID == slideID }) else {
            return
        }
        let (packed, dropped) = Self.cells(of: slide, in: layout)
        var cells = packed
        var span: Int?
        if layout == .panorama, let image = cells[0].image {
            cells[0].image?.crop = ImageCrop()
            span = Slide.panoramaSpan(fitting: image.pixelSize, in: project.aspectRatio)
        }
        var changed = Slide(id: slideID, layout: layout, span: span, cells: cells, blur: slide.blur, style: slide.style)
        changed.keepLayers(from: slide, slideSize: project.aspectRatio.exportSize)
        update(projectID, deletingImages: dropped) { project in
            guard let index = project.slides.firstIndex(where: { $0.id == slideID }) else {
                return
            }
            project.slides[index] = changed
        }
    }

    /// Spreads panorama `slideID` across `span` slides, kept within `Slide.panoramaSpans`, with
    /// its layers kept on it.
    func setSpan(_ span: Int, of slideID: UUID, in projectID: UUID) {
        let span = Slide.clampedPanoramaSpan(span)
        guard let slide = project(projectID)?.slides.first(where: { $0.id == slideID }),
              slide.layout == .panorama,
              slide.span != span else {
            return
        }
        update(projectID) { project in
            guard let index = project.slides.firstIndex(where: { $0.id == slideID }) else {
                return
            }
            project.slides[index].setSpan(span)
        }
    }

    /// Gives slide `slideID` `style` and blurs its photos by `blur`, each kept in range, in one
    /// save if either changed.
    func setStyle(_ style: SlideStyle, blur: Double, of slideID: UUID, in projectID: UUID) {
        let style = style.clamped()
        let blur = min(max(blur, 0), Slide.maximumBlur)
        guard let slide = project(projectID)?.slides.first(where: { $0.id == slideID }),
              slide.style != style || slide.blur != blur else {
            return
        }
        update(projectID) { project in
            guard let index = project.slides.firstIndex(where: { $0.id == slideID }) else {
                return
            }
            project.slides[index].style = style
            project.slides[index].blur = blur
        }
    }

    /// Gives every slide the style of slide `slideID`, leaving each its own blur, if any differs.
    func applyStyle(of slideID: UUID, toAllIn projectID: UUID) {
        guard let project = project(projectID),
              let style = project.slides.first(where: { $0.id == slideID })?.style,
              !project.slides(besides: slideID, allHave: style) else {
            return
        }
        update(projectID) { project in
            for index in project.slides.indices {
                project.slides[index].style = style
            }
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
