//
//  SlideStrip.swift
//  Swipeset
//

import SwiftUI

/// Something the strip can scroll to: a slide, or the button after the last one.
enum StripItem: Hashable {
    case slide(UUID)
    case add
}

/// A project's slides side by side, with the button for another after the last.
struct SlideStrip: View {
    let project: Project
    @Binding var position: StripItem?
    let importingCells: Set<CellAddress>
    let cellActions: CellActions
    let session: CropSession
    /// Taps between the slides, which finish framing a photo.
    let onBackgroundTap: () -> Void
    let onAddSlide: () -> Void
    let onChangeLayout: (UUID) -> Void
    let onMove: (UUID, Int) -> Void
    let onDelete: (UUID) -> Void
    let onSetSpan: (UUID, Int) -> Void
    @State private var size: CGSize = .zero
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The caption's height and the gap above it, which the slide makes room for.
    private static let captionSpace: CGFloat = 56
    private static let spacing: CGFloat = 20
    private static let addButtonSize: CGFloat = 56

    var body: some View {
        Group {
            if project.slides.isEmpty {
                GhostSlide(size: cardSize(span: 1), onAdd: onAddSlide)
                    .padding(.bottom, SelectionBar.reservedHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                strip
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            self.size = size
        }
    }

    private var strip: some View {
        let numbers = project.slideNumbers
        return ScrollView(.horizontal) {
            LazyHStack(alignment: .slideCenter, spacing: Self.spacing) {
                ForEach(Array(project.slides.enumerated()), id: \.element.id) { index, slide in
                    SlideCard(
                        slide: slide,
                        projectID: project.id,
                        numbers: numbers[index],
                        count: project.carouselSlideCount,
                        canMoveLeft: index > 0,
                        canMoveRight: index < project.slides.count - 1,
                        style: project.style,
                        size: cardSize(span: slide.span),
                        importingCells: importingCells,
                        cellActions: cellActions,
                        session: session,
                        onChangeLayout: { onChangeLayout(slide.id) },
                        onMove: { onMove(slide.id, $0) },
                        onDelete: { onDelete(slide.id) },
                        onSetSpan: { onSetSpan(slide.id, $0) }
                    )
                    .id(StripItem.slide(slide.id))
                }
                AddSlideButton(size: Self.addButtonSize, action: onAddSlide)
                    .id(StripItem.add)
            }
            // Where `scrollPosition` finds the slides and the add button by ID.
            .scrollTargetLayout()
            // Room for the first slide and the add button each to reach the middle. Padding
            // rather than `contentMargins`, which stop view-aligned scrolling from snapping and
            // shift a centered `scrollPosition` off the middle of the screen.
            .padding(.leading, max(0, (size.width - firstCardWidth) / 2))
            .padding(.trailing, max(0, (size.width - Self.addButtonSize) / 2))
            .padding(.bottom, SelectionBar.reservedHeight)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .onTapGesture(perform: onBackgroundTap)
        }
        .scrollTargetBehavior(snapping)
        // A drag on the selected photo frames it rather than scrolling past it.
        .scrollDisabled(session.selection != nil)
        .scrollPosition(id: $position, anchor: .center)
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    /// Rests the strip with a slide, or the add button, in the middle of the screen. View-aligned
    /// scrolling would rest a slide's leading edge on the screen's instead, whatever its anchor.
    /// Each offset centers its item past the leading padding, which centers the first, so a
    /// panorama wider than a slide centers too.
    private var snapping: StripSnapping {
        let first = firstCardWidth
        var leadingEdge: CGFloat = 0
        var offsets: [CGFloat] = []
        for slide in project.slides {
            let width = cardSize(span: slide.span).width
            offsets.append(leadingEdge + (width - first) / 2)
            leadingEdge += width + Self.spacing
        }
        return StripSnapping(offsets: offsets + [leadingEdge + (Self.addButtonSize - first) / 2])
    }

    private var firstCardWidth: CGFloat {
        cardSize(span: project.slides.first?.span ?? 1).width
    }

    /// The project's shape, `span` slides wide, fitted to the screen, leaving the slides either
    /// side peeking in at the edges so the strip reads as one to scroll. A panorama fits in the
    /// same room as a slide, so all of it can be framed at once.
    private func cardSize(span: Int) -> CGSize {
        let ratio = project.aspectRatio.widthOverHeight * CGFloat(span)
        let maxWidth = size.width * (horizontalSizeClass == .regular ? 0.7 : 0.82)
        let maxHeight = max(0, size.height - Self.captionSpace - SelectionBar.reservedHeight - 32)
        let width = max(0, min(maxWidth, maxHeight * ratio))
        return CGSize(width: width, height: width / ratio)
    }
}

/// Snaps a scroll to the nearest of `offsets`.
private struct StripSnapping: ScrollTargetBehavior {
    let offsets: [CGFloat]

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        // A scroll to a `scrollPosition` targets the item's own rect, anchored to center it,
        // which already rests it on one of the offsets. Snapping that rect as if it were the
        // visible region would stop the scroll short.
        guard target.anchor == nil else {
            return
        }
        let proposed = target.rect.minX
        if let nearest = offsets.min(by: { abs($0 - proposed) < abs($1 - proposed) }) {
            target.rect.origin.x = nearest
        }
    }
}

extension VerticalAlignment {
    /// The middle of the slides, so the add button beside them lines up with the slides
    /// rather than with the slides and their captions.
    private enum SlideCenter: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    static let slideCenter = VerticalAlignment(SlideCenter.self)
}

private struct SlideCard: View {
    let slide: Slide
    let projectID: UUID
    /// The slide's numbers in the carousel: one, or a panorama's run.
    let numbers: ClosedRange<Int>
    let count: Int
    let canMoveLeft: Bool
    let canMoveRight: Bool
    let style: SlideStyle
    let size: CGSize
    let importingCells: Set<CellAddress>
    let cellActions: CellActions
    let session: CropSession
    let onChangeLayout: () -> Void
    let onMove: (Int) -> Void
    let onDelete: () -> Void
    let onSetSpan: (Int) -> Void
    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(spacing: 12) {
            SlideView(slide: slide, style: style) { index in
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
                    isPanorama: slide.layout == .panorama
                )
            }
            .frame(width: size.width, height: size.height)
            .overlay {
                if slide.span > 1 {
                    PanoramaSeams(span: slide.span)
                }
            }
            // A hairline, so a slide the color of the screen still shows its edges.
            .overlay {
                Rectangle()
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .alignmentGuide(.slideCenter) { $0[VerticalAlignment.center] }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(spokenNumbers) of \(count), \(slide.layout.name)")
            Menu {
                options
            } label: {
                HStack(spacing: 8) {
                    Text(numbersText)
                    Image(systemName: "ellipsis")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("\(spokenNumbers) Options")
            .frame(height: 44)
        }
        .confirmationDialog("Delete \(numbersText)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button(deleteTitle, role: .destructive, action: onDelete)
        } message: {
            Text(deletionMessage)
        }
    }

    @ViewBuilder
    private var options: some View {
        Button("Change Layout…", systemImage: "rectangle.split.2x2", action: onChangeLayout)
        // Once there's a photo, since the first one sets the width to fit it.
        if slide.layout == .panorama, slide.cells.first?.image != nil {
            Picker(selection: Binding { slide.span } set: { onSetSpan($0) }) {
                ForEach(Slide.panoramaSpans, id: \.self) { span in
                    Text("\(span) Slides").tag(span)
                }
            } label: {
                Label("Width", systemImage: "arrow.left.and.right")
            }
            .pickerStyle(.menu)
        }
        Button("Move Left", systemImage: "arrow.left") {
            onMove(-1)
        }
        .disabled(!canMoveLeft)
        Button("Move Right", systemImage: "arrow.right") {
            onMove(1)
        }
        .disabled(!canMoveRight)
        Divider()
        Button(deleteTitle, systemImage: "trash", role: .destructive) {
            isConfirmingDelete = true
        }
    }

    /// "Slide 3", or a panorama's "Slides 2–4".
    private var numbersText: String {
        numbers.count == 1 ? "Slide \(numbers.lowerBound)" : "Slides \(numbers.lowerBound)–\(numbers.upperBound)"
    }

    /// `numbersText` as VoiceOver should read it, rather than trusting it to read the dash.
    private var spokenNumbers: String {
        numbers.count == 1 ? "Slide \(numbers.lowerBound)" : "Slides \(numbers.lowerBound) to \(numbers.upperBound)"
    }

    private var deleteTitle: String {
        slide.layout == .panorama ? "Delete Panorama" : "Delete Slide"
    }

    /// Where cell `index` sits, for VoiceOver.
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

    private var deletionMessage: String {
        switch slide.cells.compactMap(\.image).count {
        case 0: slide.layout == .panorama ? "This panorama has no photo yet." : "This slide has no photos yet."
        case 1: "Its photo is removed from the project. The original stays in your photo library."
        case let count: "Its \(count) photos are removed from the project. The originals stay in your photo library."
        }
    }
}

private struct AddSlideButton: View {
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Add Slide", systemImage: "plus")
                .labelStyle(.iconOnly)
                .font(.title2.weight(.semibold))
                .frame(width: size - 16, height: size - 16)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityHint("Choose a layout for a new slide")
        // Exactly `size` across, which the strip's snapping counts on to center it.
        .frame(width: size, height: size)
        .alignmentGuide(.slideCenter) { $0[VerticalAlignment.center] }
    }
}

/// Where the first slide will go, in the project's shape.
private struct GhostSlide: View {
    let size: CGSize
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .frame(width: size.width, height: size.height)
                .overlay {
                    Button(action: onAdd) {
                        Label("Add Slide", systemImage: "plus")
                            .labelStyle(.iconOnly)
                            .font(.title.weight(.semibold))
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .accessibilityHint("Choose a layout for the first slide")
                }
            Text("Add a slide to start your carousel.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .padding(.bottom, 40)
    }
}

#Preview("Slides") {
    @Previewable @State var position: StripItem?
    SlideStrip(
        project: SampleProjects.all[0],
        position: $position,
        importingCells: [],
        cellActions: .preview,
        session: CropSession(),
        onBackgroundTap: {},
        onAddSlide: {},
        onChangeLayout: { _ in },
        onMove: { _, _ in },
        onDelete: { _ in },
        onSetSpan: { _, _ in }
    )
    .background { GlowBackdrop() }
}

#Preview("Panorama") {
    @Previewable @State var position: StripItem? = .slide(SampleProjects.sampleID(14))
    SlideStrip(
        project: SampleProjects.all[0],
        position: $position,
        importingCells: [],
        cellActions: .preview,
        session: CropSession(),
        onBackgroundTap: {},
        onAddSlide: {},
        onChangeLayout: { _ in },
        onMove: { _, _ in },
        onDelete: { _ in },
        onSetSpan: { _, _ in }
    )
    .background { GlowBackdrop() }
}

#Preview("Empty") {
    @Previewable @State var position: StripItem?
    SlideStrip(
        project: SampleProjects.all[2],
        position: $position,
        importingCells: [],
        cellActions: .preview,
        session: CropSession(),
        onBackgroundTap: {},
        onAddSlide: {},
        onChangeLayout: { _ in },
        onMove: { _, _ in },
        onDelete: { _ in },
        onSetSpan: { _, _ in }
    )
    .background { GlowBackdrop() }
}
