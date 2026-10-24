//
//  CardPhotos.swift
//  Carouline
//

import SwiftUI

/// A slide's cells, each with its photo or the way to add one. The only part of the card that
/// reads a blur or style the layers sheet is editing, so each step redraws the photos alone,
/// rather than the card, which on a wide screen hosts the sheet's popover.
struct CardPhotos: View {
    let slide: Slide
    let projectID: UUID
    let numbers: ClosedRange<Int>
    let size: CGSize
    let importingCells: Set<CellAddress>
    let cellActions: CellActions
    let session: CropSession
    let layerSession: LayerSession
    let isAnythingSelected: Bool
    /// The cell a drop over the slide would land in.
    let dropTarget: Int?
    @Environment(TrayPress.self) private var trayPress: TrayPress?

    var body: some View {
        // Here rather than on the card, so a tray photo carried from cell to cell redraws the cells alone.
        let target = dropTarget ?? trayPress?.target.flatMap { $0.slideID == slide.id ? $0.index : nil }
        let isStyling = layerSession.stylingSlideID == slide.id
        let style = isStyling ? layerSession.slideStyle : slide.style
        let blur = LayerGeometry.blurRadius(isStyling ? layerSession.slideBlur : slide.blur, slideWidth: size.width / CGFloat(max(1, slide.span)))
        SlideView(slide: slide, style: style, revealsEmptyCells: true) { index in
            let address = CellAddress(projectID: projectID, slideID: slide.id, index: index)
            CellView(
                cell: slide.cells[index],
                address: address,
                background: style.background,
                position: position(of: index),
                emptyCellCount: slide.emptyCellCount(skipping: importingIndexes),
                isImporting: importingCells.contains(address),
                actions: cellActions,
                session: session,
                isPanorama: slide.layout == .panorama,
                isAnythingSelected: isAnythingSelected,
                blur: blur,
                isDropTarget: target == index,
                stripReach: StripMiddle.reach(span: slide.span, cardWidth: size.width)
            )
        }
    }

    private func position(of index: Int) -> String {
        if slide.layout == .panorama {
            "panorama photo on slides \(numbers.lowerBound) to \(numbers.upperBound)"
        } else {
            "slide \(numbers.lowerBound), photo \(index + 1) of \(slide.cells.count)"
        }
    }

    /// The cells with a photo on its way in, which a pick can't fill.
    private var importingIndexes: Set<Int> {
        Set(slide.cells.indices.filter { importingCells.contains(CellAddress(projectID: projectID, slideID: slide.id, index: $0)) })
    }
}

#Preview {
    let project = SampleProjects.all[0]
    CardPhotos(
        slide: project.slides[2],
        projectID: project.id,
        numbers: 3...3,
        size: CGSize(width: 300, height: 375),
        importingCells: [],
        cellActions: .preview,
        session: CropSession(),
        layerSession: LayerSession(),
        isAnythingSelected: false,
        dropTarget: nil
    )
    .padding()
    .background { GlowBackdrop() }
}
