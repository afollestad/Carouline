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
    @State private var size: CGSize = .zero
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The caption's height and the gap above it, which the slide makes room for.
    private static let captionSpace: CGFloat = 56
    private static let spacing: CGFloat = 20
    private static let addButtonSize: CGFloat = 56

    var body: some View {
        Group {
            if project.slides.isEmpty {
                GhostSlide(size: slideSize, onAdd: onAddSlide)
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
        ScrollView(.horizontal) {
            LazyHStack(alignment: .slideCenter, spacing: Self.spacing) {
                ForEach(Array(project.slides.enumerated()), id: \.element.id) { index, slide in
                    SlideCard(
                        slide: slide,
                        projectID: project.id,
                        number: index + 1,
                        count: project.slides.count,
                        style: project.style,
                        size: slideSize,
                        importingCells: importingCells,
                        cellActions: cellActions,
                        session: session,
                        onChangeLayout: { onChangeLayout(slide.id) },
                        onMove: { onMove(slide.id, $0) },
                        onDelete: { onDelete(slide.id) }
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
            .padding(.leading, max(0, (size.width - slideSize.width) / 2))
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
    private var snapping: StripSnapping {
        let pitch = slideSize.width + Self.spacing
        let slides = (0..<project.slides.count).map { CGFloat($0) * pitch }
        let add = CGFloat(project.slides.count) * pitch + (Self.addButtonSize - slideSize.width) / 2
        return StripSnapping(offsets: slides + [add])
    }

    /// The project's shape fitted to the screen, leaving the slides either side peeking in at
    /// the edges so the strip reads as one to scroll.
    private var slideSize: CGSize {
        let ratio = project.aspectRatio.widthOverHeight
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
    let number: Int
    let count: Int
    let style: SlideStyle
    let size: CGSize
    let importingCells: Set<CellAddress>
    let cellActions: CellActions
    let session: CropSession
    let onChangeLayout: () -> Void
    let onMove: (Int) -> Void
    let onDelete: () -> Void
    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(spacing: 12) {
            SlideView(slide: slide, style: style) { index in
                let address = CellAddress(projectID: projectID, slideID: slide.id, index: index)
                CellView(
                    cell: slide.cells[index],
                    address: address,
                    background: style.background,
                    position: "slide \(number), photo \(index + 1) of \(slide.cells.count)",
                    emptyCellCount: slide.emptyCellCount(skipping: importingIndexes),
                    isImporting: importingCells.contains(address),
                    actions: cellActions,
                    session: session
                )
            }
            .frame(width: size.width, height: size.height)
            // A hairline, so a slide the color of the screen still shows its edges.
            .overlay {
                Rectangle()
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .alignmentGuide(.slideCenter) { $0[VerticalAlignment.center] }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Slide \(number) of \(count), \(slide.layout.name)")
            Menu {
                Button("Change Layout…", systemImage: "rectangle.split.2x2", action: onChangeLayout)
                Button("Move Left", systemImage: "arrow.left") {
                    onMove(-1)
                }
                .disabled(number == 1)
                Button("Move Right", systemImage: "arrow.right") {
                    onMove(1)
                }
                .disabled(number == count)
                Divider()
                Button("Delete Slide", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Slide \(number)")
                    Image(systemName: "ellipsis")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Slide \(number) Options")
            .frame(height: 44)
        }
        .confirmationDialog("Delete Slide \(number)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Slide", role: .destructive, action: onDelete)
        } message: {
            Text(deletionMessage)
        }
    }

    /// The cells with a photo on its way in, which a pick can't fill.
    private var importingIndexes: Set<Int> {
        Set(slide.cells.indices.filter { importingCells.contains(CellAddress(projectID: projectID, slideID: slide.id, index: $0)) })
    }

    private var deletionMessage: String {
        switch slide.cells.compactMap(\.image).count {
        case 0: "This slide has no photos yet."
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
        onDelete: { _ in }
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
        onDelete: { _ in }
    )
    .background { GlowBackdrop() }
}
